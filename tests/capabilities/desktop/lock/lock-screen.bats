#!/usr/bin/env bats
# The lock-screen wrapper run by hypridle's lock_cmd, with hyprctl and hyprlock doubles; nothing is locked.

setup() {
  TEST_DIR="$(mktemp -d)"
  SCRIPT="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/lock/lock-screen"
  export CALLS="$TEST_DIR/calls"
  mkdir "$TEST_DIR/bin"
  # Two keyboards; the second is main and has layout index ${ACTIVE_INDEX:-1} active.
  cat > "$TEST_DIR/bin/hyprctl" <<'EOF'
#!/usr/bin/bash
printf 'hyprctl %s\n' "$*" >> "$CALLS"
case "$1" in
  devices)
    [[ "${HYPRCTL_DEVICES_FAIL:-0}" != 1 ]] || exit 1
    printf '{"keyboards": [{\n    "name": "power-button",\n    "active_layout_index": 0,\n    "main": false\n},{\n'
    printf '    "name": "kbd",\n    "active_layout_index": %s,\n    "main": true\n}]}\n' "${ACTIVE_INDEX:-1}" ;;
  switchxkblayout) [[ "${HYPRCTL_SWITCH_FAIL:-0}" != 1 ]] || exit 1; printf 'ok\n' ;;
esac
EOF
  # shellcheck disable=SC2016 # The double expands its variables when it runs.
  printf '#!/usr/bin/bash\nprintf "hyprlock\\n" >> "$CALLS"\nexit "${HYPRLOCK_STATUS:-0}"\n' > "$TEST_DIR/bin/hyprlock"
  chmod 0755 "$TEST_DIR/bin/"*
  export PATH="$TEST_DIR/bin:$PATH"
}

teardown() { rm -rf -- "$TEST_DIR"; }

@test "locks in the first layout and restores the previous layout after unlocking" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = "$(printf 'hyprctl devices -j\nhyprctl switchxkblayout all 0\nhyprlock\nhyprctl switchxkblayout all 1')" ]
}

@test "the previous layout is restored even when it was the first one" {
  ACTIVE_INDEX=0 run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$CALLS")" = 'hyprctl switchxkblayout all 0' ]
}

@test "an unreadable layout still locks and restores nothing" {
  HYPRCTL_DEVICES_FAIL=1 run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = "$(printf 'hyprctl devices -j\nhyprctl switchxkblayout all 0\nhyprlock')" ]
}

@test "a failed layout switch never prevents locking and hyprlock's status is returned" {
  HYPRCTL_SWITCH_FAIL=1 HYPRLOCK_STATUS=3 run "$SCRIPT"
  [ "$status" -eq 3 ]
  grep -qx hyprlock "$CALLS"
  [ "$(grep -c 'switchxkblayout' "$CALLS")" -eq 2 ]
}
