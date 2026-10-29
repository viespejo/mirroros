#!/usr/bin/env bats

setup() {
  root="$(cd "$BATS_TEST_DIRNAME/../../../.." && pwd)"
  home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home/.config/hypr"
  script="$root/capabilities/desktop/compositor/providers/hyprland/prepare-monitors"
  template="$root/capabilities/desktop/compositor/providers/hyprland/personal-monitors.lua"
  encoded="$(base64 -w 0 < "$template")"
  dest="$home/.config/hypr/monitors.lua"
}

prepare() { HOME="$home" bash "$script" "$encoded"; }

@test "creates a commented template and preserves later edits" {
  run prepare
  [ "$status" -eq 0 ]
  [ "$output" = changed ]
  cmp "$template" "$dest"
  printf '\n-- personal edit\n' >> "$dest"
  cp "$dest" "$BATS_TEST_TMPDIR/expected"
  run prepare
  [ "$status" -eq 0 ]
  [[ "$output" == 'unchanged user-owned:'* ]]
  cmp "$BATS_TEST_TMPDIR/expected" "$dest"
}

@test "preserves existing files, directories and links including broken links" {
  printf 'personal\n' > "$dest"
  run prepare
  [ "$status" -eq 0 ]
  [ "$(< "$dest")" = personal ]
  rm "$dest"
  mkdir "$dest"
  run prepare
  [ "$status" -eq 0 ]
  [ -d "$dest" ]
  rmdir "$dest"
  ln -s "$template" "$dest"
  run prepare
  [ "$status" -eq 0 ]
  [ -L "$dest" ]
  rm "$dest"
  ln -s "$BATS_TEST_TMPDIR/missing" "$dest"
  run prepare
  [ "$status" -eq 0 ]
  [ -L "$dest" ]
  [ "$(readlink "$dest")" = "$BATS_TEST_TMPDIR/missing" ]
}
