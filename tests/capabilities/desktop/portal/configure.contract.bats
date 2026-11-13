#!/usr/bin/env bats
# desktop/portal through the configure entry point, in both contexts, with disposable roots and test doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(desktop/portal)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  PORTAL_CODE="$CFG_TEST_DIR/code/capabilities/desktop/portal"
  portal_doubles
}
teardown() { cfg_test_teardown; }
refute() { if "$@"; then return 1; fi; }

# xdg-mime resolves the user file first, then the system file; `env -i` clears the environment, so the double
# carries this test's paths. The shared dconf double compiles and reads the disposable root.
portal_doubles() {
  cat > "$CFG_TEST_DIR/bin/xdg-mime" <<EOF
#!/usr/bin/bash
set -Eeuo pipefail
printf 'xdg-mime %s HOME=%s\n' "\$*" "\$HOME" >> "$CFG_TEST_CALLS"
[[ "\$*" == 'query default inode/directory' ]] || exit 97
for file in "\${XDG_CONFIG_HOME:-\$HOME/.config}/mimeapps.list" "$MIRROROS_CONFIGURE_ROOT/etc/xdg/mimeapps.list"; do
  if [[ -f "\$file" ]] && grep -q '^inode/directory=' "\$file"; then sed -n 's/^inode\/directory=//p' "\$file"; exit 0; fi
done
EOF
  chmod 0755 "$CFG_TEST_DIR/bin/xdg-mime"
}

# The packaged sddm PAM stack, as shipped by sddm 0.21.0-7.
portal_sddm_pam() {
  mkdir -p "$1/etc/pam.d"
  printf '%s\n' '#%PAM-1.0' '-auth   optional    pam_gnome_keyring.so' 'account include system-login' \
    '-password optional  pam_gnome_keyring.so use_authtok' 'session include system-login' \
    '-session optional   pam_gnome_keyring.so auto_start' > "$1/etc/pam.d/sddm"
}

portal_strata_entry() {
  mkdir -p "$1/usr/share/applications"
  printf '[Desktop Entry]\nName=Strata\nExec=strata %%U\n' > "$1/usr/share/applications/io.github.lgse.Strata.desktop"
}

@test "running configure delivers the portal stack and dark default, compiles dconf once and reruns unchanged" {
  local root="$MIRROROS_CONFIGURE_ROOT"
  portal_sddm_pam "$root"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/portal: changed'* ]]
  for package in xdg-desktop-portal xdg-desktop-portal-gtk gnome-keyring dconf; do [ -e "$CFG_TEST_INSTALLED/$package" ]; done
  cmp "$PORTAL_CODE/mimeapps.list" "$root/etc/xdg/mimeapps.list"
  cmp "$PORTAL_CODE/dconf-profile-user" "$root/etc/dconf/profile/user"
  cmp "$PORTAL_CODE/00-mirroros-appearance" "$root/etc/dconf/db/local.d/00-mirroros-appearance"
  cmp "$PORTAL_CODE/portal-check" "$root/usr/share/mirroros/portal/portal-check"
  [ "$(stat -c %a "$root/etc/xdg/mimeapps.list")" = 644 ]
  [ "$(stat -c %a "$root/etc/dconf/profile/user")" = 644 ]
  [ "$(stat -c %a "$root/usr/share/mirroros/portal/portal-check")" = 755 ]
  grep -qx "color-scheme='prefer-dark'" "$root/etc/dconf/db/local"
  [ "$(grep -c '^dconf update$' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -qF 'portal changes take effect at the next login' "$CFG_TEST_DIR/first/configure.log"
  grep -qF 'unavailable: inode/directory default check; io.github.lgse.Strata.desktop is not installed yet' \
    "$CFG_TEST_DIR/first/configure.log"
  refute grep -qE '^(systemctl|busctl|gsettings|xdg-mime) ' "$CFG_TEST_CALLS"
  [ ! -e "$CFG_TEST_HOME/.config/dconf" ]
  [ ! -e "$root/etc/xdg/xdg-desktop-portal/portals.conf" ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/second"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/portal: unchanged'* ]]
  grep -qF 'portal changes take effect at the next login' "$CFG_TEST_DIR/second/configure.log"
  refute grep -q '^dconf update' "$CFG_TEST_CALLS"
  cfg_test_no_install
}

@test "dconf update runs again only when a declared dconf file changes or the database is missing" {
  portal_sddm_pam "$MIRROROS_CONFIGURE_ROOT"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  printf '# managed by MirrorOS configure\n[org/gnome/desktop/interface]\ncolor-scheme='"'prefer-dark'"'\n\n' \
    > "$PORTAL_CODE/00-mirroros-appearance"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'desktop/portal: changed'* ]]
  [ "$(grep -c '^dconf update$' "$CFG_TEST_CALLS")" -eq 1 ]
  rm "$MIRROROS_CONFIGURE_ROOT/etc/dconf/db/local"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^dconf update$' "$CFG_TEST_CALLS")" -eq 1 ]
}

@test "the running inode/directory check uses the system association and ignores a user choice" {
  local root="$MIRROROS_CONFIGURE_ROOT"
  portal_sddm_pam "$root"
  portal_strata_entry "$root"
  mkdir -p "$CFG_TEST_HOME/.config"
  printf '[Default Applications]\ninode/directory=org.example.Files.desktop\n' > "$CFG_TEST_HOME/.config/mimeapps.list"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  grep -qx 'xdg-mime query default inode/directory HOME=/nonexistent' "$CFG_TEST_CALLS"
  refute grep -q 'runuser' "$CFG_TEST_CALLS"
  [ "$(< "$CFG_TEST_HOME/.config/mimeapps.list")" = $'[Default Applications]\ninode/directory=org.example.Files.desktop' ]
  printf '# managed by MirrorOS configure\n[Default Applications]\ninode/directory=org.example.Files.desktop\n' \
    > "$PORTAL_CODE/mimeapps.list"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/other"
  [ "$status" -eq 4 ]
  grep -qF 'Postcondition failed: directory_default' "$CFG_TEST_DIR/other/configure.log"
}

@test "the packaged SDDM keyring lines are read only, required once SDDM exists and never edited" {
  local root="$MIRROROS_CONFIGURE_ROOT"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/absent"
  [ "$status" -eq 0 ]
  grep -qF 'unavailable: SDDM PAM integration; desktop/login installs SDDM later in the step order' \
    "$CFG_TEST_DIR/absent/configure.log"
  [ ! -e "$root/etc/pam.d/sddm" ]
  portal_sddm_pam "$root"
  cp "$root/etc/pam.d/sddm" "$CFG_TEST_DIR/sddm.pam"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  cmp "$CFG_TEST_DIR/sddm.pam" "$root/etc/pam.d/sddm"
  grep -v 'pam_gnome_keyring.so auto_start' "$CFG_TEST_DIR/sddm.pam" > "$root/etc/pam.d/sddm"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/missing"
  [ "$status" -eq 4 ]
  grep -qF 'Postcondition failed: sddm_keyring' "$CFG_TEST_DIR/missing/configure.log"
  [ "$(grep -c pam_gnome_keyring "$root/etc/pam.d/sddm")" -eq 2 ]
}

@test "target configure installs the portal stack inside the target and compiles dconf through the chroot" {
  cfg_test_target_context
  portal_sddm_pam "$CFG_TEST_TARGET_ROOT"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  for package in xdg-desktop-portal xdg-desktop-portal-gtk gnome-keyring dconf; do
    grep -qF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/$package" "$CFG_TEST_CALLS" ||
      grep -qE "^arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -S .*extra/$package( |$)" "$CFG_TEST_CALLS"
  done
  cmp "$CFG_SOURCE_ROOT/capabilities/desktop/portal/mimeapps.list" "$CFG_TEST_TARGET_ROOT/etc/xdg/mimeapps.list"
  grep -qx "arch-chroot $CFG_TEST_TARGET_ROOT dconf update" "$CFG_TEST_CALLS"
  grep -qx "color-scheme='prefer-dark'" "$CFG_TEST_TARGET_ROOT/etc/dconf/db/local"
  [ -x "$CFG_TEST_TARGET_ROOT/usr/share/mirroros/portal/portal-check" ]
  refute grep -qE '(^| )(systemctl|busctl|xdg-mime|gsettings) ' "$CFG_TEST_CALLS"
}
