# shellcheck shell=bash
# Welcome screen; live console settings stay separate from installation choices.

welcome_form() {
  local action status
  while true; do
    gum style --foreground 8 --padding "$PADDING" 'A guided installation of MirrorOS.'
    # shellcheck disable=SC2154 # Live keyboard state is initialized by the guide entry point.
    gum style --foreground 8 --padding "$PADDING" "Installation keyboard: $live_keyboard_label ($live_keyboard_source)"
    gum style --foreground 8 --padding "$PADDING" 'This layout is for the live installation, not the installed system.'
    action=$(gum choose --show-help --height 2 --selected 'Continue' 'Continue' 'Change installation keyboard layout') || return $?
    case $action in
      Continue) return 0 ;;
      'Change installation keyboard layout')
        step 'Installation keyboard layout'
        status=0
        live_console_keyboard_form || status=$?
        case $status in
          0|1) step 'Welcome to MirrorOS' ;;
          *) return "$status" ;;
        esac
        ;;
      *) return 6 ;;
    esac
  done
}
