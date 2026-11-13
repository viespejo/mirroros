#!/usr/bin/env bats
# GTK3 resources are published without selecting a session theme or changing portals.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(visual/theme visual/gtk3)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}
teardown() { cfg_test_teardown; }

@test "GTK3 configure publishes its runtime palette and provenance with an unchanged rerun" {
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  [[ "$output" == *'visual/gtk3: changed'* ]]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk3"
  bash "$CFG_SOURCE_ROOT/capabilities/visual/gtk3/install-runtime" check \
    "$CFG_SOURCE_ROOT/capabilities/visual/gtk3" "$dest" \
    "$(stat -c %u "$MIRROROS_CONFIGURE_ROOT")" "$(stat -c %g "$MIRROROS_CONFIGURE_ROOT")"
  [ "$(stat -c %a "$dest/base.css")" = 644 ]
  [ -f "$dest/STRATA-LICENSE" ]
  [ -f "$dest/typography.css" ]
  [ -f "$dest/licenses/COPYING.yaru" ]
  [ -f "$dest/licenses/LICENSE_CCBYSA.yaru" ]
  [ ! -e "$dest/share" ]
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk3/assets/check-symbolic.svg" "$dest/assets/check-symbolic.svg"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/theme/default/gtk-3.0.css" \
    "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes/default/gtk-3.0.css"
  for file in apply packages install-runtime sources.md theme.name launch share/icons; do [ ! -e "$dest/$file" ]; done
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/themes/gtk3" ]
  grep -qxF "mirroros-gtk3-runtime"$'\t'"capabilities/visual/gtk3"$'\t\t\t'"manifest-sha256:$(sha256sum < "$dest/.mirroros-manifest" | cut -d' ' -f1)" \
    "$CFG_TEST_DIR/first/sources.tsv"
  grep -qxF $'osaka-jade-gtk3\thttps://github.com/abhinav20sep/osaka-jade-theme\t\t2ac2934f2ebf62ad1088bc5ea434c4670b8cd2dc\t' \
    "$CFG_TEST_DIR/first/sources.tsv"
  grep -qxF $'strata-gtk3-font\thttps://github.com/lgse/strata\tv1.2.1\t491e6ba9735e821f9f49910ffd2582076196865c\t' \
    "$CFG_TEST_DIR/first/sources.tsv"
  [ ! -e "$CFG_TEST_HOME/.config/gtk-3.0" ]
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/etc/dconf" ]
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/themes/MirrorOS" ]
  [ ! -e "$dest/entries" ]
  local entry="$MIRROROS_CONFIGURE_ROOT/usr/share/themes/MirrorOS-default/gtk-3.0"
  bash "$CFG_SOURCE_ROOT/capabilities/visual/gtk3/install-runtime" check \
    "$CFG_SOURCE_ROOT/capabilities/visual/gtk3/entries/default" "$entry" \
    "$(stat -c %u "$MIRROROS_CONFIGURE_ROOT")" "$(stat -c %g "$MIRROROS_CONFIGURE_ROOT")"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk3/entries/default/gtk.css" "$entry/gtk.css"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk3/entries/default/gtk-dark.css" "$entry/gtk-dark.css"
  grep -qxF "mirroros-gtk3-entry-default"$'\t'"capabilities/visual/gtk3/entries/default"$'\t\t\t'"manifest-sha256:$(sha256sum < "$entry/.mirroros-manifest" | cut -d' ' -f1)" \
    "$CFG_TEST_DIR/first/sources.tsv"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/gtk3: unchanged'* ]]
}

@test "target GTK3 configure publishes only below the target root and reruns unchanged" {
  cfg_test_target_context
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  local dest="$CFG_TEST_TARGET_ROOT/usr/share/mirroros/gtk3"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk3/base.css" "$dest/base.css"
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/theme/default/gtk-3.0.css" \
    "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/themes/default/gtk-3.0.css"
  [ ! -e "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/themes/gtk3" ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/etc/dconf" ]
  [ ! -e "$CFG_TEST_TARGET_ROOT/usr/share/themes/MirrorOS" ]
  cmp "$CFG_SOURCE_ROOT/capabilities/visual/gtk3/entries/default/gtk.css" \
    "$CFG_TEST_TARGET_ROOT/usr/share/themes/MirrorOS-default/gtk-3.0/gtk.css"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/gtk3: unchanged'* ]]
}

@test "GTK3 configure preserves locally modified styles and widget assets" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk3"
  printf '\n/* local change */\n' >> "$dest/base.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -q 'local change' "$dest/base.css"
  cp "$CFG_SOURCE_ROOT/capabilities/visual/gtk3/base.css" "$dest/base.css"
  printf '\n<!-- local asset -->\n' >> "$dest/assets/check-symbolic.svg"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -q 'local asset' "$dest/assets/check-symbolic.svg"
}

@test "GTK3 configure repairs an absent delivery but preserves unknown directories" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk3"
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

@test "GTK3 configure preserves incomplete linked and unsafe runtime deliveries" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local dest="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk3"
  rm "$dest/base.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ ! -e "$dest/base.css" ]
  ln -s typography.css "$dest/base.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ -L "$dest/base.css" ]
  rm "$dest/base.css"
  cp "$CFG_SOURCE_ROOT/capabilities/visual/gtk3/base.css" "$dest/base.css"
  chmod 0666 "$dest/base.css"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ "$(stat -c %a "$dest/base.css")" = 666 ]
}

@test "GTK3 configure refuses a linked runtime without writing through it" {
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros" "$CFG_TEST_DIR/other"
  ln -s "$CFG_TEST_DIR/other" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk3"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ -L "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk3" ]
  [ ! -e "$CFG_TEST_DIR/other/base.css" ]
}

@test "GTK3 standalone publication refuses an unsafe shared parent" {
  printf 'CFG_STEPS=(visual/gtk3)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros"
  chmod 0777 "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/gtk3" ]
}

@test "GTK3 and GTK4 coexist without overwriting user settings icons or portal selection" {
  printf 'CFG_STEPS=(visual/theme visual/gtk4 visual/gtk3)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  mkdir -p "$CFG_TEST_HOME/.config/gtk-3.0" "$CFG_TEST_HOME/.config/gtk-4.0" \
    "$MIRROROS_CONFIGURE_ROOT/etc/xdg/xdg-desktop-portal" "$MIRROROS_CONFIGURE_ROOT/usr/share/icons/Adwaita"
  printf 'personal settings\n' > "$CFG_TEST_HOME/.config/gtk-3.0/settings.ini"
  printf 'personal CSS\n' > "$CFG_TEST_HOME/.config/gtk-4.0/gtk.css"
  printf 'existing routing\n' > "$MIRROROS_CONFIGURE_ROOT/etc/xdg/xdg-desktop-portal/portals.conf"
  printf 'packaged icon index\n' > "$MIRROROS_CONFIGURE_ROOT/usr/share/icons/Adwaita/index.theme"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  for toolkit in gtk3 gtk4; do
    [ -f "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/$toolkit/base.css" ]
  done
  [ "$(find "$MIRROROS_CONFIGURE_ROOT/usr/share/themes/MirrorOS-default" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)" = \
    $'gtk-3.0\ngtk-4.0' ]
  grep -qx 'personal settings' "$CFG_TEST_HOME/.config/gtk-3.0/settings.ini"
  grep -qx 'personal CSS' "$CFG_TEST_HOME/.config/gtk-4.0/gtk.css"
  grep -qx 'existing routing' "$MIRROROS_CONFIGURE_ROOT/etc/xdg/xdg-desktop-portal/portals.conf"
  grep -qx 'packaged icon index' "$MIRROROS_CONFIGURE_ROOT/usr/share/icons/Adwaita/index.theme"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c ': unchanged$')" -eq 3 ]
}
