#!/usr/bin/bash
# Native, read-only observations of the mounted target. Every function only reads: file reads, stat, findmnt,
# blkid -p, pacman -Q, systemctl is-enabled, lsinitcpio listings, filefrag, btrfs map-swapfile, lsattr,
# efibootmgr -v, sfdisk --dump, lsblk listings, and readlink. The
# comparison with the plan belongs to evaluate.mjs. Paths are relative to the target root and start with "/".

readonly MAX_TEXT_BYTES=262144
ROOT_FILESYSTEM_TYPE=''

# A regular file or directory of the target, never a symbolic link (an absolute link would resolve in the live system).
target_file() {
  [[ -f "${TARGET_ROOT}$1" && ! -L "${TARGET_ROOT}$1" ]]
}

observe_stat() {
  local info
  info="$(stat -c '%F|%a|%s' -- "${TARGET_ROOT}$1" 2> /dev/null)" || return 0
  obs "stat:$1" "$info"
}

observe_text() {
  local content
  target_file "$1" || return 0
  content="$(head -c "$MAX_TEXT_BYTES" -- "${TARGET_ROOT}$1" 2> /dev/null)" || return 0
  obs "text:$1" "$content"
}

observe_sha256() {
  local sum
  target_file "$1" || return 0
  sum="$(sha256sum -- "${TARGET_ROOT}$1" 2> /dev/null)" || return 0
  obs "sha256:$1" "${sum%% *}"
}

observe_list() {
  local directory="${TARGET_ROOT}$1" entry names=''
  [[ -d "$directory" && ! -L "$directory" ]] || return 0
  shopt -s nullglob dotglob
  for entry in "$directory"/*; do names+="${entry##*/}"$'\n'; done
  shopt -u nullglob dotglob
  obs "list:$1" "$names"
}

# The source device of the filesystem mounted at a path of the target, from the raw findmnt lines.
mount_source() {
  local raw="$1" wanted="$2" target source fstype _options decoded found=''
  while read -r target source fstype _options; do
    decoded="$(printf '%b' "$target")"
    if [[ "$decoded" == "$wanted" ]]; then found="${source%%\[*}"; fi
  done <<< "$raw"
  printf '%s' "$found"
}

mount_fstype() {
  local raw="$1" wanted="$2" target source fstype _options decoded found=''
  while read -r target source fstype _options; do
    decoded="$(printf '%b' "$target")"
    if [[ "$decoded" == "$wanted" ]]; then found="$fstype"; fi
  done <<< "$raw"
  printf '%s' "$found"
}

observe_filesystem_uuid() {
  local label="$1" device="$2" uuid
  [[ -n "$device" ]] || return 0
  uuid="$(blkid -p -o value -s UUID -- "$device" 2> /dev/null)" || return 0
  obs "uuid:${label}" "$uuid"
}

observe_mounts() {
  local raw
  obs target_root "$TARGET_ROOT"
  raw="$(findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS -R -- "$TARGET_ROOT" 2> /dev/null)" || return 0
  obs mounts "$raw"
  ROOT_FILESYSTEM_TYPE="$(mount_fstype "$raw" "$TARGET_ROOT")"
  observe_filesystem_uuid / "$(mount_source "$raw" "$TARGET_ROOT")"
  local esp partuuid
  esp="$(mount_source "$raw" "${TARGET_ROOT}/boot")"
  observe_filesystem_uuid /boot "$esp"
  if [[ -n "$esp" ]] && partuuid="$(blkid -p -o value -s PARTUUID -- "$esp" 2> /dev/null)"; then
    obs 'partuuid:/boot' "$partuuid"
  fi
}

observe_packages() {
  local listing
  listing="$(pacman --root "$TARGET_ROOT" --dbpath "${TARGET_ROOT}/var/lib/pacman" -Q 2> /dev/null)" || return 0
  obs packages "$listing"
}

observe_enabled() {
  local state
  state="$(systemctl --root="$TARGET_ROOT" is-enabled "$1" 2> /dev/null)" || true
  obs "enabled:$1" "$state"
}

# The microcode images of the early archive of one initramfs, one per line (possibly none).
observe_microcode() {
  local image="$1" listing filtered
  target_file "$image" || return 0
  listing="$(lsinitcpio --early --nocolor -l "${TARGET_ROOT}${image}" 2> /dev/null)" \
    || listing="$(lsinitcpio --nocolor -l "${TARGET_ROOT}${image}" 2> /dev/null)" || return 0
  filtered="$(grep -E '^(\./)?kernel/x86/microcode/' <<< "$listing" || true)"
  obs "microcode:${image}" "$filtered"
}

# The resume offset, computed again from the swapfile itself, and its attributes.
observe_swapfile() {
  local relative="$1" offset extents attributes
  target_file "$relative" || return 0
  if [[ "$ROOT_FILESYSTEM_TYPE" == btrfs ]]; then
    offset="$(btrfs inspect-internal map-swapfile -r "${TARGET_ROOT}${relative}" 2> /dev/null)" || offset=unavailable
  else
    extents="$(filefrag -v "${TARGET_ROOT}${relative}" 2> /dev/null)" || extents=''
    offset="$(awk '$1 == "0:" { sub(/\.\./, "", $4); print $4; exit }' <<< "$extents")"
  fi
  obs "offset:${relative}" "${offset:-unavailable}"
  attributes="$(lsattr -d -- "${TARGET_ROOT}${relative}" 2> /dev/null)" || return 0
  obs "attrs:${relative}" "${attributes%% *}"
}

# The kernel and initramfs files that the Limine configuration references (boot():/<path>) are looked up on the ESP.
observe_limine_references() {
  local line
  target_file /boot/limine.conf || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*(module_)?path:[[:space:]]*boot\(\):(/[^#[:space:]]+) ]]; then
      [[ "${BASH_REMATCH[2]}" == *..* ]] || observe_stat "/boot${BASH_REMATCH[2]}"
    fi
  done < "${TARGET_ROOT}/boot/limine.conf"
}

# The fixed allowlisted destinations of the two configuration drop-ins (install/plan/configuration-assets.mjs).
readonly ZRAM_DESTINATION=/usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf
readonly SYSCTL_DESTINATION=/usr/lib/sysctl.d/60-mirroros-memory.conf

observe_coexistence() {
  local listing disk dump storage link path
  if listing="$(efibootmgr -v 2> /dev/null)"; then obs uefi_entries "$listing"; fi
  if [[ -L "${TARGET_ROOT}/usr/local/bin/mirroros-boot-first" ]] \
    && link="$(readlink -- "${TARGET_ROOT}/usr/local/bin/mirroros-boot-first" 2> /dev/null)"; then
    obs 'link:/usr/local/bin/mirroros-boot-first' "$link"
  fi
  for path in /usr/local/lib/mirroros/operations/boot-first /usr/local/lib/mirroros/operations/lib/uefi-boot-entry.sh; do
    if target_file "$path"; then observe_stat "$path"; fi
  done
  disk="$(node -e 'const p=JSON.parse(require("fs").readFileSync(process.argv[1])); if(p.target_mode==="replace_installation") process.stdout.write(p.target.disk.path)' "$PLAN_FILE")" || return 0
  [[ -n "$disk" ]] || return 0
  if dump="$(sfdisk --dump "$disk" 2> /dev/null)"; then obs partition_table "$dump"; fi
  if storage="$(lsblk --json --tree --bytes --output PATH,KNAME,TYPE,SIZE,PTTYPE,PTUUID,FSTYPE,LABEL,UUID,PARTUUID,PARTTYPE,PARTN,START,PARTLABEL,LOG-SEC,MOUNTPOINTS 2> /dev/null)"; then
    obs storage "$storage"
  fi
}

collect_observations() {
  local path
  observe_mounts
  observe_coexistence
  observe_packages
  for path in /boot/vmlinuz-linux /boot/initramfs-linux.img /boot/initramfs-linux-fallback.img \
    /boot/EFI/systemd/systemd-bootx64.efi /boot/EFI/BOOT/BOOTX64.EFI /swapfile /swap/swapfile; do
    observe_stat "$path"
  done
  for path in /etc/fstab /etc/hostname /boot/loader/loader.conf /boot/loader/entries/mirroros.conf \
    /boot/loader/entries/mirroros-fallback.conf /etc/default/limine /boot/limine.conf "$ZRAM_DESTINATION" "$SYSCTL_DESTINATION"; do
    observe_text "$path"
  done
  observe_sha256 "$ZRAM_DESTINATION"
  observe_sha256 "$SYSCTL_DESTINATION"
  observe_list /etc/NetworkManager/system-connections
  observe_list /boot/EFI/Linux
  observe_limine_references
  observe_enabled NetworkManager.service
  observe_microcode /boot/initramfs-linux.img
  observe_microcode /boot/initramfs-linux-fallback.img
  observe_swapfile /swapfile
  observe_swapfile /swap/swapfile
}
