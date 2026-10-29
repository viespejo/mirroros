#!/usr/bin/env bats
# Terminal delivery through configure with temporary roots and test doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/terminal)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  mkdir -p "$CFG_TEST_HOME/.local/share/applications"
  touch "$CFG_TEST_HOME/.local/share/applications/foot.desktop"
}
teardown() { cfg_test_teardown; }

@test "configure publishes a standalone recovery file and preserves personal Foot settings" {
  mkdir -p "$CFG_TEST_HOME/.config/foot"
  printf '[main]\nfont=monospace:size=9\npad=14x14 center\n' > "$CFG_TEST_HOME/.config/foot/foot.ini"
  cp "$CFG_TEST_HOME/.config/foot/foot.ini" "$CFG_TEST_DIR/personal"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  local recovery="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/foot/recovery.ini"
  cmp "$CFG_TEST_DIR/code/capabilities/desktop/terminal/foot.ini" "$recovery"
  cmp "$CFG_TEST_DIR/code/capabilities/desktop/terminal/defaults.ini" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/foot/defaults.ini"
  cmp "$CFG_TEST_DIR/personal" "$CFG_TEST_HOME/.config/foot/foot.ini"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/terminal: unchanged'* ]]
  rm "$recovery"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  cmp "$CFG_TEST_DIR/code/capabilities/desktop/terminal/foot.ini" "$recovery"
  cmp "$CFG_TEST_DIR/personal" "$CFG_TEST_HOME/.config/foot/foot.ini"
}

@test "target configure publishes the recovery file below the target root" {
  cfg_test_target_context
  mkdir -p "$CFG_TEST_HOME/.local/share/applications"
  touch "$CFG_TEST_HOME/.local/share/applications/foot.desktop"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; return 1; }
  cmp "$CFG_TEST_DIR/code/capabilities/desktop/terminal/foot.ini" \
    "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/foot/recovery.ini"
  cmp "$CFG_TEST_DIR/code/capabilities/desktop/terminal/defaults.ini" \
    "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/foot/defaults.ini"
}

@test "configure rejects unsafe recovery parent directories" {
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros" "$CFG_TEST_DIR/other"
  ln -s "$CFG_TEST_DIR/other" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/foot"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ -L "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/foot" ]
  [ ! -e "$CFG_TEST_DIR/other/recovery.ini" ]
  rm "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/foot"
  mkdir "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/foot"
  chmod 0777 "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/foot"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/foot/recovery.ini" ]
}

@test "configure leaves edited defaults untouched" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local defaults="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/foot/defaults.ini"
  printf '# local edit\n' >> "$defaults"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -qF '# local edit' "$defaults"
}

@test "configure leaves edited and linked recovery files untouched" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  local recovery="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/foot/recovery.ini"
  printf '# local edit\n' >> "$recovery"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -qF '# local edit' "$recovery"
  rm "$recovery"
  ln -s "$CFG_TEST_DIR/missing" "$recovery"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ -L "$recovery" ]
}
