#!/usr/bin/bash
# shellcheck disable=SC2154 # Facts and constants come from verify-postconditions.sh, which sources this file.
# Storage checks for the Btrfs variants. This file is sourced by verify-postconditions.sh (boot 2
# and every later verifying boot) when MIRROROS_VERIFY_EXTRA_CHECKS points at it, so it uses that
# script's functions (record, pass, fail, replaces) and facts (DISK, ESP_DEV, ROOT_DEV, ROOT_UUID,
# SWAP_OFFSET, SWAPFILE_PATH, DEFAULT_ENTRY_FILE). It replaces the check groups that the 02-01
# script hardcodes for ext4, /swapfile with filefrag, and systemd-boot (DEC-010):
#   storage_*  -> btrfs_* and snapper_* checks (every Btrfs variant)
#   swap_*     -> btrfs_swap_* and btrfs_resume_match (every Btrfs variant)
#   boot_*     -> limine_* checks (btrfs-limine only)
# Every replacement check is registered with its group, so the report names it.

STORAGE_VARIANT="${MIRROROS_STORAGE_VARIANT:-}"
SNAPSHOT_BASELINE_DESCRIPTION='post-install baseline'
LIMINE_CONFIG_CANDIDATES=(/boot/limine.conf /boot/EFI/limine/limine.conf /boot/EFI/BOOT/limine.conf /boot/limine/limine.conf)

# Booted from a Limine snapshot entry: / is then an overlay (sd-btrfs-overlayfs), so the facts that
# verify-postconditions.sh derives from / come from the Btrfs mount of /home instead.
SNAPSHOT_BOOT=0
if [[ "$(findmnt -no FSTYPE / 2> /dev/null)" == 'overlay' ]]; then
  SNAPSHOT_BOOT=1
  ROOT_DEV="$(findmnt -no SOURCE /home 2> /dev/null)"
  ROOT_DEV="${ROOT_DEV%%\[*}"
  ROOT_UUID="$(findmnt -no UUID /home 2> /dev/null)"
  SNAPSHOT_DISK="$(lsblk -no PKNAME "$ROOT_DEV" 2> /dev/null | head -n 1)"
  [[ -z "$SNAPSHOT_DISK" ]] || DISK="/dev/${SNAPSHOT_DISK}"
fi

declare -A SUBVOLUME_MOUNTS=(
  ['@']=/
  ['@home']=/home
  ['@log']=/var/log
  ['@pkg']=/var/cache/pacman/pkg
  ['@snapshots']=/.snapshots
  ['@swap']=/swap
)

# Records a replacement check. Arguments: group, id, passed|failed, detail.
replacement() {
  replaces "$1" "$2"
  record "$2" "$3" "$4"
}

# Records passed when the command succeeds. Arguments: group, id, ok detail, bad detail, command...
replacement_verdict() {
  local group="$1"
  local id="$2"
  local ok_detail="$3"
  local bad_detail="$4"

  shift 4
  if "$@" > /dev/null 2>&1; then replacement "$group" "$id" passed "$ok_detail"; else replacement "$group" "$id" failed "$bad_detail"; fi
}

# ---- storage group: disk layout, Btrfs, compression, fstab, Snapper ---------------------------

check_btrfs_disk_layout() {
  local pttype
  local partitions
  local esp_fstype
  local esp_size
  local esp_type

  pttype="$(lsblk -dno PTTYPE "$DISK" 2> /dev/null)"
  partitions="$(lsblk -nlo TYPE "$DISK" 2> /dev/null | grep -c '^part$')"
  if [[ "$pttype" == 'gpt' ]]; then replacement storage btrfs_gpt passed 'partition table is GPT'; else replacement storage btrfs_gpt failed "partition table is ${pttype:-unknown}"; fi
  if [[ "$partitions" -eq 2 ]]; then replacement storage btrfs_two_partitions passed 'exactly two partitions'; else replacement storage btrfs_two_partitions failed "${partitions} partitions"; fi

  esp_fstype="$(findmnt -no FSTYPE /boot 2> /dev/null)"
  esp_size="$(lsblk -bdno SIZE "$ESP_DEV" 2> /dev/null)"
  esp_type="$(lsblk -dno PARTTYPE "$ESP_DEV" 2> /dev/null | tr '[:upper:]' '[:lower:]')"
  if [[ "$esp_fstype" == 'vfat' && "$esp_type" == "$ESP_PARTITION_TYPE" && "$esp_size" =~ ^[0-9]+$ ]] && \
    [[ "$esp_size" -ge $((EXPECTED_ESP_BYTES - ESP_TOLERANCE_BYTES)) && "$esp_size" -le $((EXPECTED_ESP_BYTES + ESP_TOLERANCE_BYTES)) ]]; then
    replacement storage btrfs_esp passed "1 GiB FAT32 ESP at /boot, ${esp_size} bytes"
  else
    replacement storage btrfs_esp failed "ESP at /boot: fstype ${esp_fstype:-none}, type ${esp_type:-none}, size ${esp_size:-none}"
  fi
}

check_btrfs_layout() {
  local subvolume
  local mount_point
  local options
  local missing=''
  local bad_options=''
  local qgroup_output
  local qgroup_path=/

  if [[ "$SNAPSHOT_BOOT" -eq 1 ]]; then
    qgroup_path=/home
    replacement storage btrfs_root passed 'root is an overlay over a read-only snapshot (snapshot boot); @ is not mounted at /'
  elif [[ "$(findmnt -no FSTYPE / 2> /dev/null)" == 'btrfs' ]]; then replacement storage btrfs_root passed 'root is Btrfs'; else replacement storage btrfs_root failed "root is $(findmnt -no FSTYPE / 2> /dev/null)"; fi

  for subvolume in '@' '@home' '@log' '@pkg' '@snapshots' '@swap'; do
    [[ "$SNAPSHOT_BOOT" -eq 1 && "$subvolume" == '@' ]] && continue
    mount_point="${SUBVOLUME_MOUNTS[$subvolume]}"
    options="$(findmnt -no FSTYPE,OPTIONS "$mount_point" 2> /dev/null)"
    [[ "$options" == btrfs* && ",${options#* }," == *",subvol=/${subvolume},"* ]] || missing+=" ${subvolume}@${mount_point}"
    if [[ "$options" != *compress=zstd:1* || "$options" == *compress-force* || "$options" == *noatime* || "$options" != *relatime* ]]; then
      bad_options+=" ${subvolume}"
    fi
  done
  if [[ -z "$missing" ]]; then
    replacement storage btrfs_subvolumes passed '@, @home, @log, @pkg, @snapshots, and @swap are mounted at their paths'
  else
    replacement storage btrfs_subvolumes failed "missing or misplaced:${missing}"
  fi
  if [[ -z "$bad_options" ]]; then
    replacement storage btrfs_compression passed 'every checked subvolume mounts with compress=zstd:1 and relatime, without compress-force or noatime'
  else
    replacement storage btrfs_compression failed "unexpected mount options on:${bad_options} (/home: $(findmnt -no OPTIONS /home 2> /dev/null))"
  fi

  if qgroup_output="$(btrfs qgroup show "$qgroup_path" 2>&1)"; then
    replacement storage btrfs_no_qgroups failed 'qgroups are enabled'
  elif grep -qi 'not enabled' <<< "$qgroup_output"; then
    replacement storage btrfs_no_qgroups passed 'quotas are not enabled'
  else
    replacement storage btrfs_no_qgroups failed "could not determine the quota state: ${qgroup_output}"
  fi
}

check_btrfs_fstab() {
  local bad_fstab
  local btrfs_lines
  local missing_subvol
  local vfat_lines
  local swap_lines

  bad_fstab="$(awk '!/^[[:space:]]*(#|$)/ && $3 != "swap" && $1 !~ /^UUID=/ { print $1 }' /etc/fstab)"
  btrfs_lines="$(awk '!/^[[:space:]]*(#|$)/ && $1 ~ /^UUID=/ && $3 == "btrfs"' /etc/fstab | wc -l)"
  missing_subvol="$(awk '!/^[[:space:]]*(#|$)/ && $3 == "btrfs" && $4 !~ /(^|,)subvol=/ { print $2 }' /etc/fstab)"
  vfat_lines="$(awk '!/^[[:space:]]*(#|$)/ && $1 ~ /^UUID=/ && $2 == "/boot" && $3 == "vfat"' /etc/fstab | wc -l)"
  swap_lines="$(awk -v path="$SWAPFILE_PATH" '!/^[[:space:]]*(#|$)/ && $1 == path && $3 == "swap"' /etc/fstab | wc -l)"
  if [[ -z "$bad_fstab" && -z "$missing_subvol" && "$btrfs_lines" -eq 6 && "$vfat_lines" -eq 1 && "$swap_lines" -eq 1 ]]; then
    replacement storage btrfs_fstab passed 'fstab lists six Btrfs subvolumes with subvol= and the ESP by UUID, plus one swapfile entry'
  else
    replacement storage btrfs_fstab failed "fstab: ${btrfs_lines} Btrfs, ${vfat_lines} ESP, ${swap_lines} swapfile entries, non-UUID: ${bad_fstab:-none}, without subvol=: ${missing_subvol:-none}"
  fi
}

check_snapper() {
  local config_file=/etc/snapper/configs/root
  local bad=''
  local value
  local key
  local baseline

  if snapper --csvout --no-headers list-configs 2> /dev/null | grep -q '^root,/$'; then
    replacement storage snapper_config passed 'one root configuration covers the @ subvolume mounted at /'
  else
    replacement storage snapper_config failed 'the Snapper root configuration for / is missing'
  fi

  for key in TIMELINE_CREATE:no NUMBER_CLEANUP:yes NUMBER_LIMIT:10 ALLOW_USERS: ALLOW_GROUPS:; do
    value="$(sed -n "s/^${key%%:*}=\"\(.*\)\"/\1/p" "$config_file" 2> /dev/null | head -n 1)"
    [[ "$value" == "${key#*:}" ]] || bad+=" ${key%%:*}=${value:-unset}"
  done
  if [[ -z "$bad" ]]; then
    replacement storage snapper_policy passed 'TIMELINE_CREATE=no, NUMBER_LIMIT=10, NUMBER_CLEANUP=yes, and no ALLOW_USERS or ALLOW_GROUPS'
  else
    replacement storage snapper_policy failed "unexpected Snapper settings:${bad}"
  fi

  if systemctl is-enabled --quiet snapper-cleanup.timer && ! systemctl is-enabled --quiet snapper-timeline.timer; then
    replacement storage snapper_timers passed 'snapper-cleanup.timer is enabled and snapper-timeline.timer is not'
  else
    replacement storage snapper_timers failed "snapper timers are not cleanup-only (cleanup: $(systemctl is-enabled snapper-cleanup.timer 2>&1), timeline: $(systemctl is-enabled snapper-timeline.timer 2>&1))"
  fi
  replacement_verdict storage snapper_snap_pac 'snap-pac is installed' 'snap-pac is not installed' pacman -Q snap-pac

  if [[ "$SNAPSHOT_BOOT" -eq 1 ]]; then
    baseline="$(grep -lF "$SNAPSHOT_BASELINE_DESCRIPTION" /.snapshots/*/info.xml 2> /dev/null | wc -l)"
  else
    baseline="$(snapper --csvout --no-headers -c root list --columns number,description 2> /dev/null | grep -cF "$SNAPSHOT_BASELINE_DESCRIPTION")"
  fi
  if [[ "$baseline" -ge 1 ]]; then
    replacement storage snapper_baseline passed "a '${SNAPSHOT_BASELINE_DESCRIPTION}' snapshot exists"
  else
    replacement storage snapper_baseline failed "no '${SNAPSHOT_BASELINE_DESCRIPTION}' snapshot"
  fi
}

# ---- swap group: Btrfs swapfile and hibernation configuration ---------------------------------

check_btrfs_swap() {
  local size
  local mode
  local attributes
  local cmdline
  local options
  local missing=''
  local token
  local resume_ok=1

  size="$(stat -c %s "$SWAPFILE_PATH" 2> /dev/null)"
  mode="$(stat -c %a "$SWAPFILE_PATH" 2> /dev/null)"
  attributes="$(lsattr -d "$SWAPFILE_PATH" 2> /dev/null | awk '{ print $1 }')"
  if [[ "$size" == "$EXPECTED_SWAP_BYTES" && "$mode" == '600' && "$attributes" == *C* ]]; then
    replacement swap btrfs_swap_file passed "4 GiB NOCOW ${SWAPFILE_PATH} with mode ${mode}"
  else
    replacement swap btrfs_swap_file failed "swapfile size ${size:-none}, mode ${mode:-none}, attributes ${attributes:-none}"
  fi
  if swapon --noheadings --show=NAME 2> /dev/null | grep -qx "$SWAPFILE_PATH"; then
    replacement swap btrfs_swap_active passed "${SWAPFILE_PATH} is active"
  else
    replacement swap btrfs_swap_active failed "${SWAPFILE_PATH} is not active"
  fi

  # The offset comes from btrfs inspect-internal map-swapfile -r (gather_facts, tool btrfs).
  cmdline="$(< /proc/cmdline)"
  for token in "resume=UUID=${ROOT_UUID}" "resume_offset=${SWAP_OFFSET}"; do
    [[ -n "$SWAP_OFFSET" && " ${cmdline} " == *" ${token} "* ]] || missing+=" ${token}"
  done
  if [[ "$STORAGE_VARIANT" != 'btrfs-limine' ]]; then
    if [[ -f "$DEFAULT_ENTRY_FILE" ]]; then
      options=" $(entry_options "$DEFAULT_ENTRY_FILE") "
      [[ -n "$SWAP_OFFSET" && "$options" == *" resume=UUID=${ROOT_UUID} "* && "$options" == *" resume_offset=${SWAP_OFFSET} "* ]] || resume_ok=0
    else
      resume_ok=0
    fi
    [[ "$resume_ok" -eq 1 ]] || missing+=' (default entry)'
  fi
  if [[ -z "$missing" ]]; then
    replacement swap btrfs_resume_match passed "resume UUID and offset ${SWAP_OFFSET} match the map-swapfile offset"
  else
    replacement swap btrfs_resume_match failed "missing or mismatched:${missing}"
  fi
}

# ---- boot group (btrfs-limine): Limine configuration, entries, and command line --------------

limine_config_path() {
  local candidate

  for candidate in "${LIMINE_CONFIG_CANDIDATES[@]}"; do
    [[ -f "$candidate" ]] && { printf '%s' "$candidate"; return 0; }
  done
  return 1
}

check_limine() {
  local config
  local path
  local missing=''
  local entries
  local token
  local line
  local cmdline_ok=0
  local cmdline
  local current_missing=''

  if [[ -d /sys/firmware/efi ]]; then replacement boot limine_uefi passed 'guest booted in UEFI mode'; else replacement boot limine_uefi failed '/sys/firmware/efi is absent'; fi

  if ! config="$(limine_config_path)"; then
    replacement boot limine_config failed 'no Limine configuration found on the ESP'
    return 0
  fi
  replacement boot limine_config passed "Limine configuration at ${config}"

  while read -r path; do
    path="${path%%#*}" # Limine v12 appends #<hash> to verified paths
    [[ -n "$path" && -f "/boot${path}" ]] || missing+=" ${path:-empty}"
  done < <(sed -n 's/^[[:space:]]*\(kernel_path\|module_path\):[[:space:]]*boot():\(.*\)$/\2/p' "$config")
  if [[ -z "$missing" ]]; then
    replacement boot limine_entry_files passed 'every kernel and initramfs referenced by the configuration exists on the ESP'
  else
    replacement boot limine_entry_files failed "referenced files missing: $(printf '%s\n' "$missing" | sed 's|^ */[0-9a-f]*/||; s/^\(.\{40\}\).*\(.\{12\}\)$/\1~\2/' | tr '\n' ' ')"
  fi

  entries="$(grep -cE '^[[:space:]]*///' "$config")"
  if [[ "$entries" -ge 1 ]]; then
    replacement boot limine_snapshot_entries passed "${entries} snapshot boot entries"
  else
    replacement boot limine_snapshot_entries failed 'no snapshot boot entries in the Limine configuration'
  fi

  if compgen -G '/boot/EFI/Linux/*.efi' > /dev/null; then replacement boot limine_no_uki failed 'a unified kernel image exists on the ESP'; else replacement boot limine_no_uki passed 'no unified kernel image'; fi

  # At least one entry must carry the full root, resume, and Btrfs subvolume options.
  while read -r line; do
    cmdline=" ${line} "
    for token in "root=UUID=${ROOT_UUID}" 'rootflags=subvol=@,compress=zstd:1,relatime' "resume=UUID=${ROOT_UUID}" "resume_offset=${SWAP_OFFSET}"; do
      [[ -n "$SWAP_OFFSET" && "$cmdline" == *" ${token} "* ]] || continue 2
    done
    cmdline_ok=1
    break
  done < <(sed -n 's/^[[:space:]]*cmdline:[[:space:]]*//p' "$config")
  if [[ "$cmdline_ok" -eq 1 ]]; then
    replacement boot limine_cmdline passed "an entry carries root, rootflags=subvol=@, resume, and resume_offset=${SWAP_OFFSET}"
  else
    replacement boot limine_cmdline failed 'no entry carries root, rootflags=subvol=@, resume, and the map-swapfile resume_offset'
  fi

  # The running system, which may be a snapshot entry, must still resume from the real swapfile.
  cmdline="$(< /proc/cmdline)"
  for token in "root=UUID=${ROOT_UUID}" "resume=UUID=${ROOT_UUID}" "resume_offset=${SWAP_OFFSET}"; do
    [[ -n "$SWAP_OFFSET" && " ${cmdline} " == *" ${token} "* ]] || current_missing+=" ${token}"
  done
  if [[ -z "$current_missing" ]]; then
    replacement boot limine_running_cmdline passed 'the running command line has root, resume, and the map-swapfile resume_offset'
  else
    replacement boot limine_running_cmdline failed "running command line misses:${current_missing}"
  fi
}

check_btrfs_disk_layout
check_btrfs_layout
check_btrfs_fstab
check_snapper
check_btrfs_swap
if [[ "$STORAGE_VARIANT" == 'btrfs-limine' ]]; then
  check_limine
fi
