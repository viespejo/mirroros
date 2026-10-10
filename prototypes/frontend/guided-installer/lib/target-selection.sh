# shellcheck shell=bash
# Preview target selection; no hardware validation or discovery is performed.

target_selection_form() {
  local choice
  gum style --foreground 8 --padding "$PADDING" 'Choose the machine profile for this installation.' 'This is not the disk selection.'
  gum style --foreground 8 --padding "$PADDING" 'Preview only: hardware matching is not checked.' 'Framework hardware identity capture is still pending.'
  # shellcheck disable=SC2154 # Target state is initialized by the guide entry point.
  choice=$(gum choose --show-help --height 2 --selected "${target_label:-Reference VM}" --header 'Installation target' 'Reference VM' 'Framework Laptop 13 Pro (AMD)') || return $?
  # shellcheck disable=SC2034 # The guide entry point consumes the selected target ID.
  case $choice in
    'Reference VM') target_id=reference-vm ;;
    'Framework Laptop 13 Pro (AMD)') target_id=framework-13-pro-amd ;;
    *) return 6 ;;
  esac
  target_label=$choice
}
