#!/usr/bin/env bats
# Neutral screenshot delivery through configure; backend readiness is tested by its provider.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/screenshot)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
}
teardown() { cfg_test_teardown; }

screenshot_delivery() {
  local root="$1" action path
  for action in screenshot color ocr qr; do
    path="/usr/share/mirroros/screenshot/$action"
    cmp "$CFG_SOURCE_ROOT/capabilities/desktop/screenshot/$action" "$root$path"
    [ "$(stat -c %a "$root$path")" = 755 ]
    [ -f "$root/var/lib/mirroros/configure/delivered$path.sha256" ]
    [ ! -e "$root/usr/share/mirroros/compositor/$action-backend" ]
  done
  [ -e "$CFG_TEST_INSTALLED/bash" ]
  [ -e "$CFG_TEST_INSTALLED/systemd" ]
  [ -e "$CFG_TEST_INSTALLED/libnotify" ]
  ! grep -qE '^(systemctl|notify-send|systemd-cat|screenshot|color|ocr|qr) ' "$CFG_TEST_CALLS"
}

@test "running configure delivers screenshot without a backend and reruns unchanged" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/screenshot: changed'* ]]
  screenshot_delivery "$MIRROROS_CONFIGURE_ROOT"
  grep -qxF 'pacman -S --needed --noconfirm -- core/bash core/systemd extra/libnotify' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/screenshot: unchanged'* ]]
  cfg_test_no_install
  screenshot_delivery "$MIRROROS_CONFIGURE_ROOT"
}

@test "target configure delivers screenshot offline and reruns unchanged" {
  cfg_test_target_context
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  screenshot_delivery "$CFG_TEST_TARGET_ROOT"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/screenshot: unchanged'* ]]
  cfg_test_no_install
  screenshot_delivery "$CFG_TEST_TARGET_ROOT"
}

@test "locally edited screenshot command is preserved and configure fails" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  printf '\n# local edit\n' >> "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/screenshot/screenshot"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  grep -q '^# local edit$' "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/screenshot/screenshot"
}

@test "unknown user-owned screenshot command is preserved and configure fails" {
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/screenshot"
  printf 'personal command\n' > "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/screenshot/screenshot"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ "$(< "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/screenshot/screenshot")" = 'personal command' ]
}
