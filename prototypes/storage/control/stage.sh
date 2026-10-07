#!/usr/bin/bash
# shellcheck disable=SC2034,SC2154 # Variant contract variables and installer globals (see lib/README.md).
# Control variant (Story 2.1, Track 2): ext4 root, /swapfile, systemd-boot. Sourced by guest/install.
# The functions below are the 02-01 storage and swap/boot stages of native-arch/guest/install, moved
# here without changes. Non-production.

VARIANT_PACKAGES=()

variant_plan_lines() {
  printf '  1. GPT: 1 GiB FAT32 ESP at /boot, ext4 root for the rest of the disk\n'
  printf '  3. genfstab -U, then a 4 GiB /swapfile with resume parameters\n'
  printf '  4. systemd-boot with the primary and fallback entries, timeout 3, editor no\n'
}

variant_install_storage() {
  mirroros_proto_log 'storage: partitioning'
  run sfdisk --wipe always --wipe-partitions always "$TARGET_DISK" <<'EOF'
label: gpt
size=1GiB, type=U
type=L
EOF
  run udevadm settle
  run mkfs.fat -F 32 "$ESP_PARTITION"
  run mkfs.ext4 -q "$ROOT_PARTITION"
  run mount "$ROOT_PARTITION" "$TARGET_ROOT"
  # umask=0077 keeps the random seed on the ESP from being world accessible (bootctl warns otherwise).
  run mount --mkdir -o umask=0077 "$ESP_PARTITION" "${TARGET_ROOT}/boot"
}

variant_configure_swap_and_boot() {
  local root_uuid
  local offset

  mirroros_proto_log 'swap'
  run mkswap -U clear --size 4G --file "${TARGET_ROOT}/swapfile"
  printf '/swapfile none swap defaults 0 0\n' >> "${TARGET_ROOT}/etc/fstab" || {
    mirroros_proto_log 'could not append the swapfile to fstab'
    exit 1
  }
  root_uuid="$(blkid -s UUID -o value "$ROOT_PARTITION")" || exit 1
  offset="$(filefrag -v "${TARGET_ROOT}/swapfile" | awk '$1 == "0:" { gsub(/\./, "", $4); print $4; exit }')"
  if [[ -z "$root_uuid" || ! "$offset" =~ ^[0-9]+$ ]]; then
    mirroros_proto_log 'could not determine the root UUID or the swapfile resume offset'
    exit 1
  fi

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
options root=UUID=${root_uuid} rw resume=UUID=${root_uuid} resume_offset=${offset}
EOF
  put "${TARGET_ROOT}/boot/loader/entries/arch-fallback.conf" <<EOF
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-linux
initrd  /initramfs-linux-fallback.img
options root=UUID=${root_uuid} rw resume=UUID=${root_uuid} resume_offset=${offset}
EOF
  run arch-chroot "$TARGET_ROOT" systemctl enable systemd-boot-update.service
}

# The control has no snapshot stage and keeps every 02-01 check (no excluded groups).
variant_finalize() {
  :
}
