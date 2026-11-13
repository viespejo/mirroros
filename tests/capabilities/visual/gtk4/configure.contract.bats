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
  [ ! -e "$dest/launch" ]
  [ ! -e "$dest/share" ]
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
  [ ! -e "$dest/entries" ]
  local entry="$MIRROROS_CONFIGURE_ROOT/usr/share/themes/MirrorOS-default/gtk-4.0"
  bash "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/install-runtime" check \
    "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/entries/default" "$entry" \
    "$(stat -c %u "$MIRROROS_CONFIGURE_ROOT")" "$(stat -c %g "$MIRROROS_CONFIGURE_ROOT")"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/entries/default/gtk.css" "$entry/gtk.css"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/entries/default/gtk-dark.css" "$entry/gtk-dark.css"
  [ "$(stat -c %a "$entry/gtk.css")" = 644 ]
  grep -qxF "mirroros-gtk4-entry-default"$'\t'"capabilities/visual/gtk4/entries/default"$'\t\t\t'"manifest-sha256:$(sha256sum < "$entry/.mirroros-manifest" | cut -d' ' -f1)" \
    "$CFG_TEST_DIR/first/sources.tsv"
  [ ! -e "$dest/icons" ]
  local icons="$MIRROROS_CONFIGURE_ROOT/usr/share/icons/MirrorOS-default"
  bash "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/install-runtime" check \
    "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/icons/default" "$icons" \
    "$(stat -c %u "$MIRROROS_CONFIGURE_ROOT")" "$(stat -c %g "$MIRROROS_CONFIGURE_ROOT")"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/icons/default/index.theme" "$icons/index.theme"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/icons/default/symbolic/status/emblem-default-symbolic.svg" \
    "$icons/symbolic/status/emblem-default-symbolic.svg"
  [ "$(stat -c %a "$icons/index.theme")" = 644 ]
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/icons/Adwaita" ]
  grep -qxF "mirroros-gtk4-icons-default"$'\t'"capabilities/visual/gtk4/icons/default"$'\t\t\t'"manifest-sha256:$(sha256sum < "$icons/.mirroros-manifest" | cut -d' ' -f1)" \
    "$CFG_TEST_DIR/first/sources.tsv"
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/etc/dconf" ]
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
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/base.css" "$dest/base.css"
  [ ! -e "$dest/launch" ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/themes/gtk4" ]
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/entries/default/gtk.css" \
    "$CFG_TEST_TARGET_ROOT/usr/share/themes/MirrorOS-default/gtk-4.0/gtk.css"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/icons/default/index.theme" \
    "$CFG_TEST_TARGET_ROOT/usr/share/icons/MirrorOS-default/index.theme"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/gtk4: unchanged'* ]]
}

@test "GTK4 configure preserves locally modified styles and assets" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk4"
  printf '\n/* local change */\n' >> "$dest/base.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -q 'local change' "$dest/base.css"
  cp "$CFG_SOURCE_ROOT/capabilities/visual/gtk4/base.css" "$dest/base.css"
  local icon="$dest/assets/check-symbolic.svg"
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
  [ -f "$dest/base.css" ]
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

@test "GTK4 configure preserves a modified unknown or linked native theme entry" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local themes="$MIRROROS_CONFIGURE_ROOT/usr/share/themes"
  printf '\n/* local entry */\n' >> "$themes/MirrorOS-default/gtk-4.0/gtk.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -q 'local entry' "$themes/MirrorOS-default/gtk-4.0/gtk.css"
  rm -rf "$themes/MirrorOS-default"
  mkdir -p "$themes/MirrorOS-default/gtk-4.0"
  printf 'keep\n' > "$themes/MirrorOS-default/gtk-4.0/gtk.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -qx keep "$themes/MirrorOS-default/gtk-4.0/gtk.css"
  rm -rf "$themes/MirrorOS-default"
  mkdir -p "$CFG_TEST_DIR/other"
  ln -s "$CFG_TEST_DIR/other" "$themes/MirrorOS-default"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ -L "$themes/MirrorOS-default" ]
  [ ! -e "$CFG_TEST_DIR/other/gtk-4.0" ]
}

@test "GTK4 configure preserves a modified unknown or linked native icon theme" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local icons="$MIRROROS_CONFIGURE_ROOT/usr/share/icons/MirrorOS-default"
  printf '\n<!-- local icon -->\n' >> "$icons/scalable/status/emblem-default.svg"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -q 'local icon' "$icons/scalable/status/emblem-default.svg"
  rm -rf "$icons"
  mkdir -p "$icons"
  printf 'keep\n' > "$icons/index.theme"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -qx keep "$icons/index.theme"
  rm -rf "$icons"
  mkdir -p "$CFG_TEST_DIR/other"
  ln -s "$CFG_TEST_DIR/other" "$icons"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ -L "$icons" ]
  [ ! -e "$CFG_TEST_DIR/other/index.theme" ]
}
