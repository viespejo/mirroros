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
  cmp "$LOCK_CODE/lock-screen" "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/lock/lock-screen"
  [ "$(stat -c %a "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/lock/lock-screen")" = 755 ]
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
  grep -qxF '    lock_cmd = pidof hyprlock || /usr/share/mirroros/lock/lock-screen' "$idle"
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
}

@test "the lock shows only the field over the selected background with theme colors after literal fallbacks" {
  local lock="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/lock/hyprlock.conf"
  local theme="$BATS_TEST_DIRNAME/../../../../capabilities/visual/theme/default/hyprlock.conf"
  local source_line='source = ~/.local/state/mirroros/current/theme/hyprlock.conf'
  # ADR 0021: no clock or layout labels, one field, and the PAM message for five seconds.
  run grep -qE '^[[:space:]]*label[[:space:]]*\{' "$lock"
  [ "$status" -eq 1 ]
  [ "$(grep -c '^input-field {' "$lock")" -eq 1 ]
  grep -qxF '    path = ~/.local/state/mirroros/current/background' "$lock"
  grep -qxF '    color = $background' "$lock"
  grep -qxF '    fail_timeout = 5000' "$lock"
  grep -qxF '    fail_text = <i>$PAMFAIL</i>' "$lock"
  grep -qxF '    size = 31.5%, 9.5%' "$lock"
  # The single source line follows every fallback variable and precedes every section.
  [ "$(grep -c '^source' "$lock")" -eq 1 ]
  local source_at last_variable first_section
  source_at="$(grep -nxF "$source_line" "$lock" | cut -d: -f1)"
  last_variable="$(grep -n '^\$' "$lock" | tail -1 | cut -d: -f1)"
  first_section="$(grep -n '{$' "$lock" | head -1 | cut -d: -f1)"
  [ -n "$source_at" ] && [ "$last_variable" -lt "$source_at" ] && [ "$source_at" -lt "$first_section" ]
  # The theme file only defines variables, exactly the color fallbacks of the lock.
  [ -z "$(grep -vE '^(#.*|\$[a-z_]+ = rgba?\([0-9., ]+\))$' "$theme")" ]
  [ "$(grep -o '^\$[a-z_]*' "$theme" | sort)" = "$(grep -o '^\$[a-z_]*' "$lock" | grep -vx '\$font' | sort)" ]
}

@test "configure replaces the previously shipped lock and preserves personal or linked lock files" {
  mkdir -p "$CFG_TEST_HOME/.config/hypr"
  cp "$BATS_TEST_DIRNAME/hyprlock-legacy.conf" "$CFG_TEST_HOME/.config/hypr/hyprlock.conf"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  cmp "$LOCK_CODE/hyprlock.conf" "$CFG_TEST_HOME/.config/hypr/hyprlock.conf"
  printf 'general {\n}\n' > "$CFG_TEST_HOME/.config/hypr/hyprlock.conf"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/owned"
  [ "$status" -eq 0 ]
  grep -qF 'user-owned: .config/hypr/hyprlock.conf' "$CFG_TEST_DIR/owned/configure.log"
  [ "$(< "$CFG_TEST_HOME/.config/hypr/hyprlock.conf")" = $'general {\n}' ]
  rm "$CFG_TEST_HOME/.config/hypr/hyprlock.conf"
  cp "$BATS_TEST_DIRNAME/hyprlock-legacy.conf" "$CFG_TEST_DIR/personal-lock"
  ln -s "$CFG_TEST_DIR/personal-lock" "$CFG_TEST_HOME/.config/hypr/hyprlock.conf"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ -L "$CFG_TEST_HOME/.config/hypr/hyprlock.conf" ]
  cmp "$BATS_TEST_DIRNAME/hyprlock-legacy.conf" "$CFG_TEST_DIR/personal-lock"
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
