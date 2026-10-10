# shellcheck shell=bash
# Read-only live boot-mode check.

boot_mode_form() {
  local bits
  if [[ ! -r /sys/firmware/efi/fw_platform_size ]]; then
    printf 'UEFI boot was not detected. Restart the VM in UEFI mode.\n' >&2
    return 2
  fi
  IFS= read -r bits < /sys/firmware/efi/fw_platform_size || return 2
  if [[ $bits != 64 ]]; then
    printf 'MirrorOS requires 64-bit UEFI. Restart with supported UEFI firmware.\n' >&2
    return 2
  fi
  gum style --padding "$PADDING" 'Boot mode: UEFI (64-bit)'
  gum style --foreground 8 --padding "$PADDING" 'The live environment is running in the required boot mode.'
  gum input --show-help --char-limit 0 --placeholder 'Press Enter to continue, or Esc to go back' --prompt '> ' >/dev/null
}
