#!/usr/bin/env bats
# The greeter layout indicator helper (ADR 0015) with a hyprctl double; no compositor runs.

setup() {
  TEST_DIR="$(mktemp -d)"
  HELPER="$BATS_TEST_DIRNAME/../../../capabilities/desktop/compositor/providers/hyprland/greeter/layout-indicator"
  export MIRROROS_LAYOUT_STATE="$TEST_DIR/mirroros-greeter-layout"
  export HYPRCTL_CALLS="$TEST_DIR/calls" HYPRCTL_ACTIVE="$TEST_DIR/active"
  mkdir "$TEST_DIR/bin"
  printf 'Spanish\n' > "$HYPRCTL_ACTIVE"
  # Two keyboards as in the VM; the second is main. switchxkblayout toggles between the two layouts.
  cat > "$TEST_DIR/bin/hyprctl" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$*" >> "$HYPRCTL_CALLS"
case "$1" in
  switchxkblayout)
    [[ "${HYPRCTL_FAIL:-0}" != 1 ]] || { printf 'hyprctl: simulated failure\n' >&2; exit 3; }
    if [[ "$(< "$HYPRCTL_ACTIVE")" == Spanish ]]; then printf 'English (US)\n'; else printf 'Spanish\n'; fi \
      > "$HYPRCTL_ACTIVE.new" && mv "$HYPRCTL_ACTIVE.new" "$HYPRCTL_ACTIVE"
    printf 'ok\n' ;;
  devices)
    active="${HYPRCTL_NAME:-$(< "$HYPRCTL_ACTIVE")}"
    printf '{\n"keyboards": [{\n    "name": "power-button",\n    "active_keymap": "Other",\n    "main": false\n},{\n'
    printf '    "name": "usb-keyboard",\n    "active_keymap": "%s",\n    "capsLock": false,\n    "main": %s\n}]\n}\n' \
      "$active" "$([[ -n "${HYPRCTL_NO_MAIN:-}" ]] && echo false || echo true)" ;;
esac
EOF
  chmod 0755 "$TEST_DIR/bin/hyprctl"
  export PATH="$TEST_DIR/bin:$PATH"
}

teardown() { rm -rf -- "$TEST_DIR"; }

@test "current records the main keyboard's active layout without switching" {
  run "$HELPER" current
  [ "$status" -eq 0 ]
  [ "$(< "$MIRROROS_LAYOUT_STATE")" = Spanish ]
  run ! grep -q switchxkblayout "$HYPRCTL_CALLS"
  [ -z "$(find "$TEST_DIR" -name 'mirroros-greeter-layout.*')" ]
}

@test "without a main keyboard the first keyboard's layout is recorded" {
  HYPRCTL_NO_MAIN=1 run "$HELPER" current
  [ "$status" -eq 0 ]
  [ "$(< "$MIRROROS_LAYOUT_STATE")" = Other ]
}

@test "next and prev switch every keyboard and record the new layout" {
  run "$HELPER" next
  [ "$status" -eq 0 ]
  grep -qxF 'switchxkblayout all next' "$HYPRCTL_CALLS"
  [ "$(< "$MIRROROS_LAYOUT_STATE")" = 'English (US)' ]
  run "$HELPER" prev
  [ "$status" -eq 0 ]
  grep -qxF 'switchxkblayout all prev' "$HYPRCTL_CALLS"
  [ "$(< "$MIRROROS_LAYOUT_STATE")" = Spanish ]
}

@test "an unrecognized layout name or a failed switch keeps the previous state" {
  printf 'Spanish\n' > "$MIRROROS_LAYOUT_STATE"
  HYPRCTL_NAME='Bad"name' run "$HELPER" current
  [ "$status" -eq 1 ]
  [[ "$output" == *'Unrecognized active keyboard layout'* ]]
  HYPRCTL_FAIL=1 run "$HELPER" next
  [ "$status" -eq 3 ]
  [[ "$output" == *'simulated failure'* ]]
  [ "$(< "$MIRROROS_LAYOUT_STATE")" = Spanish ]
  [ -z "$(find "$TEST_DIR" -name 'mirroros-greeter-layout.*')" ]
}

@test "other arguments are rejected before hyprctl runs" {
  for args in '' 'toggle' 'next extra'; do
    # shellcheck disable=SC2086 # The cases are word lists.
    run "$HELPER" $args
    [ "$status" -eq 2 ]
    [[ "$output" == *'Usage: layout-indicator next|prev|current'* ]]
  done
  [ ! -e "$HYPRCTL_CALLS" ]
}
