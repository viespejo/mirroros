#!/usr/bin/bash
# shellcheck disable=SC2034,SC2154 # Variant contract variables and installer globals (see lib/README.md).
# Shared Btrfs stage for btrfs-rescue and btrfs-limine (Story 2.1, Track 2), sourced by the variant
# stage.sh inside guest/install. Layout per DEC-003, mounts per DEC-004, Snapper policy per DEC-005.
# Non-production.

BTRFS_MOUNT_OPTIONS='compress=zstd:1,relatime'
BTRFS_SNAPSHOT_BASELINE='post-install baseline'
BTRFS_ROOT_UUID=''
BTRFS_RESUME_OFFSET=''

# Both Btrfs variants replace the 02-01 storage and swap checks, and check the swapfile with btrfs.
MIRROROS_STORAGE_SWAPFILE='/swap/swapfile'
MIRROROS_STORAGE_OFFSET_TOOL='btrfs'

btrfs_plan_lines() {
  printf '  1. GPT: 1 GiB FAT32 ESP at /boot, one Btrfs filesystem with flat subvolumes\n'
  printf '     @ (/), @home, @log, @pkg, @snapshots (/.snapshots), @swap (/swap), mounted with %s\n' "$BTRFS_MOUNT_OPTIONS"
  printf '  3. genfstab -U, then a 4 GiB NOCOW /swap/swapfile with resume parameters\n'
}

btrfs_install_storage() {
  local subvolume
  local mount_point

  mirroros_proto_log 'storage: partitioning'
  run sfdisk --wipe always --wipe-partitions always "$TARGET_DISK" <<'EOF'
label: gpt
size=1GiB, type=U
type=L
EOF
  run udevadm settle
  run mkfs.fat -F 32 "$ESP_PARTITION"
  run mkfs.btrfs -q -f -L mirroros "$ROOT_PARTITION"

  mirroros_proto_log 'storage: subvolumes'
  run mount "$ROOT_PARTITION" "$TARGET_ROOT"
  for subvolume in @ @home @log @pkg @snapshots @swap; do
    run btrfs subvolume create "${TARGET_ROOT}/${subvolume}"
  done
  run umount "$TARGET_ROOT"

  # Every subvolume is mounted with the same options from before pacstrap.
  run mount -o "${BTRFS_MOUNT_OPTIONS},subvol=@" "$ROOT_PARTITION" "$TARGET_ROOT"
  for subvolume in @home @log @pkg @snapshots @swap; do
    case "$subvolume" in
      @home) mount_point=home ;;
      @log) mount_point=var/log ;;
      @pkg) mount_point=var/cache/pacman/pkg ;;
      @snapshots) mount_point=.snapshots ;;
      @swap) mount_point=swap ;;
    esac
    run mount --mkdir -o "${BTRFS_MOUNT_OPTIONS},subvol=${subvolume}" "$ROOT_PARTITION" "${TARGET_ROOT}/${mount_point}"
  done
  # umask=0077 keeps the random seed on the ESP from being world accessible.
  run mount --mkdir -o umask=0077 "$ESP_PARTITION" "${TARGET_ROOT}/boot"
}

# Creates the NOCOW swapfile in @swap and sets BTRFS_ROOT_UUID and BTRFS_RESUME_OFFSET.
btrfs_configure_swap() {
  mirroros_proto_log 'swap'
  # genfstab records subvolid= next to subvol=. A rollback replaces @ with a new subvolume id, and a
  # mount with a stale subvolid= would fail, so only the subvolume paths stay in fstab.
  run sed -i 's/subvolid=[0-9]*,//' "${TARGET_ROOT}/etc/fstab"
  run btrfs filesystem mkswapfile --size 4g --uuid clear "${TARGET_ROOT}/swap/swapfile"
  printf '/swap/swapfile none swap defaults 0 0\n' >> "${TARGET_ROOT}/etc/fstab" || {
    mirroros_proto_log 'could not append the swapfile to fstab'
    exit 1
  }
  BTRFS_ROOT_UUID="$(blkid -s UUID -o value "$ROOT_PARTITION")" || exit 1
  BTRFS_RESUME_OFFSET="$(btrfs inspect-internal map-swapfile -r "${TARGET_ROOT}/swap/swapfile")" || exit 1
  if [[ -z "$BTRFS_ROOT_UUID" || ! "$BTRFS_RESUME_OFFSET" =~ ^[0-9]+$ ]]; then
    mirroros_proto_log 'could not determine the root UUID or the swapfile resume offset'
    exit 1
  fi
}

# Snapper root configuration for @ only. The @snapshots subvolume is mounted at /.snapshots before
# create-config, which needs to create that path itself, so the mount is replaced around the call.
btrfs_configure_snapper() {
  mirroros_proto_log 'snapshots: Snapper root configuration'
  run umount "${TARGET_ROOT}/.snapshots"
  run rmdir "${TARGET_ROOT}/.snapshots"
  run arch-chroot "$TARGET_ROOT" snapper --no-dbus -c root create-config /
  run btrfs subvolume delete "${TARGET_ROOT}/.snapshots"
  run mkdir -m 750 "${TARGET_ROOT}/.snapshots"
  run mount -o "${BTRFS_MOUNT_OPTIONS},subvol=@snapshots" "$ROOT_PARTITION" "${TARGET_ROOT}/.snapshots"
  run chmod 750 "${TARGET_ROOT}/.snapshots"
  run arch-chroot "$TARGET_ROOT" snapper --no-dbus -c root set-config \
    TIMELINE_CREATE=no NUMBER_CLEANUP=yes NUMBER_LIMIT=10
  run arch-chroot "$TARGET_ROOT" systemctl enable snapper-cleanup.timer
  run arch-chroot "$TARGET_ROOT" systemctl disable snapper-timeline.timer
}

# Takes the baseline last, so it holds the complete installed system including the prototype units.
btrfs_take_baseline() {
  mirroros_proto_log 'snapshots: post-install baseline'
  run arch-chroot "$TARGET_ROOT" snapper --no-dbus -c root create --type single \
    --description "$BTRFS_SNAPSHOT_BASELINE"
}
