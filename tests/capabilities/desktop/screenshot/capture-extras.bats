#!/usr/bin/env bats

setup() {
  root="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
  work="$BATS_TEST_TMPDIR"
  export CALLS="$work/calls" BACKEND_STATUS=0
  mkdir "$work/bin"
  : > "$CALLS"
  export PATH="$work/bin:$PATH"
  for action in color ocr qr; do
    sed "s|backend=/usr/share/mirroros/compositor/|backend=$work/|" \
      "$root/capabilities/desktop/screenshot/$action" > "$work/$action"
    cat > "$work/$action-backend" <<'EOF'
#!/usr/bin/bash
printf '%s argc=%s\n' "${0##*/}" "$#" >> "$CALLS"
printf 'synthetic capture content\n'
printf 'synthetic tool error\n' >&2
exit "$BACKEND_STATUS"
EOF
    chmod 0755 "$work/$action-backend"
  done
  cat > "$work/bin/notify-send" <<'EOF'
#!/usr/bin/bash
printf 'notify %s\n' "$*" >> "$CALLS"
printf 'synthetic notification error\n' >&2
exit 7
EOF
  chmod 0755 "$work/bin/notify-send"
}

@test "capture extras reject argv before dispatch and call only the fixed backend with no arguments" {
  for action in color ocr qr; do
    : > "$CALLS"
    run bash "$work/$action" --help
    [ "$status" -eq 2 ]
    [ "$output" = "Usage: $action" ]
    [ ! -s "$CALLS" ]
    run bash "$work/$action"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(< "$CALLS")" = "$action-backend argc=0" ]
  done
}

@test "capture extras normalize backend failures without forwarding any backend output" {
  for action in color ocr qr; do
    for code in 1 2 9; do
      run env BACKEND_STATUS="$code" bash "$work/$action"
      [ "$status" -eq 1 ]
      [[ "$output" == *'journalctl --user -t mirroros-screenshot'* && "$output" != *synthetic* ]]
    done
  done
}

@test "capture extras advise configure with the matching glyph for missing backends despite notification failure" {
  export LC_ALL=C
  for action in color ocr qr; do
    case "$action" in
      color) title='Color failed'; glyph=$'\363\260\203\211' ;;
      ocr) title='OCR failed'; glyph=$'\363\260\264\221' ;;
      qr) title='QR capture failed'; glyph=$'\363\260\220\262' ;;
    esac
    : > "$CALLS"
    rm "$work/$action-backend"
    run bash "$work/$action"
    [ "$status" -eq 1 ]
    [[ "$output" == *'Rerun mirroros-configure'* && "$output" != *synthetic* ]]
    [ "$(< "$CALLS")" = "notify --urgency=normal --hint=int:transient:1 --hint=string:omarchy-glyph:$glyph $title $output" ]
  done
}
