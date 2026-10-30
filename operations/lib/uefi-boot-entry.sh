#!/usr/bin/bash
# Shared live-installer and installed-command UEFI operations (ADR 0022).

uefi_error() { printf 'MirrorOS UEFI: %s\n' "$*" >&2; }

uefi_guid_valid() {
  [[ "$1" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]
}

uefi_select_loader() {
  case "$1" in
    limine) UEFI_LABEL='Limine MirrorOS'; UEFI_LOADER='\EFI\BOOT\BOOTX64.EFI' ;;
    systemd-boot) UEFI_LABEL=MirrorOS; UEFI_LOADER='\EFI\systemd\systemd-bootx64.efi' ;;
    *) uefi_error 'unsupported bootloader'; return 2 ;;
  esac
}

# Snapshot arrays include every entry, including firmware and non-GPT device paths.
uefi_read_entries() {
  local listing line id guid path device_path order_count=0 hd_re file_re
  listing=$(efibootmgr -v) || return 5
  UEFI_ORDER=''; UEFI_IDS=(); UEFI_GUIDS=(); UEFI_PATHS=()
  hd_re='HD\([0-9]+,GPT,([[:xdigit:]-]+),[^)]*\)'
  file_re='File\(([^)]*)\)'
  while IFS= read -r line; do
    if [[ "$line" == BootOrder:* ]]; then
      order_count=$((order_count + 1))
      UEFI_ORDER=${line#BootOrder:}; UEFI_ORDER=${UEFI_ORDER//[[:space:]]/}; UEFI_ORDER=${UEFI_ORDER^^}
      [[ -z "$UEFI_ORDER" || "$UEFI_ORDER" =~ ^[[:xdigit:]]{4}(,[[:xdigit:]]{4})*$ ]] || {
        uefi_error 'invalid BootOrder'; return 2;
      }
    elif [[ "$line" =~ ^Boot([[:xdigit:]]{4})(\*|[[:space:]]) ]]; then
      id=${BASH_REMATCH[1]^^}; guid=''; path=''
      [[ " ${UEFI_IDS[*]} " != *" $id "* ]] || { uefi_error 'duplicate boot number'; return 2; }
      # efibootmgr separates the description from the device path with a tab.
      # Never interpret a PARTUUID-looking description as a cleanup target.
      device_path=''
      if [[ "$line" == *$'\t'* ]]; then device_path=${line#*$'\t'}; fi
      if [[ "$device_path" =~ $hd_re ]]; then
        guid=${BASH_REMATCH[1],,}
        uefi_guid_valid "$guid" || { uefi_error 'invalid GPT device path'; return 2; }
        if [[ "$device_path" =~ $file_re ]]; then
          path=${BASH_REMATCH[1]//\//\\}; path=${path,,}
        fi
      fi
      UEFI_IDS+=("$id"); UEFI_GUIDS+=("$guid"); UEFI_PATHS+=("$path")
    fi
  done <<< "$listing"
  (( order_count <= 1 )) || { uefi_error 'ambiguous BootOrder'; return 2; }
  local -a order_ids=()
  local seen=' '
  IFS=, read -r -a order_ids <<< "$UEFI_ORDER"
  for id in "${order_ids[@]}"; do
    [[ "$seen" != *" $id "* && " ${UEFI_IDS[*]} " == *" $id "* ]] || {
      uefi_error 'BootOrder contains duplicate or missing entries'; return 2;
    }
    seen+="$id "
  done
}

# Leaves an empty UEFI_MATCH when absent; duplicates fail before any mutation.
uefi_find_entry() {
  local guid=${1,,} path=${2//\//\\} index
  path=${path,,}; UEFI_MATCH=''
  uefi_guid_valid "$guid" || { uefi_error 'invalid ESP PARTUUID'; return 2; }
  for index in "${!UEFI_IDS[@]}"; do
    if [[ "${UEFI_GUIDS[index]}" == "$guid" && "${UEFI_PATHS[index]}" == "$path" ]]; then
      [[ -z "$UEFI_MATCH" ]] || { uefi_error 'duplicate matching entries; investigate manually'; return 2; }
      UEFI_MATCH=${UEFI_IDS[index]}
    fi
  done
}

uefi_require_preserved() {
  local id
  for id in "$@"; do
    [[ " ${UEFI_IDS[*]} " == *" $id "* ]] || { uefi_error 'a pre-existing entry disappeared'; return 6; }
  done
}

# Arguments: disk node, ESP partition number, ESP PARTUUID, limine|systemd-boot.
# The caller must validate the target and privileges before invoking this function.
uefi_ensure_first() {
  local disk=$1 part=$2 guid=$3 loader=$4 before desired id selected
  local -a previous=() order_ids=()
  [[ "$disk" == /dev/* && "$part" =~ ^[1-9][0-9]*$ ]] || return 2
  uefi_select_loader "$loader" || return $?
  uefi_read_entries || return $?
  uefi_find_entry "$guid" "$UEFI_LOADER" || return $?
  before=$UEFI_ORDER; previous=("${UEFI_IDS[@]}")
  printf 'BootOrder before: %s\n' "${before:-<empty>}"
  if [[ -z "$UEFI_MATCH" ]]; then
    efibootmgr --create-only --disk "$disk" --part "$part" --label "$UEFI_LABEL" --loader "$UEFI_LOADER" >/dev/null || return 5
    uefi_read_entries || return $?
    uefi_find_entry "$guid" "$UEFI_LOADER" || return $?
    [[ -n "$UEFI_MATCH" && "$UEFI_ORDER" == "$before" ]] || {
      uefi_error 'creation did not preserve BootOrder or produce one entry'; return 6;
    }
    uefi_require_preserved "${previous[@]}" || return $?
  fi
  selected=$UEFI_MATCH; desired=$selected
  IFS=, read -r -a order_ids <<< "$before"
  for id in "${order_ids[@]}"; do
    [[ "$id" == "$selected" ]] || desired+=",$id"
  done
  if [[ "$desired" != "$UEFI_ORDER" ]]; then
    efibootmgr --bootorder "$desired" >/dev/null || return 5
  fi
  uefi_read_entries || return $?
  uefi_find_entry "$guid" "$UEFI_LOADER" || return $?
  [[ "$UEFI_MATCH" == "$selected" && "$UEFI_ORDER" == "$desired" ]] || {
    uefi_error 'entry or BootOrder postcondition failed'; return 6;
  }
  uefi_require_preserved "${previous[@]}" || return $?
  printf 'BootOrder after: %s\n' "$UEFI_ORDER"
}

# Whole-disk engine only: arguments are the recorded pre-wipe GPT PARTUUID set.
uefi_remove_partuuids() {
  local guid index id expected_order='' before
  local -a remove=() keep=() order_ids=()
  for guid in "$@"; do
    uefi_guid_valid "$guid" || { uefi_error 'invalid pre-wipe PARTUUID'; return 2; }
  done
  uefi_read_entries || return $?
  before=$UEFI_ORDER
  for index in "${!UEFI_IDS[@]}"; do
    id=${UEFI_IDS[index]}
    for guid in "$@"; do
      if [[ "${UEFI_GUIDS[index]}" == "${guid,,}" ]]; then remove+=("$id"); break; fi
    done
    [[ " ${remove[*]} " == *" $id "* ]] || keep+=("$id")
  done
  IFS=, read -r -a order_ids <<< "$before"
  for id in "${order_ids[@]}"; do
    if [[ " ${remove[*]} " != *" $id "* ]]; then expected_order+="${expected_order:+,}$id"; fi
  done
  for id in "${remove[@]}"; do
    efibootmgr --bootnum "$id" --delete-bootnum >/dev/null || return 5
  done
  uefi_read_entries || return $?
  uefi_require_preserved "${keep[@]}" || return $?
  for id in "${remove[@]}"; do
    [[ " ${UEFI_IDS[*]} " != *" $id "* ]] || { uefi_error 'stale entry was not removed'; return 6; }
  done
  [[ "$UEFI_ORDER" == "$expected_order" ]] || { uefi_error 'cleanup changed unrelated ordering'; return 6; }
}

# Check only native kernel command-line records, never comments or title strings.
uefi_config_root_matches() {
  local file=$1 kind=$2 uuid=$3
  awk -v kind="$kind" -v wanted="root=UUID=$uuid" '
    (kind == "limine" && $1 == "cmdline:") || (kind == "systemd-boot" && $1 == "options") {
      for (i = 2; i <= NF; i++) {
        if ($i ~ /^#/) break
        if ($i ~ /^root=/) { found++; if ($i != wanted) bad = 1 }
      }
    }
    END { exit !(found && !bad) }
  ' "$file"
}

# Resolve the running root and its actual /boot mount without mounting or writing.
# Explicit file paths allow isolated contract tests, not command-line target overrides.
uefi_identify_running() {
  local boot=$1 fstab=$2 root esp root_uuid esp_uuid root_fs disk esp_disk count uuid
  local linux_type=0fc63daf-8483-4772-8e79-3d69d8477de4 esp_type=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
  root=$(findmnt -nro SOURCE --target /) || return 2
  root=${root%%\[*}
  esp=$(findmnt -nro SOURCE --mountpoint "$boot") || return 2
  [[ "$root" == /dev/* && "$esp" == /dev/* && "$root" != "$esp" ]] || return 2
  root=$(readlink -f -- "$root") || return 2
  esp=$(readlink -f -- "$esp") || return 2
  [[ $(lsblk -dnro TYPE "$root") == part && $(lsblk -dnro TYPE "$esp") == part ]] || return 2
  [[ $(lsblk -dnro LABEL "$root") == mirroros ]] || return 2
  [[ $(lsblk -dnro PARTTYPE "$root" | tr '[:upper:]' '[:lower:]') == "$linux_type" ]] || return 2
  [[ $(lsblk -dnro PARTTYPE "$esp" | tr '[:upper:]' '[:lower:]') == "$esp_type" ]] || return 2
  root_fs=$(lsblk -dnro FSTYPE "$root") || return 2
  [[ "$root_fs" == ext4 || "$root_fs" == btrfs ]] || return 2
  [[ $(findmnt -nro FSTYPE --mountpoint "$boot") == vfat ]] || return 2
  disk=$(lsblk -dnpro PKNAME "$root") || return 2
  esp_disk=$(lsblk -dnpro PKNAME "$esp") || return 2
  [[ "$disk" == /dev/* && "$disk" == "$esp_disk" && $(lsblk -dnro PTTYPE "$disk") == gpt ]] || return 2
  root_uuid=$(lsblk -dnro UUID "$root") || return 2
  esp_uuid=$(lsblk -dnro UUID "$esp") || return 2
  uefi_guid_valid "$root_uuid" || return 2
  [[ "$esp_uuid" =~ ^[[:xdigit:]]{4}-[[:xdigit:]]{4}$ && -r "$fstab" ]] || return 2
  # Each volume ID must be unique on the disk, and fstab must bind both mounts.
  for uuid in "$root_uuid" "$esp_uuid"; do
    count=$(lsblk -nrpo UUID "$disk" | grep -cxF -- "$uuid") || return 2
    [[ "$count" == 1 ]] || return 2
  done
  awk -v root="UUID=$root_uuid" -v esp="UUID=$esp_uuid" '
    $1 !~ /^#/ && $2 == "/" { r++; if ($1 != root) bad = 1 }
    $1 !~ /^#/ && $2 == "/boot" { e++; if ($1 != esp) bad = 1 }
    END { exit !(r == 1 && e == 1 && !bad) }
  ' "$fstab" || return 2
  UEFI_RUNNING_LOADER=''
  if [[ -e "$boot/limine.conf" ]]; then
    [[ "$root_fs" == btrfs ]] && uefi_config_root_matches "$boot/limine.conf" limine "$root_uuid" || return 2
    UEFI_RUNNING_LOADER=limine
  fi
  if [[ -e "$boot/loader/entries/mirroros.conf" ]]; then
    [[ -z "$UEFI_RUNNING_LOADER" ]] || return 2
    uefi_config_root_matches "$boot/loader/entries/mirroros.conf" systemd-boot "$root_uuid" || return 2
    UEFI_RUNNING_LOADER=systemd-boot
  fi
  [[ -n "$UEFI_RUNNING_LOADER" ]] || return 2
  uefi_select_loader "$UEFI_RUNNING_LOADER" || return $?
  local loader_file=${UEFI_LOADER//\\//}
  [[ -s "$boot$loader_file" ]] || return 2
  # shellcheck disable=SC2034 # Output consumed by operations/boot-first and the live caller.
  UEFI_RUNNING_DISK=$disk
  UEFI_RUNNING_PART=$(lsblk -dnro PARTN "$esp") || return 2
  UEFI_RUNNING_GUID=$(lsblk -dnro PARTUUID "$esp") || return 2
  [[ "$UEFI_RUNNING_PART" =~ ^[1-9][0-9]*$ ]] && uefi_guid_valid "$UEFI_RUNNING_GUID"
}
