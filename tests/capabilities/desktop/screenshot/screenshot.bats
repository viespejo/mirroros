#!/usr/bin/env bats
# Neutral command tests: fixed backend and sender paths are substituted in a disposable copy.
setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
  WORK="$(mktemp -d)"
  export CALLS="$WORK/calls" JOURNAL="$WORK/journal" BACKEND_STATUS=0 LOGGER_STATUS=0 NOTIFY_STATUS=0
  mkdir "$WORK/bin"
  : > "$CALLS"
  : > "$JOURNAL"
  export PATH="$WORK/bin:$PATH"
  SCRIPT="$WORK/screenshot"
  BACKEND="$WORK/backend"
  sed -e "s|backend=/usr/share/mirroros/compositor/screenshot-backend|backend=$BACKEND|" \
    -e "s|/usr/share/mirroros/shell/notifications/mirroros-notification-send|$WORK/bin/mirroros-notification-send|" \
    "$ROOT/capabilities/desktop/screenshot/screenshot" > "$SCRIPT"
  cat > "$BACKEND" <<'EOF'
#!/usr/bin/bash
printf -v arguments ' <%s>' "$@"
printf 'backend%s\n' "$arguments" >> "$CALLS"
printf 'synthetic stdout diagnostic\n'
printf 'synthetic stderr diagnostic\n' >&2
exit "$BACKEND_STATUS"
EOF
  cat > "$WORK/bin/systemd-cat" <<'EOF'
#!/usr/bin/bash
printf 'journal %s\n' "$*" >> "$CALLS"
cat >> "$JOURNAL"
exit "$LOGGER_STATUS"
EOF
  cat > "$WORK/bin/mirroros-notification-send" <<'EOF'
#!/usr/bin/bash
printf 'notify %s\n' "$*" >> "$CALLS"
exit "$NOTIFY_STATUS"
EOF
  chmod 0755 "$BACKEND" "$WORK/bin/"*
}
teardown() { rm -rf -- "$WORK"; }

@test "screenshot defaults to smart and sends diagnostics to the journal without notifying" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -qxF 'backend <smart>' "$CALLS"
  grep -qxF 'journal --identifier=mirroros-screenshot' "$CALLS"
  grep -qxF 'synthetic stdout diagnostic' "$JOURNAL"
  grep -qxF 'synthetic stderr diagnostic' "$JOURNAL"
  ! grep -q '^notify ' "$CALLS"
}

@test "screenshot dispatches each neutral mode and edit as separate validated arguments in either order" {
  local mode
  for mode in smart region window full scroll; do
    : > "$CALLS"
    run bash "$SCRIPT" "$mode"
    [ "$status" -eq 0 ]
    grep -qxF "backend <$mode>" "$CALLS"
    : > "$CALLS"
    run bash "$SCRIPT" "$mode" --edit
    [ "$status" -eq 0 ]
    grep -qxF "backend <$mode> <--edit>" "$CALLS"
    : > "$CALLS"
    run bash "$SCRIPT" --edit "$mode"
    [ "$status" -eq 0 ]
    grep -qxF "backend <$mode> <--edit>" "$CALLS"
  done
  : > "$CALLS"
  run bash "$SCRIPT" --edit
  [ "$status" -eq 0 ]
  grep -qxF 'backend <smart> <--edit>' "$CALLS"
  ! grep -q '^notify ' "$CALLS"
}

assert_usage() {
  : > "$CALLS"
  run bash "$SCRIPT" "$@"
  [ "$status" -eq 2 ]
  [[ "$output" == 'Usage: screenshot '* ]]
  [ ! -s "$CALLS" ]
}

@test "screenshot rejects unknown repeated empty and excess arguments before dispatch" {
  assert_usage unknown
  assert_usage ''
  assert_usage --help
  assert_usage --editor overlay
  assert_usage --edit --edit
  assert_usage smart smart
  assert_usage region window
  assert_usage smart --edit extra
  assert_usage --edit full scroll
  assert_usage 'region; touch /tmp/not-run'
}

@test "screenshot preserves success cancellation dismissal and usage statuses without notifications" {
  local code
  for code in 0 2; do
    : > "$CALLS"
    export BACKEND_STATUS="$code"
    run bash "$SCRIPT"
    [ "$status" -eq "$code" ]
    ! grep -q '^notify ' "$CALLS"
  done
}

@test "screenshot capture failures notify actionable journal guidance and normalize other failures" {
  local code
  for code in 1 7 127; do
    : > "$CALLS"
    export BACKEND_STATUS="$code"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'journalctl --user -t mirroros-screenshot'* ]]
    grep -q '^notify -u normal --transient -- Screenshot failed.*journalctl --user -t mirroros-screenshot' "$CALLS"
    [ "$(grep -c '^notify ' "$CALLS")" -eq 1 ]
    grep -q 'synthetic stderr diagnostic' "$JOURNAL"
  done
}

@test "screenshot missing or non-executable backend advises rerunning configure without invoking the journal" {
  local kind
  for kind in missing nonexecutable; do
    if [[ "$kind" == missing ]]; then rm "$BACKEND"; else printf '# not executable\n' > "$BACKEND"; fi
    : > "$CALLS"
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Rerun mirroros-configure'* ]]
    grep -q '^notify .*Rerun mirroros-configure' "$CALLS"
    ! grep -qE '^(backend|journal)' "$CALLS"
  done
}

@test "screenshot preserves backend status when journal or notification delivery fails" {
  export LOGGER_STATUS=9 NOTIFY_STATUS=8
  local code
  for code in 0 1 2; do
    : > "$CALLS"
    export BACKEND_STATUS="$code"
    run bash "$SCRIPT"
    [ "$status" -eq "$code" ]
    [[ "$output" == *'diagnostics could not reach the journal'* ]]
    if [[ "$code" == 1 ]]; then grep -q '^notify ' "$CALLS"; else ! grep -q '^notify ' "$CALLS"; fi
  done
  rm "$BACKEND"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "screenshot waits for the backend before returning or notifying" {
  cat > "$BACKEND" <<'EOF'
#!/usr/bin/bash
sleep 0.1
printf 'backend completed\n' >> "$CALLS"
exit 1
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  grep -q '^backend completed$' "$CALLS"
  [ "$(grep -E '^(backend completed|notify )' "$CALLS" | head -n 1)" = 'backend completed' ]
}

@test "screenshot neutral implementation does not name a provider or invoke the backend with exec" {
  ! grep -iE 'omasnap|hyprland' "$ROOT/capabilities/desktop/screenshot/"*
  ! grep -q 'exec .*backend' "$SCRIPT"
}
