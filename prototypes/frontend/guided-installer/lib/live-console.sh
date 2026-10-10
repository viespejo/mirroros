# shellcheck shell=bash
# shellcheck disable=SC2034 # Live keyboard state is consumed by the welcome screen.
# Live console settings only; not installed-system choices.

initialize_live_keyboard() {
  local config keymap=''
  live_keyboard_source='Console default'
  for config in /etc/vconsole.conf /usr/share/factory/etc/vconsole.conf; do
    [[ -r $config ]] || continue
    keymap=$(awk '
      /^[[:space:]]*KEYMAP[[:space:]]*=/ {
        sub(/^[^=]*=[[:space:]]*/, "")
        sub(/[[:space:]]*#.*/, "")
        gsub(/[\047\042[:space:]]/, "")
        print
        exit
      }
    ' "$config") || return 5
    if [[ $keymap =~ ^[A-Za-z0-9_.+-]+$ ]]; then
      live_keyboard_source='ISO configuration'
      break
    fi
    keymap=''
  done
  keymap=${keymap:-us}
  case $keymap in
    us) live_keyboard_label='English (US)' ;;
    es) live_keyboard_label='Spanish (ES)' ;;
    *) live_keyboard_label=$keymap ;;
  esac
}

live_console_keyboard_form() {
  local choice keymap
  gum style --foreground 8 --padding "$PADDING" 'Choose the keyboard layout used during installation.' 'This affects all virtual consoles in this live session only.'
  choice=$(gum choose --show-help --height 2 --selected "$live_keyboard_label" --header 'Installation keyboard layout' 'English (US)' 'Spanish (ES)') || return $?
  case $choice in
    'English (US)') keymap=us ;;
    'Spanish (ES)') keymap=es ;;
    *) return 6 ;;
  esac
  if ! command -v loadkeys >/dev/null; then
    printf 'loadkeys is required to change the live console keyboard.\n' >&2
    return 2
  fi
  if ! loadkeys "$keymap"; then
    printf 'Could not change the live console keyboard. No installation was run.\n' >&2
    return 5
  fi
  live_keyboard_label=$choice
  live_keyboard_source='Selected in this guide'
}
