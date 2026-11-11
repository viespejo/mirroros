#!/usr/bin/env bats
# desktop/reminders through the configure entry point, in both contexts, with test doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/reminders)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  REMINDERS_CODE="$CFG_TEST_DIR/code/capabilities/desktop/reminders"
}
teardown() { cfg_test_teardown; }

@test "running configure installs the reminder command, its licence and packages, then reruns unchanged" {
  local root="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/reminders"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/reminders: changed'* ]]
  [ -e "$CFG_TEST_INSTALLED/jq" ]
  [ -e "$CFG_TEST_INSTALLED/sound-theme-freedesktop" ]
  cmp "$REMINDERS_CODE/reminder" "$root/reminder"
  [ "$(stat -c %a "$root/reminder")" = 755 ]
  cmp "$REMINDERS_CODE/OMARCHY-LICENSE" "$root/licenses/omarchy-reminders"
  [ "$(stat -c %a "$root/licenses/omarchy-reminders")" = 644 ]
  run grep -qE '^(systemctl|systemd-run|sudo|qs|notify-send|pw-play) ' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
  [ ! -e "$CFG_TEST_HOME/.config/systemd" ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/reminders: unchanged'* ]]
  cfg_test_no_install
}

@test "a locally edited reminder command fails the step and is preserved" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  printf '\n# local change\n' >> "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/reminders/reminder"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [[ "$output" == *'step desktop/reminders:'* ]]
  grep -q '# local change' "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/reminders/reminder"
}

@test "target configure installs the command in the target root without services and reruns unchanged" {
  cfg_test_target_context
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  cmp "$REMINDERS_CODE/reminder" "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/reminders/reminder"
  [ -f "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/reminders/licenses/omarchy-reminders" ]
  run grep -qE '^(systemctl |arch-chroot [^ ]+ systemctl )' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/reminders: unchanged'* ]]
}
