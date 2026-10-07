#!/usr/bin/bash
# shellcheck disable=SC2034,SC2154 # Variant contract variables and installer globals (see lib/README.md).
# btrfs-rescue variant (Story 2.1, Track 2): Btrfs/Snapper with systemd-boot and rescue-based
# rollback. Sourced by guest/install. Non-production.

# shellcheck disable=SC1091 # Resolved from the mounted NoCloud medium at run time.
source "${MIRROROS_SEED_DIR:?}/engine/support/btrfs-stage.sh"

VARIANT_PACKAGES=(btrfs-progs snapper snap-pac compsize)
MIRROROS_STORAGE_EXCLUDE_GROUPS='storage swap'

variant_plan_lines() {
  btrfs_plan_lines
  printf '  4. systemd-boot with rootflags=subvol=@, Snapper root configuration (snap-pac, no timeline),\n'
  printf '     and a "post-install baseline" snapshot\n'
}

variant_install_storage() {
  btrfs_install_storage
}

variant_configure_swap_and_boot() {
  btrfs_configure_swap

  mirroros_proto_log 'boot: systemd-boot'
  run arch-chroot "$TARGET_ROOT" bootctl install --esp-path=/boot
  put "${TARGET_ROOT}/boot/loader/loader.conf" <<'EOF'
default arch.conf
timeout 3
editor no
EOF
  put "${TARGET_ROOT}/boot/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${BTRFS_ROOT_UUID} rootflags=subvol=@ rw resume=UUID=${BTRFS_ROOT_UUID} resume_offset=${BTRFS_RESUME_OFFSET}
EOF
  put "${TARGET_ROOT}/boot/loader/entries/arch-fallback.conf" <<EOF
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-linux
initrd  /initramfs-linux-fallback.img
options root=UUID=${BTRFS_ROOT_UUID} rootflags=subvol=@ rw resume=UUID=${BTRFS_ROOT_UUID} resume_offset=${BTRFS_RESUME_OFFSET}
EOF
  run arch-chroot "$TARGET_ROOT" systemctl enable systemd-boot-update.service
}

variant_finalize() {
  btrfs_configure_snapper
  btrfs_take_baseline
}
