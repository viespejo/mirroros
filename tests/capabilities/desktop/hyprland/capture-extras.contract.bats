#!/usr/bin/env bats
load ../../support

setup() {
  work="$BATS_TEST_TMPDIR"
  provider="$CFG_SOURCE_ROOT/capabilities/desktop/compositor/providers/hyprland"
}

teardown() {
  if [[ -n ${CFG_TEST_DIR:-} ]]; then cfg_test_teardown; fi
}

capture_doubles() {
  export CALLS="$work/calls" JOURNAL="$work/journal" CLIPBOARD="$work/clipboard" FREEZE_PID="$work/freeze-pid"
  mkdir "$work/bin"
  export PATH="$work/bin:$PATH"
  : > "$CALLS"
  : > "$JOURNAL"
  printf 'prior clipboard\n' > "$CLIPBOARD"
  printf 'eng+spa\n' > "$work/ocr-languages"
  unset MIRROROS_OCR_LANGS
  local sender_path="s|/usr/share/mirroros/shell/notifications/mirroros-notification-send|$work/bin/notify-send|"
  sed -e "$sender_path" -e "s|language_file=/usr/share/mirroros/compositor/ocr-languages|language_file=$work/ocr-languages|" \
    "$provider/capture-extras/ocr-backend" > "$work/ocr"
  qr="$work/qr"
  sed -e "$sender_path" "$provider/capture-extras/qr-backend" > "$qr"
  color="$provider/capture-extras/color-backend"
  cat > "$work/bin/double" <<'EOF'
#!/usr/bin/bash
name=${0##*/}
printf '%s <%s>\n' "$name" "$*" >> "$CALLS"
case "$name" in
  pkill) exit "${PKILL_STATUS:-1}" ;;
  hyprpicker)
    printf 'synthetic picker output\n'
    if [[ "$*" == '-a' ]]; then exit "${PICKER_STATUS:-0}"; fi
    [[ "$*" == '-r -z' ]] || exit 97
    printf '%s\n' "$$" > "$FREEZE_PID"
    trap 'exit 0' TERM
    while :; do sleep .05; done ;;
  slurp)
    case ${SELECTION_OUTCOME:-success} in
      cancel) printf 'selection cancelled\n' >&2; exit 1 ;;
      failure) printf 'synthetic selector error\n' >&2; exit 1 ;;
      *) printf '12,-8 100x200\n' ;;
    esac ;;
  grim)
    [[ "$#" == 3 && "$1" == -g && "$2" == '12,-8 100x200' && "$3" == - ]] || exit 97
    printf 'synthetic grim diagnostic\n' >&2
    printf 'synthetic image stream\n'
    exit "${GRIM_STATUS:-0}" ;;
  tesseract|zbarimg)
    if [[ "$*" == --list-langs ]]; then printf '%s\n' eng spa; exit 0; fi
    [[ "$(cat)" == 'synthetic image stream' ]] || exit 97
    printf 'synthetic recognizer diagnostic\n' >&2
    if [[ "${DECODE_STATUS:-0}" != 0 ]]; then exit "$DECODE_STATUS"; fi
    if [[ "${DECODE_EMPTY:-0}" == 1 ]]; then exit 0; fi
    printf 'synthetic %s payload\n' "$name" ;;
  wl-copy)
    value="$(cat)"
    printf 'synthetic clipboard diagnostic\n' >&2
    if [[ "${COPY_STATUS:-0}" != 0 ]]; then exit "$COPY_STATUS"; fi
    printf '%s' "$value" > "$CLIPBOARD" ;;
  notify-send) printf 'synthetic notification diagnostic\n'; exit "${NOTIFY_STATUS:-0}" ;;
  systemd-cat) cat >> "$JOURNAL"; printf 'synthetic journal diagnostic\n' >&2 ;;
  *) exit 97 ;;
esac
EOF
  chmod 0755 "$work/bin/double"
  for tool in pkill hyprpicker slurp grim tesseract zbarimg wl-copy notify-send systemd-cat; do
    ln -s double "$work/bin/$tool"
  done
}

freeze_was_cleaned() {
  [ -s "$FREEZE_PID" ]
  ! kill -0 "$(< "$FREEZE_PID")" 2>/dev/null
}

capture_diagnostics_are_clean() {
  [ -z "$output" ]
  ! grep -q 'synthetic' "$CALLS" "$JOURNAL"
}

@test "Color keeps the upstream stop-or-start toggle and normalizes picker failure" {
  capture_doubles
  run env PKILL_STATUS=0 bash "$color"
  [ "$status" -eq 0 ]
  [ "$(< "$CALLS")" = 'pkill <hyprpicker>' ]
  : > "$CALLS"
  run bash "$color"
  [ "$status" -eq 0 ]
  grep -qxF 'hyprpicker <-a>' "$CALLS"
  ! grep -q '^notify-send ' "$CALLS"
  run env PICKER_STATUS=7 bash "$color"
  [ "$status" -eq 1 ]
  grep -qxF 'Color picker failed.' "$JOURNAL"
  capture_diagnostics_are_clean
}

@test "direct OCR streams the selected image and copies normally using the managed default or explicit override" {
  capture_doubles
  run env LC_ALL=C NOTIFY_STATUS=7 bash "$work/ocr"
  [ "$status" -eq 0 ]
  grep -qxF 'grim <-g 12,-8 100x200 ->' "$CALLS"
  grep -qxF 'tesseract <stdin stdout --oem 1 --psm 6 -l eng+spa --dpi 300 -c preserve_interword_spaces=1>' "$CALLS"
  grep -qxF 'wl-copy <>' "$CALLS"
  [ "$(< "$CLIPBOARD")" = 'synthetic tesseract payload' ]
  grep -qxF $'notify-send <-u low --transient -g \363\260\264\221 -- Text copied Paste the recognized text where you need it.>' "$CALLS"
  freeze_was_cleaned
  : > "$CALLS"
  run env MIRROROS_OCR_LANGS=spa bash "$work/ocr"
  [ "$status" -eq 0 ]
  grep -qxF 'tesseract <stdin stdout --oem 1 --psm 6 -l spa --dpi 300 -c preserve_interword_spaces=1>' "$CALLS"
  freeze_was_cleaned
  capture_diagnostics_are_clean
}

@test "direct OCR rejects invalid defaults and empty or unavailable overrides before selection" {
  capture_doubles
  for languages in '' eng++spa eng+fra; do
    run env MIRROROS_OCR_LANGS="$languages" bash "$work/ocr"
    [ "$status" -eq 1 ]
    ! grep -q '^hyprpicker ' "$CALLS"
  done
  printf 'spa\n' > "$work/ocr-languages"
  run bash "$work/ocr"
  [ "$status" -eq 1 ]
  rm "$work/ocr-languages"
  run bash "$work/ocr"
  [ "$status" -eq 1 ]
  grep -qxF 'OCR language default is invalid. Rerun mirroros-configure.' "$JOURNAL"
  grep -qxF 'OCR language default is missing. Rerun mirroros-configure.' "$JOURNAL"
  grep -qxF 'A requested OCR model is unavailable.' "$JOURNAL"
  ! grep -qE '^(hyprpicker|wl-copy|notify-send) ' "$CALLS"
  capture_diagnostics_are_clean
}

@test "QR streams directly to QR-only zbar without D-Bus and copies only with the sensitive flag" {
  capture_doubles
  run env LC_ALL=C bash "$qr"
  [ "$status" -eq 0 ]
  grep -qxF 'grim <-g 12,-8 100x200 ->' "$CALLS"
  grep -qxF 'zbarimg <-q --raw --nodbus -Sdisable -Sqrcode.enable ->' "$CALLS"
  grep -qxF 'wl-copy <--sensitive>' "$CALLS"
  [ "$(< "$CLIPBOARD")" = 'synthetic zbarimg payload' ]
  grep -qxF $'notify-send <-u low --transient -g \363\260\220\262 -- QR code copied Paste the result where you need it.>' "$CALLS"
  freeze_was_cleaned
  capture_diagnostics_are_clean
}

@test "OCR and QR cancel silently and clean up the freeze without changing the clipboard" {
  capture_doubles
  for script in "$work/ocr" "$qr"; do
    : > "$CALLS"
    run env SELECTION_OUTCOME=cancel bash "$script"
    [ "$status" -eq 0 ]
    [ "$(< "$CLIPBOARD")" = 'prior clipboard' ]
    [ ! -s "$JOURNAL" ]
    ! grep -qE '^(grim|wl-copy|notify-send) ' "$CALLS"
    freeze_was_cleaned
    capture_diagnostics_are_clean
  done
}

@test "QR distinguishes no result from selector, capture and decoder failures and cleans up on each" {
  capture_doubles
  run env LC_ALL=C DECODE_STATUS=4 bash "$qr"
  [ "$status" -eq 1 ]
  grep -qxF $'notify-send <-u low --transient -g \363\260\220\262 -- No QR code found Try selecting a region that includes the entire code.>' "$CALLS"
  freeze_was_cleaned
  capture_diagnostics_are_clean
  for setting in 'SELECTION_OUTCOME=failure' 'DECODE_STATUS=2' 'DECODE_EMPTY=1' 'GRIM_STATUS=7 DECODE_STATUS=4'; do
    read -ra env_args <<< "$setting"
    : > "$CALLS"
    : > "$JOURNAL"
    run env "${env_args[@]}" bash "$qr"
    [ "$status" -eq 1 ]
    ! grep -qE '^(wl-copy|notify-send) ' "$CALLS"
    grep -q 'failed\.$' "$JOURNAL"
    freeze_was_cleaned
    capture_diagnostics_are_clean
  done
  [ "$(< "$CLIPBOARD")" = 'prior clipboard' ]
}

@test "OCR and QR fail without a success notification when copy fails or no text can be copied" {
  capture_doubles
  for script in "$work/ocr" "$qr"; do
    : > "$CALLS"
    run env COPY_STATUS=7 bash "$script"
    [ "$status" -eq 1 ]
    ! grep -q '^notify-send ' "$CALLS"
    grep -q '^Could not copy ' "$JOURNAL"
    freeze_was_cleaned
    capture_diagnostics_are_clean
  done
  for setting in 'DECODE_EMPTY=1' 'GRIM_STATUS=7' 'DECODE_STATUS=2'; do
    : > "$CALLS"
    run env "$setting" bash "$work/ocr"
    [ "$status" -eq 1 ]
    ! grep -qE '^(wl-copy|notify-send) ' "$CALLS"
    freeze_was_cleaned
    capture_diagnostics_are_clean
  done
  [ "$(< "$CLIPBOARD")" = 'prior clipboard' ]
}

@test "a missing sender leaves OCR and QR copies successful and QR misses unsuccessful" {
  capture_doubles
  rm -- "$work/bin/notify-send"
  run bash "$work/ocr"
  [ "$status" -eq 0 ]
  [ "$(< "$CLIPBOARD")" = 'synthetic tesseract payload' ]
  run bash "$qr"
  [ "$status" -eq 0 ]
  [ "$(< "$CLIPBOARD")" = 'synthetic zbarimg payload' ]
  run env DECODE_STATUS=4 bash "$qr"
  [ "$status" -eq 1 ]
  [ "$(< "$CLIPBOARD")" = 'synthetic zbarimg payload' ]
  capture_diagnostics_are_clean
}

@test "Hyprland manages English and Spanish OCR defaults and leaves an unchanged rerun untouched" {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/compositor/providers/hyprland)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/share/wayland-sessions"
  printf '[Desktop Entry]\nExec=uwsm start hyprland.desktop\n' > "$MIRROROS_CONFIGURE_ROOT/usr/share/wayland-sessions/hyprland-uwsm.desktop"
  printf '1.26.2-4.4\n' > "$CFG_TEST_INSTALLED/omasnap"
  printf 'LANG=en_US.UTF-8\nLC_TIME=en_US.UTF-8\nLC_MESSAGES=es_ES.UTF-8\n' > "$MIRROROS_CONFIGURE_ROOT/etc/locale.conf"
  local default="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/compositor/ocr-languages"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/english"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  cmp -s "$default" <(printf 'eng\n')
  [ -f "$CFG_TEST_INSTALLED/tesseract-data-eng" ]
  ! grep -q 'tesseract-data-spa' "$CFG_TEST_CALLS"
  for action in color ocr qr; do
    backend="${default%/*}/$action-backend"
    cmp "$provider/capture-extras/$action-backend" "$backend"
    [ "$(stat -c %a "$backend")" = 755 ]
  done
  printf 'LANG="es_ES.UTF-8"\nLC_TIME=en_US.UTF-8\n' > "$MIRROROS_CONFIGURE_ROOT/etc/locale.conf"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/spanish"
  [ "$status" -eq 0 ]
  cmp -s "$default" <(printf 'eng+spa\n')
  grep -qxF 'pacman -S --needed --noconfirm -- extra/tesseract-data-spa' "$CFG_TEST_CALLS"
  grep -qxF $'tesseract-data-spa\t1.0-1\textra' "$CFG_TEST_DIR/spanish/packages.tsv"
  stamp="$(stat -c '%y:%i' "$default")"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'hyprland: unchanged'* ]]
  cfg_test_no_install
  [ "$(stat -c '%y:%i' "$default")" = "$stamp" ]
  printf 'LANG=en_US.UTF-8\n' > "$MIRROROS_CONFIGURE_ROOT/etc/locale.conf"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  cmp -s "$default" <(printf 'eng\n')
  [ -f "$CFG_TEST_INSTALLED/tesseract-data-spa" ]
  ! grep -q 'tesseract-data-spa' "$CFG_TEST_CALLS"
  cfg_test_no_install
}
