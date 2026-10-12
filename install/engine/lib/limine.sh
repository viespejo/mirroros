#!/usr/bin/bash
# shellcheck disable=SC2034 # LIMINE_NORMAL and LIMINE_SNAPSHOTS are read by the checks of this file.
# Limine operations of the installation engine (contracts/installation-engine.md, "Limine (btrfs-limine)").
# The responsibilities are split over three operations and no Limine or snapshot tool runs before the package
# transaction of install_limine_snapshot_tools installs it:
#   install_bootloader               writes only /etc/default/limine and verifies that file;
#   install_limine_snapshot_tools    verifies the embedded packages, writes the initramfs hooks drop-in, installs
#                                    the packages, and verifies what their transaction produced;
#   sync_limine_snapshot_entries     runs limine-snapper-sync after the baseline and verifies the snapshot entries.
# The engine never runs limine-update, never deploys the EFI binary, and never writes limine.conf itself.

# Engine constants.
readonly LIMINE_DEFAULTS=/etc/default/limine
readonly LIMINE_CONFIG=/boot/limine.conf
readonly LIMINE_PACKAGE_STAGING=/var/tmp/mirroros-packages
readonly LIMINE_HOOKS_DROPIN=/etc/mkinitcpio.conf.d/10-mirroros-limine.conf
readonly LIMINE_HOOKS='HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems sd-btrfs-overlayfs fsck)'

# The prebuilt packages travel inside the embedded code of the running artifact.
LIMINE_PACKAGES_DIR="${CODE_ROOT}/packages"

LIMINE_TIMEOUT=''
LIMINE_NORMAL=()
LIMINE_SNAPSHOTS=()

op_install_limine_bootloader() {
  [[ "$(param bootloader)" == limine ]] || check_fail 'the plan does not select Limine'
  LIMINE_TIMEOUT="$(param options.timeout)"
  [[ "$LIMINE_TIMEOUT" =~ ^[0-9]+$ ]] || check_fail 'the boot timeout is not valid'
  resolved_cmdline
  # The file is read by a shell: only plain kernel parameters are accepted.
  [[ "$CMDLINE" =~ ^[A-Za-z0-9_.,:=@/+\ -]+$ ]] || check_fail 'the kernel command line holds a character the Limine defaults file cannot carry'
  printf 'ESP_PATH="/boot"\nSKIP_UEFI=yes\nKERNEL_CMDLINE[default]="%s rootflags=subvol=@"\n' "$CMDLINE" | put_file 0644 "$LIMINE_DEFAULTS"
  grep -qxF -- 'ESP_PATH="/boot"' "${TARGET}${LIMINE_DEFAULTS}" || check_fail 'ESP_PATH was not written'
  grep -qxF -- 'SKIP_UEFI=yes' "${TARGET}${LIMINE_DEFAULTS}" || check_fail 'SKIP_UEFI was not written'
  grep -qxF -- "KERNEL_CMDLINE[default]=\"${CMDLINE} rootflags=subvol=@\"" "${TARGET}${LIMINE_DEFAULTS}" \
    || check_fail 'the Limine kernel command line differs from the plan'
  record_constant install_bootloader.limine_defaults 'ESP_PATH=/boot SKIP_UEFI=yes KERNEL_CMDLINE[default]=<plan kernel_cmdline> rootflags=subvol=@'
  # The pinned tools offer no supported way to apply these two options (contract, "Mapping of bootloader_options").
  record_constant install_bootloader.editor not_applicable_to_limine
  record_constant install_bootloader.fallback_entry not_applicable_to_limine
}

# Splits the Limine configuration into the normal entries (and global options) and the snapshot entries, which
# the snapshot tool writes below the "//Snapshots" line.
limine_read_config() {
  local file="${TARGET}${LIMINE_CONFIG}" line snapshots=0
  LIMINE_NORMAL=()
  LIMINE_SNAPSHOTS=()
  [[ -s "$file" ]] || check_fail 'the Limine configuration is missing or empty'
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*//Snapshots[[:space:]]*$ ]]; then
      snapshots=1
      continue
    fi
    if (( snapshots )); then LIMINE_SNAPSHOTS+=("$line"); else LIMINE_NORMAL+=("$line"); fi
  done < "$file"
}

# Every kernel and initramfs that the given configuration lines reference (boot():/<path>) exists on the ESP.
limine_check_referenced_files() {
  local line reference found=0
  for line in "$@"; do
    if [[ "$line" =~ ^[[:space:]]*(module_)?path:[[:space:]]*boot\(\):(/[^#[:space:]]+) ]]; then
      reference="${BASH_REMATCH[2]}"
      [[ "$reference" != *..* ]] || check_fail 'a Limine entry references a path with ..'
      [[ -s "${TARGET}/boot${reference}" ]] || check_fail "a Limine entry references ${reference}, which is not on the ESP"
      found=$((found + 1))
    fi
  done
  (( found >= 2 )) || check_fail 'a Limine entry does not reference both a kernel and an initramfs'
}

limine_has_parameter() {
  local wanted="$1" token
  for token in $LIMINE_CMDLINE_TOKENS; do
    [[ "$token" == "$wanted" ]] && return 0
  done
  return 1
}

# The normal entry carries the planned parameters; resume parameters exist exactly when hibernation is enabled.
limine_check_normal_entry() {
  local line
  LIMINE_CMDLINE_TOKENS=''
  for line in "${LIMINE_NORMAL[@]}"; do
    if [[ "$line" =~ ^[[:space:]]*cmdline:[[:space:]]*(.*)$ ]]; then
      LIMINE_CMDLINE_TOKENS="${BASH_REMATCH[1]}"
      break
    fi
  done
  [[ -n "$LIMINE_CMDLINE_TOKENS" ]] || check_fail 'the Limine configuration has no normal entry with a command line'
  limine_has_parameter "root=UUID=${ROOT_UUID}" || check_fail 'the Limine entry lacks the root UUID'
  limine_has_parameter 'rootflags=subvol=@' || check_fail 'the Limine entry lacks rootflags=subvol=@'
  limine_has_parameter 'zswap.enabled=0' || check_fail 'the Limine entry lacks zswap.enabled=0'
  if [[ "$HIBERNATION" == true ]]; then
    limine_has_parameter "resume=UUID=${ROOT_UUID}" || check_fail 'the Limine entry lacks the resume device'
    limine_has_parameter "resume_offset=${RESUME_OFFSET}" || check_fail 'the Limine entry lacks the resume offset'
  elif [[ " ${LIMINE_CMDLINE_TOKENS} " == *' resume'* ]]; then
    check_fail 'the Limine entry holds resume parameters without hibernation'
  fi
}

op_install_limine_snapshot_tools() {
  local result=() count index name file version expected actual staged=() entry joined
  mapfile -d '' -t result < <(node "${SCRIPT_DIR}/load-plan.mjs" limine-manifest --directory "$LIMINE_PACKAGES_DIR" < /dev/null 4>&- || true)
  if [[ "${result[0]:-}" != ok ]]; then
    asset_fail "${result[1]:-The Limine package manifest could not be verified.}"
  fi
  count="${result[1]}"
  install -d -m 0755 -- "${TARGET}${LIMINE_PACKAGE_STAGING}"
  for (( index = 0; index < count; index++ )); do
    name="${result[2 + index * 4]}"
    file="${result[3 + index * 4]}"
    version="${result[4 + index * 4]}"
    expected="${result[5 + index * 4]}"
    # The copy that pacman installs is the one whose hash is checked.
    cp -- "${LIMINE_PACKAGES_DIR}/${file}" "${TARGET}${LIMINE_PACKAGE_STAGING}/${file}"
    actual="$(sha256sum -- "${TARGET}${LIMINE_PACKAGE_STAGING}/${file}")" || check_fail "the staged package ${name} cannot be hashed"
    if [[ "${actual%% *}" != "$expected" ]]; then
      rm -f -- "${TARGET}${LIMINE_PACKAGE_STAGING}/${file}"
      asset_fail "The Limine package ${name} does not match its recorded SHA-256."
    fi
    staged+=("${LIMINE_PACKAGE_STAGING}/${file}")
    record_constant "install_limine_snapshot_tools.package.${name}" "${version} ${expected}"
  done
  printf '%s\n' "$LIMINE_HOOKS" | put_file 0644 "$LIMINE_HOOKS_DROPIN"
  record_constant install_limine_snapshot_tools.hooks "$LIMINE_HOOKS"
  # The package transaction regenerates the initramfs, deploys the EFI binary to the fallback path, and writes
  # the normal entries. snap-pac stays installed but takes no snapshot during the installation.
  chroot_run env SNAP_PAC_SKIP=y pacman -U --noconfirm "${staged[@]}"
  run rm -rf -- "${TARGET}${LIMINE_PACKAGE_STAGING}"

  [[ -s "${TARGET}/boot/EFI/BOOT/BOOTX64.EFI" ]] || check_fail 'the Limine EFI binary is not on the fallback path'
  if [[ -d "${TARGET}/boot/EFI/Linux" ]]; then
    for entry in "${TARGET}"/boot/EFI/Linux/*.efi; do
      [[ ! -e "$entry" ]] || check_fail 'a unified kernel image exists on the ESP'
    done
  fi
  limine_read_config
  limine_check_normal_entry
  limine_check_referenced_files "${LIMINE_NORMAL[@]}"
  joined="$(printf '%s\n' "${LIMINE_NORMAL[@]}")"
  grep -qE -- "^timeout:[[:space:]]*${LIMINE_TIMEOUT}\$" <<< "$joined" || check_fail 'the Limine timeout differs from the plan'
}

op_sync_limine_snapshot_entries() {
  local listing line number='' pattern joined
  chroot_run limine-snapper-sync
  capture listing arch-chroot "$TARGET" snapper --no-dbus -c root list
  while IFS= read -r line; do
    if [[ "$line" == *"$BASELINE_DESCRIPTION"* ]]; then
      # The number is the leading digits of the row; the column separator is a box-drawing character or a pipe.
      number="${line#"${line%%[![:space:]]*}"}"
      number="${number%%[!0-9]*}"
    fi
  done <<< "$listing"
  [[ "$number" =~ ^[0-9]+$ ]] || check_fail 'the baseline snapshot number cannot be read'
  limine_read_config
  pattern="rootflags=subvol=/@snapshots/${number}/snapshot"
  joined="$(printf '%s\n' "${LIMINE_SNAPSHOTS[@]}")"
  if ! grep -qF -- "$pattern" <<< "$joined"; then
    { printf 'baseline snapshot %s; Limine snapshot lines:\n' "$number"; printf '%s\n' "${LIMINE_SNAPSHOTS[@]}"; } >> "$ENGINE_LOG"
    check_fail 'no Limine snapshot entry points to the baseline snapshot'
  fi
  limine_check_referenced_files "${LIMINE_SNAPSHOTS[@]}"
  record_constant sync_limine_snapshot_entries.baseline_snapshot "$number"
}
