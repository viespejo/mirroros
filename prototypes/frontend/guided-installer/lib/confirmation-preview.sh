# shellcheck shell=bash
# Presentation simulation only: never creates approval or invokes an engine.

confirmation_preview_form() {
  local choice
  gum style --foreground 3 --padding "$PADDING" 'SIMULATION ONLY - synthetic disk facts, no valid plan or approval.'
  # shellcheck disable=SC2154 # Preview choices are initialized by the entry point.
  gum style --padding "$PADDING" "Example disk: $disk" "Path: $disk_path" "Identity: $target_disk" "New layout: $storage_label"
  gum style --foreground 1 --padding "$PADDING" 'A real installation would erase all existing content on this disk.'
  gum style --foreground 8 --padding "$PADDING" 'Simulating confirmation only opens the password explanation.' 'No disk changes, approval records, or installation will occur.'
  choice=$(gum choose --show-help --height 4 --selected 'Back' --header 'Confirmation simulation' 'Simulate confirmation' 'Back' 'Cancel preview') || return $?
  case $choice in
    'Simulate confirmation') return 0 ;;
    'Back') return 1 ;;
    'Cancel preview') abort ;;
    *) return 6 ;;
  esac
}
