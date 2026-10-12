#!/usr/bin/bash
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
  [[ "$(param bootloader)" == systemd-boot ]] || check_fail 'the plan does not select systemd-boot'
  timeout="$(param options.timeout)"
  [[ "$timeout" =~ ^[0-9]+$ ]] || check_fail 'the boot timeout is not valid'
  editor_line='editor yes'
  [[ "$(param options.editor)" != false ]] || editor_line='editor no'
  chroot_run bootctl install --esp-path=/boot
  printf 'default mirroros.conf\ntimeout %s\n%s\n' "$timeout" "$editor_line" | put_file 0644 /boot/loader/loader.conf
  printf 'title MirrorOS\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions %s\n' "$cmdline" \
    | put_file 0644 /boot/loader/entries/mirroros.conf
  if [[ "$(param options.fallback_entry)" == true ]]; then
    printf 'title MirrorOS (fallback initramfs)\nlinux /vmlinuz-linux\ninitrd /initramfs-linux-fallback.img\noptions %s\n' "$cmdline" \
      | put_file 0644 /boot/loader/entries/mirroros-fallback.conf
  fi
  grep -qxF -- "options ${cmdline}" "${TARGET}/boot/loader/entries/mirroros.conf" || check_fail 'the boot entry options differ from the plan'
  grep -qxF -- "timeout ${timeout}" "${TARGET}/boot/loader/loader.conf" || check_fail 'the boot timeout was not written'
  if [[ "$HIBERNATION" != true ]] && grep -rq 'resume' "${TARGET}/boot/loader"; then check_fail 'resume parameters are present without hibernation'; fi
  chroot_run bootctl is-installed --esp-path=/boot
  record_constant install_bootloader.loader_entry mirroros.conf
}

op_install_bootloader() {
  case "$STORAGE_OPTION" in
    ext4-systemd-boot) install_systemd_boot ;;
    *) check_fail "no boot loader function is defined for ${STORAGE_OPTION}" ;;
  esac
}
