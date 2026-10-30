#!/usr/bin/bash
# shellcheck disable=SC2034 # Run state is read by common.sh (finish) and by the other operation libraries.
# Storage, mount, package, fstab, and swapfile operations of the installation engine. Each function runs one
# plan operation and checks its immediate effect (contracts/installation-engine.md, "Operations, values, and
# checks"). The target disk is addressed through DISK_NODE, resolved by the pre-check.

readonly ESP_TYPE_GUID='C12A7328-F81F-11D2-BA4B-00A0C93EC93B'
readonly ROOT_TYPE_GUID='0FC63DAF-8483-4772-8E79-3D69D8477DE4'
readonly MIBIBYTE=1048576

ROOT_FILESYSTEM=''

# The kernel's partition node naming: a disk name ending in a digit takes a "p" before the number.
partition_node() {
  if [[ "$DISK_NODE" =~ [0-9]$ ]]; then printf '%sp%s' "$DISK_NODE" "$1"; else printf '%s%s' "$DISK_NODE" "$1"; fi
}

sync_partitions() {
  run blockdev --flushbufs "$DISK_NODE"
  run partprobe "$DISK_NODE"
  run udevadm settle
}

PRE_WIPE_PARTUUIDS=()

op_record_disk_partuuids() {
  param_lines partuuids PRE_WIPE_PARTUUIDS
  record_constant record_disk_partuuids.partuuids "$(join_by_comma "${PRE_WIPE_PARTUUIDS[@]}")"
}

op_remove_stale_uefi_entries() {
  [[ "$TARGET_MODE" == whole_disk ]] || check_fail 'NVRAM cleanup requires whole-disk mode'
  run_uefi uefi_remove_partuuids "${PRE_WIPE_PARTUUIDS[@]}"
}

op_wipe_partition_signatures() {
  [[ "$TARGET_MODE" == replace_installation && "$ESP_PART" != "$DISK_NODE" && "$ROOT_PART" != "$DISK_NODE" ]] \
    || check_fail 'partition wipe requires a replacement target'
  run wipefs --all "$ESP_PART" "$ROOT_PART"
  local node remaining
  for node in "$ESP_PART" "$ROOT_PART"; do
    capture remaining wipefs --noheadings "$node"
    [[ -z "$remaining" ]] || check_fail 'a target partition still has signatures'
  done
}

verify_untouched_partitions() {
  [[ "$TARGET_MODE" == replace_installation ]] || return 0
  local dump="${OUTPUT}/partition-table-after.sfdisk" storage="${OUTPUT}/.storage-after.json" record
  capture record sfdisk --dump "$DISK_NODE"
  printf '%s\n' "$record" > "$dump"
  capture record lsblk --json --tree --bytes --output PATH,KNAME,TYPE,SIZE,PTTYPE,PTUUID,FSTYPE,LABEL,UUID,PARTUUID,PARTTYPE,PARTN,START,PARTLABEL,LOG-SEC,MOUNTPOINTS
  printf '%s\n' "$record" > "$storage"
  if ! record="$(node_helper load-plan.mjs partition-record --dump "$dump" --storage "$storage" 2>> "$ENGINE_LOG")"; then
    check_fail 'the partition table differs after replacement'
  fi
  rm -f -- "$storage"
  printf '%s\n' "$record" > "${OUTPUT}/untouched-partitions-after.json"
  cmp -s -- "${OUTPUT}/untouched-partitions-before.json" "${OUTPUT}/untouched-partitions-after.json" \
    || check_fail 'non-target partition entries or identities changed'
  record_constant format_partitions.untouched_partitions_verified true
}

op_wipe_disk_signatures() {
  local nodes=() name remaining
  while IFS= read -r name; do
    [[ -n "$name" && "$name" != "${DISK_NODE##*/}" ]] && nodes+=("$(sys_path "/dev/${name}")")
  done < <(disk_sysfs_names)
  run wipefs --all "${nodes[@]}" "$DISK_NODE"
  capture remaining wipefs --noheadings "$DISK_NODE"
  [[ -z "$remaining" ]] || check_fail 'wipefs still finds a signature on the disk'
}

op_create_partition_table() {
  local table dump
  table="$(param table)"
  [[ "$table" == gpt ]] || check_fail "the partition table ${table} is not gpt"
  run_with_input 'label: gpt' sfdisk --wipe always --no-reread "$DISK_NODE"
  capture dump sfdisk --dump "$DISK_NODE"
  [[ "$dump" == *'label: gpt'* ]] || check_fail 'the disk does not report a gpt partition table'
}

op_create_partitions() {
  local esp_bytes esp_mib script esp_type root_type size
  esp_bytes="$(param esp_size_bytes)"
  [[ "$esp_bytes" =~ ^[0-9]+$ ]] || check_fail 'esp_size_bytes is not a positive integer'
  (( esp_bytes > 0 && esp_bytes % MIBIBYTE == 0 )) || check_fail 'esp_size_bytes is not a positive multiple of 1 MiB'
  esp_mib=$((esp_bytes / MIBIBYTE))
  script=$'label: gpt\n'"start=1MiB, size=${esp_mib}MiB, type=U"$'\n'"type=L"
  run_with_input "$script" sfdisk --wipe always --no-reread "$DISK_NODE"
  sync_partitions
  ESP_PART="$(partition_node 1)"
  ROOT_PART="$(partition_node 2)"
  [[ -e "$ESP_PART" && -e "$ROOT_PART" ]] || check_fail 'a partition node is missing after partitioning'
  capture size blockdev --getsize64 "$ESP_PART"
  [[ "$size" == "$esp_bytes" ]] || check_fail 'the ESP size differs from the plan'
  capture esp_type sfdisk --part-type "$DISK_NODE" 1
  capture root_type sfdisk --part-type "$DISK_NODE" 2
  [[ "${esp_type^^}" == "$ESP_TYPE_GUID" && "${root_type^^}" == "$ROOT_TYPE_GUID" ]] || check_fail 'a partition type differs from the plan'
}

op_format_filesystems() {
  local root_filesystem esp_type root_type
  root_filesystem="$(param root_filesystem)"
  [[ "$(param esp_filesystem)" == vfat ]] || check_fail 'the ESP filesystem is not vfat'
  ROOT_FILESYSTEM="$root_filesystem"
  run mkfs.fat -F 32 "$ESP_PART"
  case "$root_filesystem" in
    ext4) run mkfs.ext4 -F -L mirroros "$ROOT_PART" ;;
    btrfs) run mkfs.btrfs -f -L mirroros "$ROOT_PART" ;;
    *) check_fail "the root filesystem ${root_filesystem} is not supported" ;;
  esac
  capture ESP_UUID blkid --output value --match-tag UUID "$ESP_PART"
  capture ROOT_UUID blkid --output value --match-tag UUID "$ROOT_PART"
  capture esp_type blkid --output value --match-tag TYPE "$ESP_PART"
  capture root_type blkid --output value --match-tag TYPE "$ROOT_PART"
  [[ "$ESP_UUID" =~ ^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$ ]] || check_fail 'the ESP volume id is not well formed'
  [[ "$ROOT_UUID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || check_fail 'the root UUID is not well formed'
  [[ "$esp_type" == vfat && "$root_type" == "$root_filesystem" ]] || check_fail 'a filesystem differs from the plan'
  RESOLVED+=("esp_uuid=${ESP_UUID}" "root_uuid=${ROOT_UUID}")
}

op_mount_target() {
  [[ "$(param esp_mount_point)" == /boot ]] || check_fail 'the ESP mount point is not /boot'
  install -d -m 0700 -- "$TARGET"
  if [[ "$ROOT_FILESYSTEM" == btrfs ]]; then
    [[ -n "$BTRFS_MOUNT_OPTIONS" ]] || check_fail 'the Btrfs mount options were not resolved'
    run mount -o "${BTRFS_MOUNT_OPTIONS},subvol=@" "$ROOT_PART" "$TARGET"
    mount_btrfs_subvolumes
  else
    run mount "$ROOT_PART" "$TARGET"
  fi
  install -d -m 0755 -- "${TARGET}/boot"
  run mount -o umask=0077 "$ESP_PART" "${TARGET}/boot"
  mountpoint -q "$TARGET" || check_fail 'the root mount is missing'
  mountpoint -q "${TARGET}/boot" || check_fail 'the ESP mount is missing'
}

count_installed_packages() {
  local database="${TARGET}/var/lib/pacman/local" count=0 entry
  for entry in "$database"/*/; do
    [[ -d "$entry" ]] && count=$((count + 1))
  done
  printf '%s' "$count"
}

op_install_packages() {
  local packages=() rule_packages=() pid status=0 live_mirrorlist target_mirrorlist installed_list
  param_lines packages packages
  param_lines rule_packages rule_packages
  [[ "${#packages[@]}" -gt 0 ]] || check_fail 'the plan lists no package'
  packages+=("${rule_packages[@]}")
  LAST_ARGV=(pacstrap -K "$TARGET" "${packages[@]}")
  printf '$ %s\n' "${LAST_ARGV[*]}" >> "$ENGINE_LOG"
  # umask 022: pacstrap creates /etc implicitly (mkdir -m applies only to the deepest directory).
  (umask 022; exec pacstrap -K "$TARGET" "${packages[@]}") < /dev/null >> "$ENGINE_LOG" 2>&1 3>&- 4>&- &
  pid=$!
  while kill -0 "$pid" 2> /dev/null; do
    PACKAGE_COUNT="$(count_installed_packages)"
    write_state running install_packages
    sleep 2 || true
  done
  wait "$pid" || status=$?
  if (( status != 0 )); then
    LAST_STATUS="$status"
    stage_fail
  fi
  PACKAGE_COUNT="$(count_installed_packages)"
  write_state running install_packages
  live_mirrorlist="$(sys_path /etc/pacman.d/mirrorlist)"
  target_mirrorlist="${TARGET}/etc/pacman.d/mirrorlist"
  [[ -e "${TARGET}/boot/vmlinuz-linux" && -e "${TARGET}/boot/initramfs-linux.img" ]] || check_fail 'the kernel or the initramfs is missing under /boot'
  cmp -s -- "$live_mirrorlist" "$target_mirrorlist" || check_fail 'the target mirrorlist differs from the live one'
  mapfile -t MIRROR_SERVERS < <(grep -E '^[[:space:]]*Server[[:space:]]*=' "$target_mirrorlist" || true)
  MIRRORLIST_SHA256="$(sha256sum -- "$target_mirrorlist")"
  MIRRORLIST_SHA256="${MIRRORLIST_SHA256%% *}"
  capture installed_list arch-chroot "$TARGET" pacman -Q
  printf '%s\n' "$installed_list" > "${OUTPUT}/target-packages.txt"
  chmod 0600 -- "${OUTPUT}/target-packages.txt"
}

op_generate_fstab() {
  run_to_target_file 0644 /etc/fstab genfstab -U "$TARGET"
  if [[ "$ROOT_FILESYSTEM" == btrfs ]]; then filter_fstab_subvolume_ids; fi
  grep -q -- "UUID=${ROOT_UUID}" "${TARGET}/etc/fstab" || check_fail 'the root filesystem is not in fstab by UUID'
  grep -q -- "UUID=${ESP_UUID}" "${TARGET}/etc/fstab" || check_fail 'the ESP is not in fstab by UUID'
  ! grep -q 'subvolid=' "${TARGET}/etc/fstab" || check_fail 'fstab holds a subvolume id'
}

op_create_swapfile() {
  local path size_mib priority first_extent size mode swap_path
  path="$(param path)"
  size_mib="$(param size_mib)"
  priority="$(param priority)"
  [[ "$path" == /swapfile && "$size_mib" =~ ^[0-9]+$ && "$priority" =~ ^[0-9]+$ ]] || check_fail 'the swapfile parameters are not valid'
  swap_path="$path"
  if [[ "$ROOT_FILESYSTEM" == btrfs ]]; then
    # The plan's path is the same for every option; on Btrfs the file lives in the @swap subvolume mounted at /swap.
    swap_path=/swap/swapfile
    mountpoint -q "${TARGET}/swap" || check_fail 'the @swap subvolume is not mounted at /swap'
    run btrfs filesystem mkswapfile --size "${size_mib}M" "${TARGET}${swap_path}"
    capture RESUME_OFFSET btrfs inspect-internal map-swapfile -r "${TARGET}${swap_path}"
  else
    run mkswap --file "${TARGET}${path}" --size "${size_mib}M"
    capture first_extent filefrag -v "${TARGET}${path}"
    RESUME_OFFSET="$(awk '$1 == "0:" { sub(/\.\./, "", $4); print $4; exit }' <<< "$first_extent")"
  fi
  [[ "$RESUME_OFFSET" =~ ^[1-9][0-9]*$ ]] || check_fail 'the resume offset is not a positive integer'
  size="$(stat -c %s -- "${TARGET}${swap_path}")"
  mode="$(stat -c %a -- "${TARGET}${swap_path}")"
  [[ "$size" == "$((size_mib * MIBIBYTE))" && "$mode" == 600 ]] || check_fail 'the swapfile size or mode differs from the plan'
  printf '%s none swap defaults,pri=%s 0 0\n' "$swap_path" "$priority" >> "${TARGET}/etc/fstab"
  grep -q -- "^${swap_path} none swap" "${TARGET}/etc/fstab" || check_fail 'the swapfile is not in fstab'
  RESOLVED+=("resume_offset=${RESUME_OFFSET}")
}
