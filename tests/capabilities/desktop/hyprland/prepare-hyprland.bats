#!/usr/bin/env bats

setup() {
  root="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
  home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home/.config/hypr"
  script="$root/capabilities/desktop/compositor/providers/hyprland/prepare-hyprland"
  config="$root/capabilities/desktop/compositor/providers/hyprland/hyprland.lua"
  legacy="$BATS_TEST_DIRNAME/hyprland-legacy.lua"
  encoded="$(base64 -w 0 < "$config")"
}

apply_config() { HOME="$home" bash "$script" "$encoded"; }

@test "creates and idempotently retains the reviewed configuration" {
  run apply_config
  [ "$status" -eq 0 ]
  [ "$output" = changed ]
  cmp "$config" "$home/.config/hypr/hyprland.lua"
  run apply_config
  [ "$output" = unchanged ]
}

@test "migrates only the exact old configuration" {
  cp "$legacy" "$home/.config/hypr/hyprland.lua"
  run apply_config
  [ "$output" = changed ]
  cmp "$config" "$home/.config/hypr/hyprland.lua"
  cp "$legacy" "$home/.config/hypr/hyprland.lua"
  printf '\n-- personal edit\n' >> "$home/.config/hypr/hyprland.lua"
  cp "$home/.config/hypr/hyprland.lua" "$BATS_TEST_TMPDIR/personal"
  run apply_config
  [[ "$output" == 'unchanged user-owned:'* ]]
  cmp "$BATS_TEST_TMPDIR/personal" "$home/.config/hypr/hyprland.lua"
}

@test "migrates only the exact previous jade configuration" {
  local jade="$BATS_TEST_DIRNAME/hyprland-jade-legacy.lua"
  cp "$jade" "$home/.config/hypr/hyprland.lua"
  run apply_config
  [ "$status" -eq 0 ]
  [ "$output" = changed ]
  cmp "$config" "$home/.config/hypr/hyprland.lua"
  cp "$jade" "$home/.config/hypr/hyprland.lua"
  printf '\n-- personal monitor\n' >> "$home/.config/hypr/hyprland.lua"
  cp "$home/.config/hypr/hyprland.lua" "$BATS_TEST_TMPDIR/personal-jade"
  run apply_config
  [[ "$output" == 'unchanged user-owned:'* ]]
  cmp "$BATS_TEST_TMPDIR/personal-jade" "$home/.config/hypr/hyprland.lua"
}

@test "migrates the exact previous themed configuration and preserves edits" {
  local themed="$BATS_TEST_DIRNAME/hyprland-theme-legacy.lua"
  cp "$themed" "$home/.config/hypr/hyprland.lua"
  run apply_config
  [ "$status" -eq 0 ]
  [ "$output" = changed ]
  cmp "$config" "$home/.config/hypr/hyprland.lua"
  cp "$themed" "$home/.config/hypr/hyprland.lua"
  printf '\n-- personal monitor\n' >> "$home/.config/hypr/hyprland.lua"
  cp "$home/.config/hypr/hyprland.lua" "$BATS_TEST_TMPDIR/personal-themed"
  run apply_config
  [[ "$output" == 'unchanged user-owned:'* ]]
  cmp "$BATS_TEST_TMPDIR/personal-themed" "$home/.config/hypr/hyprland.lua"
}

@test "preserves edits to the current configuration including monitor settings" {
  cp "$config" "$home/.config/hypr/hyprland.lua"
  printf '\n-- local monitor\nhl.monitor({ output = "Virtual-1", scale = 1.6 })\n' >> "$home/.config/hypr/hyprland.lua"
  cp "$home/.config/hypr/hyprland.lua" "$BATS_TEST_TMPDIR/personal"
  run apply_config
  [ "$status" -eq 0 ]
  [[ "$output" == 'unchanged user-owned:'* ]]
  cmp "$BATS_TEST_TMPDIR/personal" "$home/.config/hypr/hyprland.lua"
}

@test "leaves existing personal layers and links untouched" {
  printf 'personal monitor settings\n' > "$home/.config/hypr/monitors.lua"
  printf 'personal bindings\n' > "$home/.config/hypr/bindings.lua"
  ln -s "$BATS_TEST_TMPDIR/missing-input" "$home/.config/hypr/input.lua"
  cp "$home/.config/hypr/monitors.lua" "$BATS_TEST_TMPDIR/monitor-before"
  cp "$home/.config/hypr/bindings.lua" "$BATS_TEST_TMPDIR/bindings-before"
  run apply_config
  [ "$status" -eq 0 ]
  cmp "$BATS_TEST_TMPDIR/monitor-before" "$home/.config/hypr/monitors.lua"
  cmp "$BATS_TEST_TMPDIR/bindings-before" "$home/.config/hypr/bindings.lua"
  [ -L "$home/.config/hypr/input.lua" ]
  [ "$(readlink "$home/.config/hypr/input.lua")" = "$BATS_TEST_TMPDIR/missing-input" ]
  [ ! -e "$home/.config/hypr/looknfeel.lua" ]
  [ ! -e "$home/.config/hypr/autostart.lua" ]
}

@test "preserves broken configuration links" {
  ln -s "$BATS_TEST_TMPDIR/missing" "$home/.config/hypr/hyprland.lua"
  run apply_config
  [ "$status" -eq 0 ]
  [[ "$output" == 'unchanged user-owned:'* ]]
  [ "$(readlink "$home/.config/hypr/hyprland.lua")" = "$BATS_TEST_TMPDIR/missing" ]
  rm "$home/.config/hypr/hyprland.lua"
  ln -s "$BATS_TEST_TMPDIR/missing" "$home/.config/hypr/hyprland.conf"
  run apply_config
  [ "$status" -eq 0 ]
  [[ "$output" == 'unchanged user-owned:'* ]]
  [ ! -e "$home/.config/hypr/hyprland.lua" ]
  [ -L "$home/.config/hypr/hyprland.conf" ]
}

@test "preserves symbolic links and existing legacy configuration" {
  ln -s "$legacy" "$home/.config/hypr/hyprland.lua"
  run apply_config
  [[ "$output" == 'unchanged user-owned:'* ]]
  [ -L "$home/.config/hypr/hyprland.lua" ]
  rm "$home/.config/hypr/hyprland.lua"
  touch "$home/.config/hypr/hyprland.conf"
  run apply_config
  [[ "$output" == 'unchanged user-owned:'* ]]
  [ ! -e "$home/.config/hypr/hyprland.lua" ]
}
