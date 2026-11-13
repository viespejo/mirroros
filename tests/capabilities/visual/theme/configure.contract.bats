#!/usr/bin/env bats
# Theme step through configure, with temporary roots and test doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(visual/theme)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}
teardown() { cfg_test_teardown; }

@test "running configure publishes the theme and preserves a modified delivery" {
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  [[ "$output" == *'visual/theme: changed'* ]]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes/default"
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/default/colors.toml" "$dest/colors.toml"
  [ -f "$dest/LICENSE.omarchy" ]
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/default/gtk-4.0.css" "$dest/gtk-4.0.css"
  local gtk4="${dest%/default}/gtk4"
  bash "$CFG_TEST_DIR/code/capabilities/visual/theme/install-theme" check \
    "$CFG_TEST_DIR/code/capabilities/visual/theme/gtk4" "$gtk4" \
    "$(stat -c %u "$MIRROROS_CONFIGURE_ROOT")" "$(stat -c %g "$MIRROROS_CONFIGURE_ROOT")"
  [ -x "$gtk4/launch" ]
  [ -f "$gtk4/STRATA-LICENSE" ]
  grep -qxF "mirroros-gtk4-runtime"$'\t'"capabilities/visual/theme/gtk4"$'\t\t\t'"manifest-sha256:$(sha256sum < "$gtk4/.mirroros-manifest" | cut -d' ' -f1)" \
    "$CFG_TEST_DIR/first/sources.tsv"
  grep -qxF $'strata-gtk4-css\thttps://github.com/lgse/strata\tv1.2.1\t491e6ba9735e821f9f49910ffd2582076196865c\t' \
    "$CFG_TEST_DIR/first/sources.tsv"
  [ ! -e "$CFG_TEST_HOME/.config/gtk-4.0" ]
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/default/hyprland.lua" "$dest/hyprland.lua"
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/default/hyprlock.conf" "$dest/hyprlock.conf"
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
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/default/gtk-4.0.css" \
    "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/themes/default/gtk-4.0.css"
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/gtk4/launch" \
    "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/themes/gtk4/launch"
  [ -x "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/themes/gtk4/launch" ]
  [ "$(readlink "$CFG_TEST_HOME/.local/state/mirroros/current/theme")" = /usr/share/mirroros/themes/default ]
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/theme: unchanged'* ]]
}

@test "configure preserves locally modified GTK4 styles and icon aliases" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes/gtk4"
  printf '\n/* local change */\n' >> "$dest/base.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -q 'local change' "$dest/base.css"
  cp "$CFG_TEST_DIR/code/capabilities/visual/theme/gtk4/base.css" "$dest/base.css"
  local icon="$dest/share/icons/Adwaita/symbolic/apps/chromium-browser-symbolic.svg"
  printf '\n<!-- local icon -->\n' >> "$icon"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -q 'local icon' "$icon"
}

@test "configure repairs an absent GTK4 delivery but preserves unknown directories" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes/gtk4"
  rm -rf "$dest"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ -x "$dest/launch" ]
  rm -rf "$dest"
  mkdir "$dest"
  printf 'keep\n' > "$dest/personal-file"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -qx keep "$dest/personal-file"
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

@test "configure publishes the theme backgrounds and selects the logo without replacing a selection" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  local source="$CFG_TEST_DIR/code/capabilities/visual/theme/default/backgrounds"
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes/default/backgrounds"
  local link="$CFG_TEST_HOME/.local/state/mirroros/current/background"
  diff -r "$source" "$dest"
  [ "$(stat -c %a "$dest/1-phase-space-jade.png")" = 644 ]
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/backgrounds" ]
  [ ! -e "$CFG_TEST_HOME/.config/mirroros/backgrounds" ]
  [ "$(readlink "$link")" = /usr/share/mirroros/themes/default/backgrounds/2-mirroros-jade.png ]
  ln -sfn /usr/share/mirroros/themes/default/backgrounds/1-phase-space-jade.png "$link"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/theme: unchanged'* ]]
  [ "$(readlink "$link")" = /usr/share/mirroros/themes/default/backgrounds/1-phase-space-jade.png ]
  printf 'local' >> "$dest/2-mirroros-jade.png"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ "$(tail -c 5 "$dest/2-mirroros-jade.png")" = local ]
}

@test "target configure publishes the theme backgrounds only below the target root" {
  cfg_test_target_context
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  cmp "$CFG_TEST_DIR/code/capabilities/visual/theme/default/backgrounds/1-phase-space-jade.png" \
    "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/themes/default/backgrounds/1-phase-space-jade.png"
  [ "$(readlink "$CFG_TEST_HOME/.local/state/mirroros/current/background")" = \
    /usr/share/mirroros/themes/default/backgrounds/2-mirroros-jade.png ]
}
