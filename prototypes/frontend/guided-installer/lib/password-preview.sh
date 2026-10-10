# shellcheck shell=bash
# Explains future secret handling without collecting any secret.

password_preview_form() {
  local choice root_message
  # shellcheck disable=SC2154 # Account choice is initialized by the entry point.
  case $root_account in
    locked) root_message='Root stays locked; no password is assigned to root.' ;;
    password) root_message='Root receives the same password as your user, not a second password.' ;;
    *) return 6 ;;
  esac
  gum style --foreground 3 --padding "$PADDING" 'PREVIEW ONLY - do not enter a real password here.'
  # shellcheck disable=SC2154 # Username is initialized by the entry point.
  gum style --padding "$PADDING" "A real flow asks for one password for $username, with repetition." 'Your user can administer the system with sudo.' "$root_message"
  gum style --foreground 8 --padding "$PADDING" 'Passwords follow real bound plan/disk confirmation, before disk writes.' 'Cancelling password entry must prevent installation from starting.' 'Passwords never belong in the plan, review, or retained evidence.'
  choice=$(gum choose --show-help --height 3 --selected 'Finish preview' --header 'No password collection in this prototype' 'Finish preview' 'Back') || return $?
  case $choice in
    'Finish preview') return 0 ;;
    'Back') return 1 ;;
    *) return 6 ;;
  esac
}
