# shellcheck shell=bash
# Preview choice only; no swapfile is created or resized.

swapfile_size_form() {
  # shellcheck disable=SC2154 # Choice state is initialized by the entry point.
  local value=$swapfile_size normalized
  while true; do
    gum style --foreground 8 --padding "$PADDING" 'The swapfile is used for swap and hibernation.' 'The default does not guarantee hibernation for every workload.'
    gum style --padding "$PADDING" 'Enter an integer from 512 to 65536 MiB.' 'A real plan checks that the complete layout fits the selected disk.'
    value=$(gum input --show-help --value "$value" --placeholder 'Size in MiB' --prompt 'Swapfile size (MiB)> ') || return $?
    normalized=$value
    while [[ $normalized == 0* && ${#normalized} -gt 1 ]]; do normalized=${normalized:1}; done
    if [[ $normalized =~ ^[0-9]{1,5}$ ]] && (( 10#$normalized >= 512 && 10#$normalized <= 65536 )); then
      # shellcheck disable=SC2034 # The entry point consumes the confirmed choice.
      swapfile_size=$((10#$normalized))
      return 0
    fi
    step 'Choose swapfile size'
    gum style --foreground 1 --padding "$PADDING" 'Use a whole number from 512 to 65536 MiB.'
  done
}
