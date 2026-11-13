#!/usr/bin/env bats
# Shared GTK4 resources have a publication owner independent of selectable palettes.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(visual/theme visual/gtk4)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}
teardown() { cfg_test_teardown; }

@test "GTK4 configure publishes its own runtime and provenance with an unchanged rerun" {
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  [[ "$output" == *'visual/gtk4: changed'* ]]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk4"
  bash "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/install-runtime" check \
    "$CFG_SOURCE_ROOT/capabilities/visual/gtk4" "$dest" \
    "$(stat -c %u "$MIRROROS_CONFIGURE_ROOT")" "$(stat -c %g "$MIRROROS_CONFIGURE_ROOT")"
  [ -x "$dest/launch" ]
  [ "$(stat -c %a "$dest/base.css")" = 644 ]
  [ -f "$dest/STRATA-LICENSE" ]
  [ -f "$dest/typography.css" ]
  [ -f "$dest/licenses/COPYING.yaru" ]
  [ -f "$dest/licenses/LICENSE_CCBYSA.yaru" ]
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/assets/check-symbolic.svg" "$dest/assets/check-symbolic.svg"
  for file in apply packages install-runtime sources.md theme.name; do [ ! -e "$dest/$file" ]; done
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes/gtk4" ]
  grep -qxF "mirroros-gtk4-runtime"$'\t'"capabilities/visual/gtk4"$'\t\t\t'"manifest-sha256:$(sha256sum < "$dest/.mirroros-manifest" | cut -d' ' -f1)" \
    "$CFG_TEST_DIR/first/sources.tsv"
  grep -qxF $'osaka-jade-gtk4\thttps://github.com/abhinav20sep/osaka-jade-theme\t\t2ac2934f2ebf62ad1088bc5ea434c4670b8cd2dc\t' \
    "$CFG_TEST_DIR/first/sources.tsv"
  grep -qxF $'strata-gtk4-font\thttps://github.com/lgse/strata\tv1.2.1\t491e6ba9735e821f9f49910ffd2582076196865c\t' \
    "$CFG_TEST_DIR/first/sources.tsv"
  [ ! -e "$CFG_TEST_HOME/.config/gtk-4.0" ]
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/gtk4: unchanged'* ]]
}

@test "target GTK4 configure publishes only below the target root and reruns unchanged" {
  cfg_test_target_context
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  local dest="$CFG_TEST_TARGET_ROOT/usr/share/mirroros/gtk4"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/launch" "$dest/launch"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/base.css" "$dest/base.css"
  [ -x "$dest/launch" ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/themes/gtk4" ]
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/gtk4: unchanged'* ]]
}

@test "GTK4 configure preserves locally modified styles and icon aliases" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk4"
  printf '\n/* local change */\n' >> "$dest/base.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -q 'local change' "$dest/base.css"
  cp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/base.css" "$dest/base.css"
  local icon="$dest/share/icons/Adwaita/symbolic/apps/chromium-browser-symbolic.svg"
  printf '\n<!-- local icon -->\n' >> "$icon"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -q 'local icon' "$icon"
}

@test "GTK4 configure repairs an absent delivery but preserves unknown directories" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk4"
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

@test "GTK4 configure preserves incomplete linked and unsafe runtime deliveries" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk4"
  rm "$dest/base.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ ! -e "$dest/base.css" ]
  ln -s typography.css "$dest/base.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ -L "$dest/base.css" ]
  rm "$dest/base.css"
  cp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/base.css" "$dest/base.css"
  chmod 0666 "$dest/base.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ "$(stat -c %a "$dest/base.css")" = 666 ]
}

@test "GTK4 configure refuses a linked runtime without writing through it" {
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros" "$CFG_TEST_DIR/other"
  ln -s "$CFG_TEST_DIR/other" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk4"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ -L "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk4" ]
  [ ! -e "$CFG_TEST_DIR/other/base.css" ]
}

@test "GTK4 standalone publication refuses an unsafe shared parent" {
  printf 'CFG_STEPS=(visual/gtk4)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros"
  chmod 0777 "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk4" ]
}
