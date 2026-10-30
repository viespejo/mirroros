#!/usr/bin/bash
# shellcheck disable=SC2034 # Run state is consumed by common.sh and apply.
# Boot loader operation of the installation engine for the systemd-boot options. The initramfs policy is the
# distribution's default mkinitcpio hooks without a unified kernel image.

# The planned kernel command line with the resolved values, left in CMDLINE (not printed, so that a failure
# ends the run in the main shell); a placeholder that stays unresolved is an error.
resolved_cmdline() {
  local cmdline
  cmdline="$(param kernel_cmdline)"
  cmdline="${cmdline//<root>/${ROOT_UUID}}"
  if [[ "$HIBERNATION" == true ]]; then cmdline="${cmdline//<resume_offset>/${RESUME_OFFSET}}"; fi
  [[ "$cmdline" != *'<'* && "$cmdline" != *'>'* ]] || check_fail 'the kernel command line holds an unresolved placeholder'
  [[ "$cmdline" == *zswap.enabled=0* ]] || check_fail 'the kernel command line lacks zswap.enabled=0'
  if [[ "$HIBERNATION" != true && "$cmdline" == *resume* ]]; then check_fail 'resume parameters are present without hibernation'; fi
  CMDLINE="$cmdline"
}

install_systemd_boot() {
  local cmdline timeout editor_line
  resolved_cmdline
  cmdline="$CMDLINE"
  # Engine constant: the Btrfs option boots the flat @ subvolume.
  [[ "$STORAGE_OPTION" != btrfs-rescue ]] || cmdline+=' rootflags=subvol=@'
  [[ "$(param bootloader)" == systemd-boot ]] || check_fail 'the plan does not select systemd-boot'
  timeout="$(param options.timeout)"
  [[ "$timeout" =~ ^[0-9]+$ ]] || check_fail 'the boot timeout is not valid'
  editor_line='editor yes'
  [[ "$(param options.editor)" != false ]] || editor_line='editor no'
  chroot_run bootctl install --esp-path=/boot --variables=no
  printf 'default mirroros.conf\ntimeout %s\n%s\n' "$timeout" "$editor_line" | put_file 0644 /boot/loader/loader.conf
  printf 'title MirrorOS\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions %s\n' "$cmdline" \
    | put_file 0644 /boot/loader/entries/mirroros.conf
  if [[ "$(param options.fallback_entry)" == true ]]; then
    # The distribution's preset may generate only the default image; the approved fallback must be explicit.
    printf 'ALL_kver="/boot/vmlinuz-linux"\nPRESETS=("default" "fallback")\ndefault_image="/boot/initramfs-linux.img"\nfallback_image="/boot/initramfs-linux-fallback.img"\nfallback_options="-S autodetect"\n' \
      | put_file 0644 /etc/mkinitcpio.d/linux.preset
    chroot_run mkinitcpio -p linux
    printf 'title MirrorOS (fallback initramfs)\nlinux /vmlinuz-linux\ninitrd /initramfs-linux-fallback.img\noptions %s\n' "$cmdline" \
      | put_file 0644 /boot/loader/entries/mirroros-fallback.conf
  fi
  grep -qxF -- "options ${cmdline}" "${TARGET}/boot/loader/entries/mirroros.conf" || check_fail 'the boot entry options differ from the plan'
  grep -qxF -- "timeout ${timeout}" "${TARGET}/boot/loader/loader.conf" || check_fail 'the boot timeout was not written'
  if [[ "$HIBERNATION" != true ]] && grep -rq 'resume' "${TARGET}/boot/loader"; then check_fail 'resume parameters are present without hibernation'; fi
  chroot_run bootctl is-installed --esp-path=/boot
  record_constant install_bootloader.loader_entry mirroros.conf
}

# Unlike run(), this invokes a sourced function rather than exec of an external command.
run_uefi() {
  LAST_ARGV=("$@")
  printf '$ %s\n' "$*" >> "$ENGINE_LOG"
  "$@" < /dev/null >> "$ENGINE_LOG" 2>&1 3>&- 4>&- || {
    LAST_STATUS=$?
    stage_fail
  }
}

op_register_uefi_boot_entry() {
  local guid number loader path
  loader="$(param bootloader)"
  uefi_select_loader "$loader" || check_fail 'unsupported UEFI loader'
  path="${UEFI_LOADER//\\//}"
  [[ -s "${TARGET}/boot${path}" && -s "${TARGET}/boot/EFI/BOOT/BOOTX64.EFI" ]] \
    || check_fail 'the selected EFI loader or fallback is missing'
  capture guid blkid --output value --match-tag PARTUUID "$ESP_PART"
  capture number lsblk -dnro PARTN "$ESP_PART"
  uefi_guid_valid "$guid" && [[ "$number" =~ ^[1-9][0-9]*$ ]] || check_fail 'invalid ESP partition identity'
  if [[ "$TARGET_MODE" == replace_installation ]]; then
    [[ "${guid,,}" == "${PARAM[wipe_partition_signatures.esp.partuuid]}" \
      && "$number" == "${PARAM[wipe_partition_signatures.esp.partition_number]}" ]] || check_fail 'the reused ESP identity changed'
  fi
  run_uefi uefi_ensure_first "$DISK_PATH" "$number" "$guid" "$loader"
  record_constant register_uefi_boot_entry.esp_partuuid "$guid"
  record_constant register_uefi_boot_entry.loader "$UEFI_LOADER"
  record_constant register_uefi_boot_entry.label "$UEFI_LABEL"
  record_constant register_uefi_boot_entry.boot_order "$UEFI_ORDER"
  copy_boot_first_code >> "$ENGINE_LOG" 2>&1 || check_fail 'boot-first delivery failed'
  record_constant register_uefi_boot_entry.command /usr/local/bin/mirroros-boot-first
  verify_untouched_partitions
}

op_install_bootloader() {
  case "$STORAGE_OPTION" in
    ext4-systemd-boot | btrfs-rescue) install_systemd_boot ;;
    btrfs-limine) op_install_limine_bootloader ;;
    *) check_fail "no boot loader function is defined for ${STORAGE_OPTION}" ;;
  esac
}
