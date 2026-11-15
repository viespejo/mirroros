#!/usr/bin/env bats
# The owned polkit-check command with systemctl and pgrep doubles over a disposable system tree; nothing is
# started, stopped or written.

setup() {
  TEST_DIR="$(mktemp -d)"
  SOURCE="$BATS_TEST_DIRNAME/../../../../capabilities"
  SCRIPT="$SOURCE/desktop/shell/polkit-check/polkit-check"
  export CALLS="$TEST_DIR/calls" HOME="$TEST_DIR/home" USER=alice MIRROROS_POLKIT_CHECK_ROOT="$TEST_DIR/root"
  ROOT="$MIRROROS_POLKIT_CHECK_ROOT"
  mkdir -p "$TEST_DIR/bin" "$HOME" "$ROOT/usr/share/mirroros/polkit"
  : > "$CALLS"
  cp "$SOURCE/desktop/shell/polkit-check/agents" "$ROOT/usr/share/mirroros/polkit/agents"
  # The unit state comes from STATE; is-active prints it and fails unless it is active.
  cat > "$TEST_DIR/bin/systemctl" <<'EOF'
#!/usr/bin/bash
printf 'systemctl %s\n' "$*" >> "$CALLS"
[[ "$*" == '--user is-active mirroros-shell.service' ]] || exit 97
printf '%s\n' "${STATE:-active}"
[[ "${STATE:-active}" == active ]]
EOF
  # The user's processes are the command lines in PROCESSES, one per line, matched like pgrep -f.
  cat > "$TEST_DIR/bin/pgrep" <<'EOF'
#!/usr/bin/bash
printf 'pgrep %s\n' "$*" >> "$CALLS"
[[ "$1 $2 $3 $4" == "-u $USER -f --" ]] || exit 97
pid=100 found=1
while IFS= read -r line; do
  pid=$((pid + 1))
  [[ -n "$line" ]] && grep -qE -- "$5" <<< "$line" && { printf '%s\n' "$pid"; found=0; }
done <<< "${PROCESSES:-}"
exit "$found"
EOF
  chmod 0755 "$TEST_DIR/bin/"*
  export PATH="$TEST_DIR/bin:$PATH"
}
teardown() { rm -rf -- "$TEST_DIR"; }

# Only read-only queries reach the user manager and the process table.
read_only_calls() {
  ! grep -vE '^(systemctl --user is-active mirroros-shell\.service|pgrep -u alice -f -- )' "$CALLS"
}

@test "an active shell without competitors passes with exit 0" {
  PROCESSES=$'/usr/bin/qs -p /usr/share/mirroros/shell\n/usr/bin/lxpolkit-helper --x\n/usr/bin/vim xfce-polkit.txt' run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *FAIL* ]]
  [[ "$output" == *'ok: mirroros-shell.service: active'* ]]
  [[ "$output" == *'ok: competing agents: none running'* ]]
  [ "$(grep -c '^pgrep ' "$CALLS")" -eq "$(grep -cvE '^(#|$)' "$ROOT/usr/share/mirroros/polkit/agents")" ]
  read_only_calls
}

@test "an inactive shell fails naming the expected owner" {
  STATE=inactive run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL: mirroros-shell.service: inactive; expected active, enabled by configure for graphical-session.target'* ]]
  read_only_calls
}

@test "a competing agent fails even with a long name, from personal autostart or left by plan 02-36" {
  PROCESSES=$'/usr/bin/qs -p /usr/share/mirroros/shell\n/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1\nlxpolkit\n/usr/lib/hyprpolkitagent/hyprpolkitagent' \
    run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL: competing agent: polkit-gnome-authentication-agent-1 running (pid 102); expected the shell-hosted agent only'* ]]
  [[ "$output" == *'FAIL: competing agent: lxpolkit running (pid 103); expected the shell-hosted agent only'* ]]
  [[ "$output" == *'FAIL: competing agent: hyprpolkitagent running (pid 104); expected the shell-hosted agent only'* ]]
  [[ "$output" != *'ok: competing agents'* ]]
  read_only_calls
}

@test "a missing agent list fails" {
  rm "$ROOT/usr/share/mirroros/polkit/agents"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: agent list: $ROOT/usr/share/mirroros/polkit/agents missing; expected the copy installed by configure"* ]]
}
