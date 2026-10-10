# shellcheck shell=bash
# Account policy preview only; no account or password changes.

initialize_root_account_preview() {
  root_account=$(jq -er '.policy.root_account.value | select(type == "string")' "$GUIDE_DIR/fixtures/installation-policy.json") || return 6
  case $root_account in
    locked) root_account_label='Locked (default)' ;;
    password) root_account_label='Password login enabled' ;;
    *) return 6 ;;
  esac
}

root_account_form() {
  local choice value
  gum style --foreground 8 --padding "$PADDING" 'Locked root: use your wheel-group user with sudo for administration.' 'Password enabled: root receives the same password as your user.'
  gum style --padding "$PADDING" 'The intended flow asks for one password, with repetition, after plan approval.' 'This preview does not collect passwords or change accounts.'
  choice=$(gum choose --show-help --height 5 --selected "$root_account_label" --header 'Root account' 'Locked (default)' 'Password login enabled') || return $?
  case $choice in
    'Locked (default)') value=locked ;;
    'Password login enabled') value=password ;;
    *) return 6 ;;
  esac
  # shellcheck disable=SC2034 # The entry point consumes the account choice and review label.
  root_account=$value root_account_label=$choice
}
