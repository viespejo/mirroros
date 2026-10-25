#!/usr/bin/env bats
# desktop/lock through the configure entry point, in both contexts, with test doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/lock)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  LOCK_CODE="$CFG_TEST_DIR/code/capabilities/desktop/lock"
  lock_packaged_unit "$MIRROROS_CONFIGURE_ROOT"
}
teardown() { cfg_test_teardown; }

# The packaged unit is supplied by hypridle; the pacman double installs no files.
lock_packaged_unit() {
  mkdir -p "$1/usr/lib/systemd/user"
  printf '[Unit]\nDescription=packaged hypridle\n' > "$1/usr/lib/systemd/user/hypridle.service"
}

@test "running configure delivers lock configuration and enables hypridle for the user without starting it" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/lock: changed'* ]]
  [ -e "$CFG_TEST_INSTALLED/hyprlock" ]
  [ -e "$CFG_TEST_INSTALLED/hypridle" ]
  cmp "$LOCK_CODE/hypridle.conf" "$CFG_TEST_HOME/.config/hypr/hypridle.conf"
  cmp "$LOCK_CODE/hyprlock.conf" "$CFG_TEST_HOME/.config/hypr/hyprlock.conf"
  cmp "$LOCK_CODE/systemd/10-mirroros.conf" "$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/hypridle.service.d/10-mirroros.conf"
  [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/hypridle.service")" = \
    /usr/lib/systemd/user/hypridle.service ]
  run grep -qE '^(systemctl|sudo|qs|hyprctl|hyprlock|hypridle|loginctl) ' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/lock: unchanged'* ]]
  cfg_test_no_install
}

@test "the lock configuration keeps the approved policy and never depends on the shell to lock" {
  local idle="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/lock/hypridle.conf"
  local lock="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/lock/hyprlock.conf"
  grep -qxF '    lock_cmd = pidof hyprlock || { hyprctl switchxkblayout all 0; hyprlock; }' "$idle"
  grep -qxF '    before_sleep_cmd = loginctl lock-session' "$idle"
  grep -qxF '    timeout = 300' "$idle"
  grep -qxF '    on-timeout = loginctl lock-session' "$idle"
  grep -qE '^    on_lock_cmd = touch "\$\{XDG_RUNTIME_DIR:\?\}/mirroros-shell-locked"; qs ipc .* call notifications lockChanged$' "$idle"
  grep -qE '^    on_unlock_cmd = rm -f "\$\{XDG_RUNTIME_DIR:\?\}/mirroros-shell-locked"; qs ipc .* call notifications lockChanged$' "$idle"
  [ "$(grep -c '^listener {' "$idle")" -eq 1 ]
  run grep -qiE 'dpms|suspend|systemctl|brightness' <<< "$(grep -viE '^[[:space:]]*#' "$idle")"
  [ "$status" -eq 1 ]
  run grep -q 'qs ' <<< "$(grep -E '^[[:space:]]*lock_cmd' "$idle")"
  [ "$status" -eq 1 ]
  run grep -qiE 'screenshot|path *= *screenshot|notification' <<< "$(grep -viE '^[[:space:]]*#' "$lock")"
  [ "$status" -eq 1 ]
  # shellcheck disable=SC2016 # Match hyprlock's literal layout variable, not a test-shell variable.
  grep -qF 'text = $LAYOUT' "$lock"
}

@test "the drop-in only adds ignorable marker cleanup and a shell reread before the packaged command" {
  local dropin="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/lock/systemd/10-mirroros.conf"
  [ "$(grep -vE '^(#|$)' "$dropin")" = $'[Service]\nExecStartPre=-/usr/bin/rm -f %t/mirroros-shell-locked\nExecStartPre=-/usr/bin/qs ipc -p /usr/share/mirroros/shell call notifications lockChanged' ]
  command -v systemd-analyze > /dev/null || skip 'systemd-analyze is not installed'
  mkdir -p "$CFG_TEST_DIR/units/hypridle.service.d"
  printf '[Unit]\nPartOf=graphical-session.target\nAfter=graphical-session.target\n[Service]\nExecStart=/usr/bin/true\n' \
    > "$CFG_TEST_DIR/units/hypridle.service"
  sed 's#/usr/bin/qs #/usr/bin/true #' "$dropin" > "$CFG_TEST_DIR/units/hypridle.service.d/10-mirroros.conf"
  run systemd-analyze verify --user --man=no "$CFG_TEST_DIR/units/hypridle.service"
  [ "$status" -eq 0 ]
  [[ "$output" != *hypridle* ]]
}

@test "a missing packaged unit or a locally edited drop-in fails the step and user-owned files survive" {
  mkdir -p "$CFG_TEST_HOME/.config/hypr"
  printf 'general {\n}\n' > "$CFG_TEST_HOME/.config/hypr/hypridle.conf"
  rm "$MIRROROS_CONFIGURE_ROOT/usr/lib/systemd/user/hypridle.service"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/missing"
  [ "$status" -eq 4 ]
  grep -qF 'Postcondition failed: cfg_system_file_present /usr/lib/systemd/user/hypridle.service' "$CFG_TEST_DIR/missing/configure.log"
  lock_packaged_unit "$MIRROROS_CONFIGURE_ROOT"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/owned"
  [ "$status" -eq 0 ]
  grep -qF 'user-owned: .config/hypr/hypridle.conf' "$CFG_TEST_DIR/owned/configure.log"
  [ "$(< "$CFG_TEST_HOME/.config/hypr/hypridle.conf")" = $'general {\n}' ]
  printf '# managed by MirrorOS configure\n[Service]\n' > "$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/hypridle.service.d/10-mirroros.conf"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ "$(< "$MIRROROS_CONFIGURE_ROOT/etc/systemd/user/hypridle.service.d/10-mirroros.conf")" = $'# managed by MirrorOS configure\n[Service]' ]
}

@test "target configure enables hypridle as the user through the chroot without services" {
  cfg_test_target_context
  lock_packaged_unit "$CFG_TEST_TARGET_ROOT"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [ "$(readlink "$CFG_TEST_HOME/.config/systemd/user/graphical-session.target.wants/hypridle.service")" = \
    /usr/lib/systemd/user/hypridle.service ]
  cmp "$LOCK_CODE/hypridle.conf" "$CFG_TEST_HOME/.config/hypr/hypridle.conf"
  [ -f "$CFG_TEST_TARGET_ROOT/etc/systemd/user/hypridle.service.d/10-mirroros.conf" ]
  run grep -qE '^(systemctl |arch-chroot [^ ]+ systemctl )' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/lock: unchanged'* ]]
}
