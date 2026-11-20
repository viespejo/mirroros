#!/usr/bin/bash
# Configure contract fixtures: use the real entry point with a disposable root and no Chrome network or build.
chrome_configure_fixture() {
  local fixtures
  fixtures=$(dirname -- "${BASH_SOURCE[0]}")
  cp "$CFG_TEST_DIR/bin/pacman" "$CFG_TEST_DIR/bin/pacman-original"
  install -m 0755 "$fixtures/configure-pacman" "$CFG_TEST_DIR/bin/pacman"
  cp "$fixtures/configure-build" "$CFG_TEST_DIR/code/capabilities/desktop/browser/build-chrome"
}
