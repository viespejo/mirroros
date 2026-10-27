#!/usr/bin/env bats
# desktop/login through the configure entry point, in both contexts, with test doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/login)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  LOGIN_SOURCE="$CFG_SOURCE_ROOT/capabilities/desktop/login"
  login_running_systemctl
  login_branding "$MIRROROS_CONFIGURE_ROOT"
}
teardown() { cfg_test_teardown; }

# Running context has no chroot; this double mirrors the arch-chroot double's unit state below the test root.
login_running_systemctl() {
  cat > "$CFG_TEST_DIR/bin/systemctl" <<'SYSTEMCTL'
#!/usr/bin/bash
set -Eeuo pipefail
printf 'systemctl %s\n' "$*" >> "$CFG_TEST_CALLS"
root="$MIRROROS_CONFIGURE_ROOT"
case "$1" in
  is-enabled) [[ -e "$root/etc/systemd/system/.sddm-enabled" ]] ;;
  enable)
    mkdir -p "$root/etc/systemd/system"
    : > "$root/etc/systemd/system/.sddm-enabled"
    ln -sf /usr/lib/systemd/system/sddm.service "$root/etc/systemd/system/display-manager.service" ;;
  get-default) cat "$root/etc/systemd/system/.default-target" 2> /dev/null || printf 'multi-user.target\n' ;;
  set-default) printf '%s\n' "$2" > "$root/etc/systemd/system/.default-target" ;;
  list-unit-files) if [[ -e "$root/etc/systemd/system/.sddm-enabled" ]]; then printf 'sddm.service enabled\n'; fi ;;
  cat) printf '[Install]\nAlias=display-manager.service\n' ;;
  *) printf 'Unexpected systemctl command: %s\n' "$*" >&2; exit 97 ;;
esac
SYSTEMCTL
  chmod 0755 "$CFG_TEST_DIR/bin/systemctl"
}

# The branding step's delivery is a prerequisite of the login postconditions.
login_branding() {
  mkdir -p "$1/usr/share/mirroros/branding"
  : > "$1/usr/share/mirroros/branding/mirroros-symbol.png"
}

login_theme_check() {
  bash "$LOGIN_SOURCE/install-theme" check "$LOGIN_SOURCE/sddm/mirroros" "$1/usr/share/sddm/themes/mirroros" "$2"
}

login_legacy() {
  mkdir -p "$1/etc/sddm.conf.d"
  printf '# managed by MirrorOS configure\n[Theme]\nCurrent=\n\n[Autologin]\nUser=\nSession=\nRelogin=false\n' \
    > "$1/etc/sddm.conf.d/10-mirroros-login.conf"
}

@test "running configure publishes the theme selects it and reruns unchanged without starting SDDM" {
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/login: changed'* ]]
  login_theme_check "$MIRROROS_CONFIGURE_ROOT" "English (US)"
  theme="$MIRROROS_CONFIGURE_ROOT/usr/share/sddm/themes/mirroros"
  for file in Main.qml LoginModel.js metadata.desktop theme.conf; do
    cmp "$LOGIN_SOURCE/sddm/mirroros/$file" "$theme/$file"
    [ "$(stat -c %a "$theme/$file")" = 644 ]
  done
  grep -qxF 'keyboardLayout="English (US)"' "$theme/theme.conf.user"
  cmp "$LOGIN_SOURCE/sddm/10-mirroros-login.conf" "$MIRROROS_CONFIGURE_ROOT/etc/sddm.conf.d/10-mirroros-login.conf"
  grep -qxF 'Current=mirroros' "$MIRROROS_CONFIGURE_ROOT/etc/sddm.conf.d/10-mirroros-login.conf"
  [ -f "$MIRROROS_CONFIGURE_ROOT/var/lib/mirroros/configure/delivered/etc/sddm.conf.d/10-mirroros-login.conf.sha256" ]
  grep -qE $'^mirroros-sddm-theme\tcapabilities/desktop/login\t\t\tmanifest-sha256:[0-9a-f]{64}$' "$CFG_TEST_DIR/first/sources.tsv"
  grep -qxF 'systemctl enable sddm.service' "$CFG_TEST_CALLS"
  run grep -qE '^systemctl (start|restart|reload|try-restart)' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/login: unchanged'* ]]
  cfg_test_no_install
}

@test "the theme shows the layout resolved by configure and republishes only when it changes" {
  printf 'KEYMAP=es\n' > "$MIRROROS_CONFIGURE_ROOT/etc/vconsole.conf"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  login_theme_check "$MIRROROS_CONFIGURE_ROOT" Spanish
  grep -qxF 'keyboardLayout="Spanish"' "$MIRROROS_CONFIGURE_ROOT/usr/share/sddm/themes/mirroros/theme.conf.user"
  printf 'XKBLAYOUT=us\nKEYMAP=es\n' > "$MIRROROS_CONFIGURE_ROOT/etc/vconsole.conf"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/login: changed'* ]]
  grep -qxF 'keyboardLayout="English (US)"' "$MIRROROS_CONFIGURE_ROOT/usr/share/sddm/themes/mirroros/theme.conf.user"
  run "$CFG_TEST_ENTRY"
  [[ "$output" == *'desktop/login: unchanged'* ]]
}

@test "a layout description outside the label character set falls back to the layout code" {
  printf '! layout\n  us English (US)\n  zz Bad"; label\n! variant\n' > "$MIRROROS_CONFIGURE_ROOT/usr/share/X11/xkb/rules/base.lst"
  printf 'XKBLAYOUT=zz\n' > "$MIRROROS_CONFIGURE_ROOT/etc/vconsole.conf"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  login_theme_check "$MIRROROS_CONFIGURE_ROOT" zz
  grep -qxF 'keyboardLayout="zz"' "$MIRROROS_CONFIGURE_ROOT/usr/share/sddm/themes/mirroros/theme.conf.user"
}

@test "the exact shipped legacy login configuration migrates to the tracked theme selection" {
  login_legacy "$MIRROROS_CONFIGURE_ROOT"
  [ "$(sha256sum < "$MIRROROS_CONFIGURE_ROOT/etc/sddm.conf.d/10-mirroros-login.conf" | cut -d' ' -f1)" = \
    e8a1257fbfde6463e2cfaf1ee54b8211599f0a5f43ac30faa4d8376d920a930e ]
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  cmp "$LOGIN_SOURCE/sddm/10-mirroros-login.conf" "$MIRROROS_CONFIGURE_ROOT/etc/sddm.conf.d/10-mirroros-login.conf"
  run "$CFG_TEST_ENTRY"
  [[ "$output" == *'desktop/login: unchanged'* ]]
}

@test "edited or unmanaged login configurations are preserved and reported as conflicts" {
  login_legacy "$MIRROROS_CONFIGURE_ROOT"
  conf="$MIRROROS_CONFIGURE_ROOT/etc/sddm.conf.d/10-mirroros-login.conf"
  sed -i 's/^Relogin=false$/Relogin=true/' "$conf"
  cp "$conf" "$CFG_TEST_DIR/edited.conf"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/edited"
  [ "$status" -eq 4 ]
  grep -qF 'Conflict: /etc/sddm.conf.d/10-mirroros-login.conf differs from its last MirrorOS delivery' "$CFG_TEST_DIR/edited/configure.log"
  cmp "$CFG_TEST_DIR/edited.conf" "$conf"
  printf '[Theme]\nCurrent=breeze\n' > "$conf"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ "$(< "$conf")" = $'[Theme]\nCurrent=breeze' ]
  run grep -q '^systemctl enable' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
}

@test "an unknown linked or edited theme directory is preserved and never selected" {
  theme="$MIRROROS_CONFIGURE_ROOT/usr/share/sddm/themes/mirroros"
  mkdir -p "$theme"
  printf 'mine\n' > "$theme/Main.qml"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/unknown"
  [ "$status" -eq 4 ]
  grep -qF 'is not an SDDM theme delivered by MirrorOS' "$CFG_TEST_DIR/unknown/configure.log"
  [ "$(< "$theme/Main.qml")" = mine ]
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/etc/sddm.conf.d/10-mirroros-login.conf" ]
  rm -rf "$theme"
  mkdir -p "$CFG_TEST_DIR/elsewhere"
  ln -s "$CFG_TEST_DIR/elsewhere" "$theme"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ -z "$(ls -A "$CFG_TEST_DIR/elsewhere")" ]
  rm "$theme"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  printf '// local\n' >> "$theme/Main.qml"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/edited"
  [ "$status" -eq 4 ]
  grep -qF 'differs from its last MirrorOS delivery (local edit)' "$CFG_TEST_DIR/edited/configure.log"
  [ "$(tail -n 1 "$theme/Main.qml")" = '// local' ]
}

@test "leftover theme staging from an interrupted publication is removed by the next one" {
  mkdir -p "$MIRROROS_CONFIGURE_ROOT/usr/share/sddm/themes/.mirroros-theme.mirroros-staging.old"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ -z "$(find "$MIRROROS_CONFIGURE_ROOT/usr/share/sddm/themes" -name '.mirroros-theme.mirroros-staging.*')" ]
}

@test "a missing branding delivery fails the login postconditions" {
  rm "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/branding/mirroros-symbol.png"
  : > "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/branding/mirroros-wordmark.png"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/missing"
  [ "$status" -eq 4 ]
  grep -qF 'Postcondition failed: cfg_system_file_present /usr/share/mirroros/branding/mirroros-symbol.png' \
    "$CFG_TEST_DIR/missing/configure.log"
}

@test "target configure publishes the theme migrates legacy configuration and reruns unchanged" {
  cfg_test_target_context
  login_branding "$CFG_TEST_TARGET_ROOT"
  login_legacy "$CFG_TEST_TARGET_ROOT"
  printf 'KEYMAP=es\n' > "$CFG_TEST_TARGET_ROOT/etc/vconsole.conf"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  login_theme_check "$CFG_TEST_TARGET_ROOT" Spanish
  cmp "$LOGIN_SOURCE/sddm/10-mirroros-login.conf" "$CFG_TEST_TARGET_ROOT/etc/sddm.conf.d/10-mirroros-login.conf"
  grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT systemctl enable sddm.service" "$CFG_TEST_CALLS"
  run grep -qE 'systemctl (start|restart|reload)' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
  run grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT install " "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/login: unchanged'* ]]
  cfg_test_no_install
}
