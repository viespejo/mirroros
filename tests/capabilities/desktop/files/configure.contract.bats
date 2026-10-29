#!/usr/bin/env bats
# Package-only file-manager delivery with disposable roots and package-manager doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/files)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}
teardown() { cfg_test_teardown; }

@test "running configure installs Nautilus once without writing personal settings" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ -e "$CFG_TEST_INSTALLED/nautilus" ]
  [[ "$output" == *'desktop/files: changed'* ]]
  [ ! -e "$CFG_TEST_HOME/.config/nautilus" ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/files: unchanged'* ]]
  cfg_test_no_install
}

@test "target configure installs Nautilus inside the target" {
  cfg_test_target_context
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [ -e "$CFG_TEST_INSTALLED/nautilus" ]
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/nautilus" "$CFG_TEST_CALLS"
}
