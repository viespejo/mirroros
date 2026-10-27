#!/usr/bin/bash
# shellcheck disable=SC2034 # Test state is consumed by Bats files sourcing this support library.
CFG_SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"

cfg_test_setup() {
  CFG_TEST_ORIGINAL_PATH="$PATH"
  CFG_TEST_DIR="$(mktemp -d)"
  export CFG_TEST_DIR
  export MIRROROS_CONFIGURE_ROOT="$CFG_TEST_DIR/root"
  export CFG_TEST_HOME="$CFG_TEST_DIR/home"
  export CFG_TEST_CALLS="$CFG_TEST_DIR/calls"
  export CFG_TEST_INSTALLED="$CFG_TEST_DIR/installed"
  export CFG_TEST_UID=0 SUDO_USER=alice
  mkdir -p "$MIRROROS_CONFIGURE_ROOT"/{etc,run/mirroros,var/lib/pacman/sync,usr/share/X11/xkb/rules} \
    "$CFG_TEST_HOME" "$CFG_TEST_INSTALLED" "$CFG_TEST_DIR/bin" "$CFG_TEST_DIR/code/operations/lib"
  cp "$CFG_SOURCE_ROOT/operations/configure" "$CFG_TEST_DIR/code/operations/"
  cp "$CFG_SOURCE_ROOT/operations/lib/lifecycle-discovery.sh" "$CFG_TEST_DIR/code/operations/lib/"
  cp "$CFG_SOURCE_ROOT/operations/lib/timing.sh" "$CFG_TEST_DIR/code/operations/lib/"
  cp -R "$CFG_SOURCE_ROOT/capabilities" "$CFG_TEST_DIR/code/"
  cp "$CFG_SOURCE_ROOT/tests/capabilities/doubles/"* "$CFG_TEST_DIR/bin/"
  chmod 0755 "$CFG_TEST_DIR/bin/"*
  export PATH="$CFG_TEST_DIR/bin:$PATH"
  : > "$CFG_TEST_CALLS"
  : > "$MIRROROS_CONFIGURE_ROOT/var/lib/pacman/sync/extra.db"
  printf '! layout\n  us English (US)\n  es Spanish\n! variant\n' > "$MIRROROS_CONFIGURE_ROOT/usr/share/X11/xkb/rules/base.lst"
  printf 'CFG_STEPS=()\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  CFG_TEST_ENTRY="$CFG_TEST_DIR/code/operations/configure"
}

cfg_test_teardown() {
  export PATH="$CFG_TEST_ORIGINAL_PATH"
  hash -r
  rm -rf -- "$CFG_TEST_DIR"
}

cfg_test_step() {
  local name="${1:-example}" body="${2:-cfg_packages_ensure \"\$STEP_DIR/packages\"}"
  mkdir -p "$CFG_TEST_DIR/code/capabilities/$name"
  printf 'CFG_STEPS=(%s)\n' "$name" > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  printf 'example extra\n' > "$CFG_TEST_DIR/code/capabilities/$name/packages"
  printf '%s\n' "$body" > "$CFG_TEST_DIR/code/capabilities/$name/apply"
}

cfg_test_helpers() {
  local script="$1"
  bash -Eeuo pipefail -c '
    CAPABILITIES_DIR="$CFG_TEST_DIR/code/capabilities"
    source "$CFG_TEST_DIR/code/operations/lib/timing.sh"
    for lib in common validate packages files units evidence repositories; do
      source "$CAPABILITIES_DIR/lib/$lib.sh"
    done
    TARGET_USER=alice
    CFG_OUTPUT="$CFG_TEST_DIR/helper-output"
    mkdir -p "$CFG_OUTPUT"
    source /dev/stdin
  ' <<< "$script"
}

cfg_test_target_context() {
  export CFG_TEST_TARGET_ROOT="$MIRROROS_CONFIGURE_ROOT"
  unset MIRROROS_CONFIGURE_ROOT
  export CFG_TEST_HOME="$CFG_TEST_TARGET_ROOT/home/alice"
  mkdir -p "$CFG_TEST_HOME"
  printf 'root:x:0:0:root:/root:/usr/bin/bash\nalice:x:1000:1000::/home/alice:/usr/bin/bash\n' > "$CFG_TEST_TARGET_ROOT/etc/passwd"
  printf '{"commit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","dirty":true}\n' > "$CFG_TEST_DIR/code/identity.json"
}

cfg_test_no_install() { ! grep -Eq '^pacman -S(yu)? ' "$CFG_TEST_CALLS"; }

# The boot configuration the installation engine writes for <storage-option>, with hibernation enabled unless the
# second argument is false, below the active configure root. CFG_TEST_CMDLINE receives the base command line.
cfg_test_boot_fixture() {
  local option="$1" hibernation="${2:-true}" root="${CFG_TEST_TARGET_ROOT:-${MIRROROS_CONFIGURE_ROOT:-}}"
  local uuid=0f3c5a8e-1b2d-4c6e-9a7b-3d5e7f9a1b2c machine=4d1f6c2a9e8b4c7d8e9f0a1b2c3d4e5f
  CFG_TEST_CMDLINE="root=UUID=$uuid rw zswap.enabled=0"
  [[ "$hibernation" != true ]] || CFG_TEST_CMDLINE+=" resume=UUID=$uuid resume_offset=533760"
  [[ "$option" == ext4-systemd-boot ]] || CFG_TEST_CMDLINE+=' rootflags=subvol=@'
  export CFG_TEST_CMDLINE
  mkdir -p "$root/etc/mkinitcpio.d" "$root/boot"
  printf '# vim:set ft=sh\nMODULES=()\nBINARIES=()\nFILES=()\n#    HOOKS=(base udev autodetect modconf block filesystems fsck)\nHOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)\n' \
    > "$root/etc/mkinitcpio.conf"
  if [[ "$option" == btrfs-limine ]]; then
    mkdir -p "$root/etc/default" "$root/etc/mkinitcpio.conf.d" "$root/boot/$machine/linux" "$root/boot/$machine/limine_history" \
      "$root/boot/EFI/BOOT"
    printf 'ESP_PATH="/boot"\nSKIP_UEFI=yes\nKERNEL_CMDLINE[default]="%s"\n' "$CFG_TEST_CMDLINE" > "$root/etc/default/limine"
    printf 'HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems sd-btrfs-overlayfs fsck)\n' \
      > "$root/etc/mkinitcpio.conf.d/10-mirroros-limine.conf"
    printf 'kernel\n' > "$root/boot/$machine/linux/vmlinuz-linux"
    printf 'init\n' > "$root/boot/$machine/linux/initramfs-linux"
    printf 'kernel\n' > "$root/boot/$machine/limine_history/vmlinuz-linux_1"
    printf 'init\n' > "$root/boot/$machine/limine_history/initramfs-linux_1"
    printf 'efi\n' > "$root/boot/EFI/BOOT/BOOTX64.EFI"
    printf '%s\n' 'timeout: 3' '' '/+Arch Linux' '//linux' '    protocol: linux' \
      "    path: boot():/$machine/linux/vmlinuz-linux" "    cmdline: $CFG_TEST_CMDLINE" \
      "    module_path: boot():/$machine/linux/initramfs-linux" '//Snapshots' '///1 baseline' '    protocol: linux' \
      "    path: boot():/$machine/limine_history/vmlinuz-linux_1" \
      "    cmdline: ${CFG_TEST_CMDLINE/subvol=@/subvol=/@snapshots/1/snapshot}" \
      "    module_path: boot():/$machine/limine_history/initramfs-linux_1" > "$root/boot/limine.conf"
    return 0
  fi
  mkdir -p "$root/boot/loader/entries"
  printf 'default mirroros.conf\ntimeout 3\neditor no\n' > "$root/boot/loader/loader.conf"
  printf 'title MirrorOS\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions %s\n' "$CFG_TEST_CMDLINE" \
    > "$root/boot/loader/entries/mirroros.conf"
  printf 'title MirrorOS (fallback initramfs)\nlinux /vmlinuz-linux\ninitrd /initramfs-linux-fallback.img\noptions %s\n' \
    "$CFG_TEST_CMDLINE" > "$root/boot/loader/entries/mirroros-fallback.conf"
  printf 'ALL_kver="/boot/vmlinuz-linux"\nPRESETS=("default" "fallback")\ndefault_image="/boot/initramfs-linux.img"\nfallback_image="/boot/initramfs-linux-fallback.img"\nfallback_options="-S autodetect"\n' \
    > "$root/etc/mkinitcpio.d/linux.preset"
  printf 'kernel\n' > "$root/boot/vmlinuz-linux"
  printf 'init\n' > "$root/boot/initramfs-linux.img"
  printf 'init\n' > "$root/boot/initramfs-linux-fallback.img"
}
