#!/usr/bin/env bats
# The lock-screen wrapper run by hypridle's lock_cmd, with hyprctl and hyprlock doubles; nothing is locked.

setup() {
  TEST_DIR="$(mktemp -d)"
  SCRIPT="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/lock/lock-screen"
  export CALLS="$TEST_DIR/calls"
  export HOME="$TEST_DIR/home"
  GEOMETRY="$HOME/.cache/mirroros/lock/geometry.conf"
  mkdir "$TEST_DIR/bin"
  # Two keyboards; the second is main and has layout index ${ACTIVE_INDEX:-1} active.
  # Two monitors; the first has scale 2, the second is focused with scale ${SCALE:-1.6}.
  cat > "$TEST_DIR/bin/hyprctl" <<'EOF'
#!/usr/bin/bash
printf 'hyprctl %s\n' "$*" >> "$CALLS"
case "$1" in
  monitors)
    [[ "${HYPRCTL_MONITORS_FAIL:-0}" != 1 ]] || exit 1
    printf '[{\n    "name": "DP-1",\n    "activeWorkspace": {\n        "id": 2\n    },\n    "scale": 2.00,\n    "focused": false\n},{\n'
    printf '    "name": "Virtual-1",\n    "scale": %s,\n    "focused": true\n}]\n' "${SCALE:-1.6}" ;;
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

# The generated field geometry and the fingerprint text, absolute glyph size and offset.
geometry_is() {
  [ "$(grep '^\$field_' "$GEOMETRY")" = "\$field_size = $1, $2"$'\n'"\$field_border = $3" ]
  [ "$(grep '^\$fprint_' "$GEOMETRY")" = "\$fprint_font_size = $4"$'\n'"\$fprint_glyph_size = $5"$'\n'"\$fprint_offset = $6" ]
}

@test "locks in the first layout and restores the previous layout after unlocking" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = "$(printf 'hyprctl monitors -j\nhyprctl devices -j\nhyprctl switchxkblayout all 0\nhyprlock\nhyprctl switchxkblayout all 1')" ]
}

@test "the previous layout is restored even when it was the first one" {
  ACTIVE_INDEX=0 run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 "$CALLS")" = 'hyprctl switchxkblayout all 0' ]
}

@test "an unreadable layout still locks and restores nothing" {
  HYPRCTL_DEVICES_FAIL=1 run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = "$(printf 'hyprctl monitors -j\nhyprctl devices -j\nhyprctl switchxkblayout all 0\nhyprlock')" ]
}

@test "a failed layout switch never prevents locking and hyprlock's status is returned" {
  HYPRCTL_SWITCH_FAIL=1 HYPRLOCK_STATUS=3 run "$SCRIPT"
  [ "$status" -eq 3 ]
  grep -qx hyprlock "$CALLS"
  [ "$(grep -c 'switchxkblayout' "$CALLS")" -eq 2 ]
}

@test "the field geometry follows the focused monitor's scale in physical pixels" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  geometry_is 605 91 5 22 29491 -100
  SCALE=1 run "$SCRIPT"
  [ "$status" -eq 0 ]
  geometry_is 378 57 3 14 18432 -63
  SCALE=1.25 run "$SCRIPT"
  [ "$status" -eq 0 ]
  geometry_is 473 71 4 18 23040 -78
  SCALE=2.50 run "$SCRIPT"
  [ "$status" -eq 0 ]
  geometry_is 945 143 8 35 46080 -156
  [ "$(find "${GEOMETRY%/*}" -type f | wc -l)" -eq 1 ]
}

@test "an unreadable or invalid scale removes the geometry and still locks" {
  run "$SCRIPT"
  [ -f "$GEOMETRY" ]
  : > "$CALLS"
  HYPRCTL_MONITORS_FAIL=1 run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -e "$GEOMETRY" ]
  grep -qx hyprlock "$CALLS"
  local config="${SCRIPT%/*}/hyprlock.conf"
  grep -qxF '$fprint_font_size = 22' "$config"
  grep -qxF '$fprint_glyph_size = 29491' "$config"
  grep -qxF '$fprint_offset = -100' "$config"
  run "$SCRIPT"
  SCALE=0 run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -e "$GEOMETRY" ]
  SCALE='"x"' run "$SCRIPT"
  [ ! -e "$GEOMETRY" ]
}

@test "the fingerprint prompt is empty without a message" {
  run bash "${SCRIPT%/*}/fingerprint-prompt" '' 18432
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run bash "${SCRIPT%/*}/fingerprint-prompt"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the fingerprint prompt shows the UTF-8 glyph and message at an absolute scaled size" {
  local glyph=$'\xf3\xb0\x88\xb7'
  run bash "${SCRIPT%/*}/fingerprint-prompt" 'Use your fingerprint or password' 18432
  [ "$status" -eq 0 ]
  [ "$output" = "<span size=\"18432\">$glyph</span>  Use your fingerprint or password" ]
  run bash "${SCRIPT%/*}/fingerprint-prompt" 'Reading fingerprint…' 23040
  [ "$status" -eq 0 ]
  [ "$output" = "<span size=\"23040\">$glyph</span>  Reading fingerprint…" ]
  run bash "${SCRIPT%/*}/fingerprint-prompt" 'Reading fingerprint…'
  [ "$status" -eq 0 ]
  [ "$output" = "<span size=\"29491\">$glyph</span>  Reading fingerprint…" ]
  run bash "${SCRIPT%/*}/fingerprint-prompt" 'Reading fingerprint…' 'invalid" size="1'
  [ "$status" -eq 0 ]
  [ "$output" = "<span size=\"29491\">$glyph</span>  Reading fingerprint…" ]
}

@test "an unwritable geometry directory never prevents locking" {
  mkdir -p "$HOME/.cache/mirroros"
  : > "$HOME/.cache/mirroros/lock"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx hyprlock "$CALLS"
}
