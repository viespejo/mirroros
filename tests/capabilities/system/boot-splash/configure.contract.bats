#!/usr/bin/env bats
# system/boot-splash through the configure entry point, in both contexts and all three storage options, with doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(visual/branding system/boot-splash)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  SPLASH_SOURCE="$CFG_SOURCE_ROOT/capabilities/system/boot-splash"
  ROOT="$MIRROROS_CONFIGURE_ROOT"
}
teardown() { cfg_test_teardown; }

refute() { if "$@"; then return 1; fi; }

splash_target() {
  cfg_test_target_context
  ROOT="$CFG_TEST_TARGET_ROOT"
}

splash_run() {
  if [[ -n "${CFG_TEST_TARGET_ROOT:-}" ]]; then
    "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice "$@"
  else
    "$CFG_TEST_ENTRY" "$@"
  fi
}

# Tool lookups (command -v) during validation are not invocations.
invocations() { grep -v 'command -v' "$CFG_TEST_CALLS" || true; }
regenerations() { invocations | grep -cE '(^| )(mkinitcpio -p linux|limine-update)$' || true; }
entry() { sed -n 's/^options //p' "$ROOT/boot/loader/entries/$1"; }
limine_default() { sed -n 's/^KERNEL_CMDLINE\[default\]="\(.*\)"$/\1/p' "$ROOT/etc/default/limine"; }
image_has_theme() { grep -qxF ./usr/share/plymouth/themes/mirroros/mirroros.script "$ROOT$1" && grep -qxF usr/share/mirroros/branding/mirroros-symbol.png "$ROOT$1"; }
state() { cat "$ROOT/var/lib/mirroros/configure/boot-splash.state"; }

# A second run with unchanged inputs regenerates and rewrites nothing.
splash_assert_unchanged_rerun() {
  local before
  before="$(find "$ROOT/boot" "$ROOT/etc" -type f -exec sha256sum {} + | sort)"
  : > "$CFG_TEST_CALLS"
  run splash_run --output "$CFG_TEST_DIR/rerun"
  [ "$status" -eq 0 ]
  [[ "$output" == *'system/boot-splash: unchanged'* ]]
  [ "$(regenerations)" -eq 0 ]
  cfg_test_no_install
  [ "$before" = "$(find "$ROOT/boot" "$ROOT/etc" -type f -exec sha256sum {} + | sort)" ]
  run grep -qE '(systemctl|reboot|plymouth-set-default-theme|bootctl)' <<< "$(invocations)"
  [ "$status" -eq 1 ]
}

@test "ext4-systemd-boot in running context adds the splash overlay and keeps the fallback entry without it" {
  cfg_test_boot_fixture ext4-systemd-boot
  run splash_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  [[ "$output" == *'== 2/2 system/boot-splash =='* ]]
  [[ "$output" == *'system/boot-splash: changed'* ]]
  [ -e "$CFG_TEST_INSTALLED/plymouth" ]
  [ "$(entry mirroros.conf)" = "$CFG_TEST_CMDLINE quiet splash" ]
  [ "$(entry mirroros-fallback.conf)" = "$CFG_TEST_CMDLINE" ]
  grep -qxF 'HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)' \
    "$ROOT/etc/mkinitcpio.conf.d/90-mirroros-plymouth.conf"
  cmp "$SPLASH_SOURCE/plymouth/plymouthd.conf" "$ROOT/etc/plymouth/plymouthd.conf"
  cmp "$SPLASH_SOURCE/plymouth/mirroros.plymouth" "$ROOT/usr/share/plymouth/themes/mirroros/mirroros.plymouth"
  cmp "$SPLASH_SOURCE/plymouth/mirroros.script" "$ROOT/usr/share/plymouth/themes/mirroros/mirroros.script"
  image_has_theme /boot/initramfs-linux.img
  image_has_theme /boot/initramfs-linux-fallback.img
  [ "$(regenerations)" -eq 1 ]
  grep -qxF 'mkinitcpio -p linux' "$CFG_TEST_CALLS"
  [[ "$(state)" =~ ^complete\ [0-9a-f]{64}$ ]]
  grep -qE $'^mirroros-boot-splash\tcapabilities/system/boot-splash\t\t\tscheme:systemd-boot inputs-sha256:[0-9a-f]{64}$' \
    "$CFG_TEST_DIR/first/sources.tsv"
  grep -qF 'plymouth' "$CFG_TEST_DIR/first/packages.tsv"
  splash_assert_unchanged_rerun
}

@test "btrfs-rescue in target context without hibernation keeps the subvolume and adds no resume parameter" {
  splash_target
  cfg_test_boot_fixture btrfs-rescue false
  run splash_run
  [ "$status" -eq 0 ]
  [ "$(entry mirroros.conf)" = "$CFG_TEST_CMDLINE quiet splash" ]
  [[ "$(entry mirroros.conf)" == *' rootflags=subvol=@ '* ]]
  [[ "$(entry mirroros.conf)" != *resume* ]]
  [ "$(entry mirroros-fallback.conf)" = "$CFG_TEST_CMDLINE" ]
  grep -qxF "arch-chroot $CFG_TEST_TARGET_ROOT env SNAP_PAC_SKIP=y pacman -S --needed --noconfirm -- extra/plymouth" "$CFG_TEST_CALLS"
  grep -qxF "arch-chroot $CFG_TEST_TARGET_ROOT mkinitcpio -p linux" "$CFG_TEST_CALLS"
  grep -qxF "arch-chroot $CFG_TEST_TARGET_ROOT lsinitcpio -l -- /boot/initramfs-linux.img" "$CFG_TEST_CALLS"
  image_has_theme /boot/initramfs-linux.img
  splash_assert_unchanged_rerun
}

@test "btrfs-limine in target context updates the authoritative defaults and keeps snapshot entries" {
  local snapshots
  splash_target
  cfg_test_boot_fixture btrfs-limine
  snapshots="$(sed -n '/^\/\/Snapshots$/,$p' "$ROOT/boot/limine.conf")"
  run splash_run
  [ "$status" -eq 0 ]
  [ "$(limine_default)" = "$CFG_TEST_CMDLINE quiet splash" ]
  grep -qxF 'ESP_PATH="/boot"' "$ROOT/etc/default/limine"
  grep -qxF 'SKIP_UEFI=yes' "$ROOT/etc/default/limine"
  grep -qxF "    cmdline: $CFG_TEST_CMDLINE quiet splash" "$ROOT/boot/limine.conf"
  [ "$snapshots" = "$(sed -n '/^\/\/Snapshots$/,$p' "$ROOT/boot/limine.conf")" ]
  grep -qxF 'HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems sd-btrfs-overlayfs fsck)' \
    "$ROOT/etc/mkinitcpio.conf.d/90-mirroros-plymouth.conf"
  grep -qxF 'HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems sd-btrfs-overlayfs fsck)' \
    "$ROOT/etc/mkinitcpio.conf.d/10-mirroros-limine.conf"
  grep -qxF "arch-chroot $CFG_TEST_TARGET_ROOT limine-update" "$CFG_TEST_CALLS"
  run grep -qF 'mkinitcpio -p' "$CFG_TEST_CALLS"
  [ "$status" -eq 1 ]
  image_has_theme /boot/4d1f6c2a9e8b4c7d8e9f0a1b2c3d4e5f/linux/initramfs-linux
  [[ "$(state)" =~ ^complete\  ]]
  splash_assert_unchanged_rerun
}

@test "btrfs-limine in running context without hibernation converges and reruns unchanged" {
  cfg_test_boot_fixture btrfs-limine false
  run splash_run
  [ "$status" -eq 0 ]
  [ "$(limine_default)" = "$CFG_TEST_CMDLINE quiet splash" ]
  [[ "$(limine_default)" != *resume* ]]
  grep -qxF 'limine-update' "$CFG_TEST_CALLS"
  splash_assert_unchanged_rerun
}

@test "present overlay tokens keep their position and are not duplicated" {
  cfg_test_boot_fixture ext4-systemd-boot
  sed -i 's/^options \(.*\)$/options quiet \1/' "$ROOT/boot/loader/entries/mirroros.conf"
  run splash_run
  [ "$status" -eq 0 ]
  [ "$(entry mirroros.conf)" = "quiet $CFG_TEST_CMDLINE splash" ]
}

@test "repeated overlay tokens are a conflict that writes nothing" {
  cfg_test_boot_fixture ext4-systemd-boot
  sed -i 's/^options \(.*\)$/options \1 splash splash/' "$ROOT/boot/loader/entries/mirroros.conf"
  cp "$ROOT/boot/loader/entries/mirroros.conf" "$CFG_TEST_DIR/entry"
  run splash_run --output "$CFG_TEST_DIR/duplicate"
  [ "$status" -eq 4 ]
  grep -qF 'repeats quiet or splash' "$CFG_TEST_DIR/duplicate/configure.log"
  cmp "$CFG_TEST_DIR/entry" "$ROOT/boot/loader/entries/mirroros.conf"
  [ ! -e "$ROOT/etc/mkinitcpio.conf.d/90-mirroros-plymouth.conf" ]
  [ ! -e "$ROOT/usr/share/plymouth/themes/mirroros" ]
  [ "$(regenerations)" -eq 0 ]
}

@test "the plymouthd.conf shipped by the package is migrated" {
  cfg_test_boot_fixture ext4-systemd-boot
  mkdir -p "$ROOT/etc/plymouth"
  printf '# Administrator customizations go in this file\n#[Daemon]\n#Theme=fade-in\n' > "$ROOT/etc/plymouth/plymouthd.conf"
  run splash_run
  [ "$status" -eq 0 ]
  cmp "$SPLASH_SOURCE/plymouth/plymouthd.conf" "$ROOT/etc/plymouth/plymouthd.conf"
}

# shellcheck disable=SC2030 # Counterpart of the SC2031 note on splash_conflict: each test owns status and output.
@test "a local Plymouth theme selection is preserved as a conflict" {
  cfg_test_boot_fixture ext4-systemd-boot
  mkdir -p "$ROOT/etc/plymouth"
  printf '[Daemon]\nTheme=spinner\n' > "$ROOT/etc/plymouth/plymouthd.conf"
  run splash_run --output "$CFG_TEST_DIR/local"
  [ "$status" -eq 4 ]
  grep -qF 'plymouthd.conf differs from its last MirrorOS delivery' "$CFG_TEST_DIR/local/configure.log"
  [ "$(< "$ROOT/etc/plymouth/plymouthd.conf")" = $'[Daemon]\nTheme=spinner' ]
  [ "$(regenerations)" -eq 0 ]
}

# Each case changes one recognized structure; the step fails with 4 before writing any boot input.
# shellcheck disable=SC2031 # run assigns status and output inside this function, in the calling test's shell.
splash_conflict() {
  local option="$1" change="$2" message="$3"
  cfg_test_teardown
  unset CFG_TEST_ESP_MOUNTED CFG_TEST_MISSING_TOOLS CFG_TEST_TARGET_ROOT
  cfg_test_setup
  ROOT="$MIRROROS_CONFIGURE_ROOT"
  printf 'CFG_STEPS=(visual/branding system/boot-splash)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  cfg_test_boot_fixture "$option"
  eval "$change"
  local before
  before="$(find "$ROOT/boot" "$ROOT/etc" \( -type f -o -type l \) -exec sha256sum {} + 2> /dev/null | sort)"
  run splash_run --output "$CFG_TEST_DIR/conflict"
  [ "$status" -eq 4 ] || { printf 'status %s for: %s\n%s\n' "$status" "$change" "$output" >&2; return 1; }
  grep -qF -- "$message" "$CFG_TEST_DIR/conflict/configure.log" ||
    { printf 'missing message %s for: %s\n' "$message" "$change" >&2; cat "$CFG_TEST_DIR/conflict/configure.log" >&2; return 1; }
  [ "$before" = "$(find "$ROOT/boot" "$ROOT/etc" \( -type f -o -type l \) -exec sha256sum {} + 2> /dev/null | sort)" ]
  [ ! -e "$ROOT/etc/mkinitcpio.conf.d/90-mirroros-plymouth.conf" ]
  [ "$(regenerations)" -eq 0 ]
}

# shellcheck disable=SC2016 # Each change is evaluated by splash_conflict against its fresh fixture ROOT.
@test "ambiguous, unsupported or locally changed boot configurations are preserved and reported" {
  splash_conflict ext4-systemd-boot 'mkdir -p "$ROOT/etc/default"; printf x > "$ROOT/etc/default/limine"' 'the boot loader is ambiguous'
  splash_conflict ext4-systemd-boot 'rm -r "$ROOT/boot/loader"' 'no MirrorOS boot configuration'
  splash_conflict ext4-systemd-boot 'printf "sort-key a\n" >> "$ROOT/boot/loader/entries/mirroros.conf"' 'differs from the shipped MirrorOS entry structure'
  splash_conflict ext4-systemd-boot 'mv "$ROOT/boot/loader/entries/mirroros.conf" "$ROOT/boot/entry"; ln -s ../../entry "$ROOT/boot/loader/entries/mirroros.conf"' 'differs from the shipped MirrorOS entry structure'
  splash_conflict ext4-systemd-boot 'sed -i "s/^options .*/& nomodeset/" "$ROOT/boot/loader/entries/mirroros-fallback.conf"' 'options differ from the normal entry'
  splash_conflict btrfs-rescue 'printf "default_options=\"\"\n" >> "$ROOT/etc/mkinitcpio.d/linux.preset"' 'differs from the preset written by the MirrorOS installer'
  splash_conflict ext4-systemd-boot 'mkdir -p "$ROOT/etc/mkinitcpio.conf.d"; printf "HOOKS+=(lvm2)\n" > "$ROOT/etc/mkinitcpio.conf.d/95-local.conf"' 'overrides HOOKS'
  splash_conflict ext4-systemd-boot 'mkdir -p "$ROOT/etc/mkinitcpio.conf.d"; printf "HOOKS=(base udev block filesystems)\n" > "$ROOT/etc/mkinitcpio.conf.d/99-late.conf"' 'overrides HOOKS'
  splash_conflict ext4-systemd-boot 'printf "HOOKS=(base\n  systemd)\n" >> "$ROOT/etc/mkinitcpio.conf"' 'no single-line HOOKS'
  splash_conflict ext4-systemd-boot 'sed -i "s/^HOOKS=(base systemd/HOOKS=(base systemd plymouth/" "$ROOT/etc/mkinitcpio.conf"' 'already lists plymouth'
  splash_conflict ext4-systemd-boot 'sed -i "s/^HOOKS=.*/HOOKS=(base autodetect block filesystems fsck)/" "$ROOT/etc/mkinitcpio.conf"' 'neither systemd nor udev'
  splash_conflict btrfs-limine 'rm "$ROOT/etc/mkinitcpio.conf.d/10-mirroros-limine.conf"' '10-mirroros-limine.conf is missing'
  splash_conflict btrfs-limine 'sed -i "s/ fsck)/)/" "$ROOT/etc/mkinitcpio.conf.d/10-mirroros-limine.conf"' 'differs from the hook drop-in'
  splash_conflict btrfs-limine 'printf "KERNEL_CMDLINE[linux-lts]+=\"x\"\n" >> "$ROOT/etc/default/limine"' 'differs from the shipped MirrorOS structure'
  splash_conflict btrfs-limine 'sed -i "s/ESP_PATH=.*/ESP_PATH=\"\/efi\"/" "$ROOT/etc/default/limine"' 'differs from the shipped MirrorOS structure'
  splash_conflict btrfs-limine 'printf "KERNEL_CMDLINE[default]+=\"\$(id)\"\n" >> "$ROOT/etc/default/limine"' 'differs from the shipped MirrorOS structure'
  splash_conflict btrfs-limine 'export CFG_TEST_ESP_MOUNTED=0' 'The ESP is not mounted'
  splash_conflict btrfs-limine 'export CFG_TEST_MISSING_TOOLS=limine-update; splash_target; cfg_test_boot_fixture btrfs-limine' 'limine-update is not installed'
}

@test "a failed regeneration stays pending, keeps its diagnostics and is retried by the next run" {
  cfg_test_boot_fixture ext4-systemd-boot
  CFG_TEST_MKINITCPIO_FAIL=1 run splash_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 5 ]
  grep -qF 'simulated mkinitcpio failure' "$CFG_TEST_DIR/failed/configure.log"
  [[ "$(state)" =~ ^pending\  ]]
  : > "$CFG_TEST_CALLS"
  run splash_run --output "$CFG_TEST_DIR/retry"
  [ "$status" -eq 0 ]
  grep -qF 'A previous boot image regeneration did not complete' "$CFG_TEST_DIR/retry/configure.log"
  [ "$(regenerations)" -eq 1 ]
  [[ "$(state)" =~ ^complete\  ]]
  splash_assert_unchanged_rerun
}

@test "a regeneration that reports success without the theme is not success and stays retryable" {
  cfg_test_boot_fixture btrfs-limine
  CFG_TEST_LIMINE_SILENT_FAIL=1 run splash_run --output "$CFG_TEST_DIR/silent"
  [ "$status" -eq 4 ]
  grep -qF 'limine-mkinitcpio not found' "$CFG_TEST_DIR/silent/configure.log"
  grep -qF 'the regeneration stays pending' "$CFG_TEST_DIR/silent/configure.log"
  [[ "$(state)" =~ ^pending\  ]]
  run splash_run
  [ "$status" -eq 0 ]
  [[ "$(state)" =~ ^complete\  ]]
}

@test "an interrupted regeneration and a boot image changed behind configure are never reported as unchanged" {
  cfg_test_boot_fixture ext4-systemd-boot
  run splash_run
  [ "$status" -eq 0 ]
  sed -i 's/^complete /pending /' "$ROOT/var/lib/mirroros/configure/boot-splash.state"
  : > "$CFG_TEST_CALLS"
  run splash_run
  [ "$status" -eq 0 ]
  [[ "$output" == *'system/boot-splash: changed'* ]]
  [ "$(regenerations)" -eq 1 ]
  # Matching file hashes alone are not convergence: the generated image itself is inspected.
  printf 'init\n' > "$ROOT/boot/initramfs-linux.img"
  run splash_run --output "$CFG_TEST_DIR/stale"
  [ "$status" -eq 4 ]
  grep -qF 'lacks usr/lib/plymouth/script.so' "$CFG_TEST_DIR/stale/configure.log"
}

@test "a changed base hook sequence updates the drop-in and regenerates once" {
  cfg_test_boot_fixture ext4-systemd-boot
  run splash_run
  [ "$status" -eq 0 ]
  sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck lvm2)/' \
    "$ROOT/etc/mkinitcpio.conf"
  : > "$CFG_TEST_CALLS"
  run splash_run
  [ "$status" -eq 0 ]
  grep -qxF 'HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck lvm2)' \
    "$ROOT/etc/mkinitcpio.conf.d/90-mirroros-plymouth.conf"
  [ "$(regenerations)" -eq 1 ]
  splash_assert_unchanged_rerun
}

@test "an intact static wordmark theme upgrades once and a local script edit remains protected" {
  local script="$CFG_TEST_DIR/code/capabilities/system/boot-splash/plymouth/mirroros.script"
  cfg_test_boot_fixture ext4-systemd-boot
  printf '# managed by MirrorOS configure\nlogo.image = Image("mirroros-wordmark.png");\n' > "$script"
  run splash_run
  [ "$status" -eq 0 ]
  cp "$SPLASH_SOURCE/plymouth/mirroros.script" "$script"
  : > "$CFG_TEST_CALLS"
  run splash_run
  [ "$status" -eq 0 ]
  [ "$(regenerations)" -eq 1 ]
  cmp "$script" "$ROOT/usr/share/plymouth/themes/mirroros/mirroros.script"
  splash_assert_unchanged_rerun
  printf '# local edit\n' >> "$ROOT/usr/share/plymouth/themes/mirroros/mirroros.script"
  : > "$CFG_TEST_CALLS"
  run splash_run --output "$CFG_TEST_DIR/edited-script"
  [ "$status" -eq 4 ]
  grep -qF 'mirroros.script differs from its last MirrorOS delivery' "$CFG_TEST_DIR/edited-script/configure.log"
  [ "$(tail -n 1 "$ROOT/usr/share/plymouth/themes/mirroros/mirroros.script")" = '# local edit' ]
  [ "$(regenerations)" -eq 0 ]
}

@test "the delivered symbol raster participates in regeneration identity" {
  local symbol="$ROOT/usr/share/mirroros/branding/mirroros-symbol.png" before old new
  cfg_test_boot_fixture ext4-systemd-boot
  run splash_run
  [ "$status" -eq 0 ]
  before="$(state)"
  old="$(sha256sum < "$symbol" | cut -d' ' -f1)"
  # Simulate an intact branding publication of different raster bytes, not a local unmanaged edit.
  printf 'new raster bytes\n' >> "$symbol"
  new="$(sha256sum < "$symbol" | cut -d' ' -f1)"
  sed -i "s/$old/$new/" "$ROOT/usr/share/mirroros/branding/.mirroros-manifest"
  : > "$CFG_TEST_CALLS"
  run splash_run
  [ "$status" -eq 0 ]
  [ "$(regenerations)" -eq 1 ]
  [ "$before" != "$(state)" ]
  splash_assert_unchanged_rerun
}

@test "a successful rebuild without the symbol stays pending and recovers on retry" {
  cfg_test_boot_fixture ext4-systemd-boot
  CFG_TEST_INITRAMFS_OMIT_IMAGE=mirroros-symbol.png run splash_run --output "$CFG_TEST_DIR/missing-symbol"
  [ "$status" -eq 4 ]
  grep -qF 'lacks usr/share/mirroros/branding/mirroros-symbol.png' "$CFG_TEST_DIR/missing-symbol/configure.log"
  [[ "$(state)" =~ ^pending\  ]]
  : > "$CFG_TEST_CALLS"
  run splash_run
  [ "$status" -eq 0 ]
  [ "$(regenerations)" -eq 1 ]
  [[ "$(state)" =~ ^complete\  ]]
  image_has_theme /boot/initramfs-linux.img
  splash_assert_unchanged_rerun
  sed -i '\|usr/share/mirroros/branding/mirroros-symbol.png|d' "$ROOT/boot/initramfs-linux.img"
  run splash_run --output "$CFG_TEST_DIR/lost-symbol"
  [ "$status" -eq 4 ]
  grep -qF 'lacks usr/share/mirroros/branding/mirroros-symbol.png' "$CFG_TEST_DIR/lost-symbol/configure.log"
}

@test "udev-based hook sequences place plymouth after udev" {
  cfg_test_boot_fixture ext4-systemd-boot
  sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' \
    "$ROOT/etc/mkinitcpio.conf"
  run splash_run
  [ "$status" -eq 0 ]
  grep -qxF 'HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)' \
    "$ROOT/etc/mkinitcpio.conf.d/90-mirroros-plymouth.conf"
}

@test "the theme uses the shared symbol and native callbacks within its effect boundary" {
  local script="$SPLASH_SOURCE/plymouth/mirroros.script" code
  code="$(grep -vE '^[[:space:]]*#' "$script")"
  grep -qF 'Image("mirroros-symbol.png")' <<< "$code"
  [ "$(grep -c 'SetBackground.*Color(16 / 255, 19 / 255, 21 / 255)' <<< "$code")" -eq 2 ]
  grep -qxF 'Plymouth.SetBootProgressFunction(update_time);' <<< "$code"
  grep -qxF 'Plymouth.SetRefreshFunction(refresh);' <<< "$code"
  [ "$(grep -c 'Plymouth\.Set[A-Za-z]*Function' <<< "$code")" -eq 2 ]
  refute grep -qE 'SetQuitFunction|SetDisplay|SetKeyboard|Text|Sleep|while|for[[:space:]]*\(' <<< "$code"
  grep -qxF 'ModuleName=script' "$SPLASH_SOURCE/plymouth/mirroros.plymouth"
  grep -qxF 'ImageDir=/usr/share/mirroros/branding' "$SPLASH_SOURCE/plymouth/mirroros.plymouth"
  grep -qxF 'ScriptFile=/usr/share/plymouth/themes/mirroros/mirroros.script' "$SPLASH_SOURCE/plymouth/mirroros.plymouth"
  refute grep -qE '/proc/cmdline|systemctl|reboot|arch-chroot|loglevel|chroot ' <<< "$(cat "$SPLASH_SOURCE/apply" "$SPLASH_SOURCE/boot-splash.sh" | grep -vE '^[[:space:]]*#')"
  refute grep -qE '(^|[^_])source [^"]|\. "\$\(cfg_path' "$SPLASH_SOURCE/boot-splash.sh"
  grep -qxF 'plymouth extra' "$SPLASH_SOURCE/packages"
}
