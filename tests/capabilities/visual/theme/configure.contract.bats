#!/usr/bin/env bats
# Theme step through configure, with temporary roots and test doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(visual/theme)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}
teardown() { cfg_test_teardown; }

@test "running configure publishes the theme and preserves a modified delivery" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  [[ "$output" == *'visual/theme: changed'* ]]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes/default"
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/default/colors.toml" "$dest/colors.toml"
  [ -f "$dest/LICENSE.omarchy" ]
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/default/hyprland.lua" "$dest/hyprland.lua"
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/resolve-current" "${dest%/default}/resolve-current"
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/check-trusted-path" "${dest%/default}/check-trusted-path"
  [ "$(readlink "$CFG_TEST_HOME/.local/state/mirroros/current/theme")" = /usr/share/mirroros/themes/default ]
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/theme: unchanged'* ]]
  printf '# local change\n' >> "$dest/colors.toml"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -qF '# local change' "$dest/colors.toml"
}

@test "configure repairs an absent theme tree but preserves an incomplete or linked delivery" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes/default"
  rm -rf "$dest"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/default/colors.toml" "$dest/colors.toml"

  rm "$dest/colors.toml"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ ! -e "$dest/colors.toml" ]
  ln -s "$CFG_TEST_DIR/code/capabilities/visual/theme/default/colors.toml" "$dest/colors.toml"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ -L "$dest/colors.toml" ]
}

@test "target configure publishes only below the target root" {
  cfg_test_target_context
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/default/colors.toml" \
    "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/themes/default/colors.toml"
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/default/hyprland.lua" \
    "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/themes/default/hyprland.lua"
  [ "$(readlink "$CFG_TEST_HOME/.local/state/mirroros/current/theme")" = /usr/share/mirroros/themes/default ]
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/theme: unchanged'* ]]
}

@test "configure preserves a modified selection helper" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local helper="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes/resolve-current"
  printf '# local change\n' >> "$helper"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -qF '# local change' "$helper"
}

@test "configure preserves a conflicting user theme link" {
  mkdir -p "$CFG_TEST_HOME/.local/state/mirroros/current"
  ln -s /unknown/theme "$CFG_TEST_HOME/.local/state/mirroros/current/theme"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ] || { printf 'status=%s\n%s\n' "$status" "$output" >&3; return 1; }
  [ "$(readlink "$CFG_TEST_HOME/.local/state/mirroros/current/theme")" = /unknown/theme ]
}

@test "configure refuses an untrusted theme parent without replacing it" {
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros"
  ln -s "$CFG_TEST_DIR" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ] || { printf 'status=%s\n%s\n' "$status" "$output" >&3; return 1; }
  [ -L "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes" ]
  [ ! -e "$CFG_TEST_DIR/default" ]
}
