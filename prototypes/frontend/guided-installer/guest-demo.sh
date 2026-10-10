#!/usr/bin/env bash
# Installation guide prototype inside the Omarchy live ISO. No disk access or installation.
# Optional keyboard settings change only the live session's virtual consoles.
# Step text, palette and table presentation adapted from omacom/omarchy-iso configurator
# and .automated_script.sh. Copyright (c) 2025 Anton Hvornum; see LICENSE-ISO.
# Loads only whitelisted presentation functions from the actual ISO configurator.
# Passwords belong after real plan approval; no secret is collected here.
set -euo pipefail

[[ -t 0 && -t 1 ]] || { printf 'Use a guest virtual console.\n' >&2; exit 2; }
command -v gum >/dev/null || { printf 'The ISO must already contain Gum.\n' >&2; exit 6; }
export OMARCHY_PATH='/usr/share/omarchy'
GUIDE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOGO_PATH="$GUIDE_DIR/mirroros-logo.txt"
export LOGO_PATH
[[ -r /root/configurator && -r "$LOGO_PATH" ]] || {
  printf 'This demo requires /root/configurator and mirroros-logo.txt beside the script.\n' >&2; exit 6;
}
LOGO_WIDTH=$(awk '{ if (length > max) max = length } END { print max+0 }' "$LOGO_PATH")
export LOGO_WIDTH
export GUM_CONFIRM_PROMPT_FOREGROUND=6
export GUM_CONFIRM_SELECTED_FOREGROUND=0
export GUM_CONFIRM_SELECTED_BACKGROUND=2
export GUM_CONFIRM_UNSELECTED_FOREGROUND=7
export GUM_CONFIRM_UNSELECTED_BACKGROUND=0
export GUM_INPUT_PROMPT_FOREGROUND="${GUM_CHOOSE_HEADER_FOREGROUND:-99}"
export GUM_INPUT_CURSOR_FOREGROUND="${GUM_CHOOSE_CURSOR_FOREGROUND:-212}"
export CLICOLOR_FORCE=1 FORCE_COLOR=1
COLUMNS=$(tput cols)
LINES=$(tput lines)
export COLUMNS LINES
# Extract the step function only: never source the configurator's top-level flow.
# shellcheck disable=SC1090 # Source is a filtered stream from the guest ISO.
source <(awk '
  /^step\(\) \{/ { copying = 1 }
  copying { print }
  copying && /^}/ { copying = 0 }
' /root/configurator)
declare -F step >/dev/null || { printf 'Missing presentation function: step\n' >&2; exit 6; }

# Center the logo and guide as one block with a shared left edge.
measure_terminal() {
  TERM_WIDTH=$(stty size 2>/dev/null </dev/tty | awk '{print $2}')
  (( TERM_WIDTH > 0 )) || TERM_WIDTH=${COLUMNS:-80}

  local guide_width=$LOGO_WIDTH
  (( guide_width > TERM_WIDTH )) && guide_width=$TERM_WIDTH
  PADDING_LEFT=$(((TERM_WIDTH - guide_width) / 2))
  PADDING_LEFT_SPACES=$(printf '%*s' "$PADDING_LEFT" '')
  LOGO_PADDING_LEFT=$PADDING_LEFT

  PADDING="0 0 0 $PADDING_LEFT"
  export GUM_CHOOSE_PADDING="$PADDING"
  export GUM_FILTER_PADDING="$PADDING"
  export GUM_INPUT_PADDING="$PADDING"
  export GUM_SPIN_PADDING="$PADDING"
  export GUM_TABLE_PADDING="$PADDING"
  export GUM_CONFIRM_PADDING="$PADDING"
}

clear_logo() {
  measure_terminal
  printf '\033[H\033[2J'
  local row white=$'\033[97m' blue=$'\033[34m'
  printf '\n\n'
  while IFS= read -r row || [[ -n $row ]]; do
    printf '%*s%s%s%s%s\033[0m\n' "$LOGO_PADDING_LEFT" '' "$blue" "${row:0:60}" "$white" "${row:60}"
  done < "$LOGO_PATH"
}
measure_terminal

# Same Tokyo Night VT palette used by the Omarchy ISO. Changes only the guest VT.
if [[ $(tty) == /dev/tty* ]]; then
  printf '\e]P01a1b26\e]P1f7768e\e]P29ece6a\e]P3e0af68\e]P47aa2f7\e]P5bb9af7\e]P67dcfff\e]P7a9b1d6'
  printf '\e]P8414868\e]P9f7768e\e]PA9ece6a\e]PBe0af68\e]PC7aa2f7\e]PDbb9af7\e]PE7dcfff\e]PFc0caf5\033[0m'
fi

# shellcheck source=lib/live-console.sh
source "$GUIDE_DIR/lib/live-console.sh"
# shellcheck source=lib/welcome.sh
source "$GUIDE_DIR/lib/welcome.sh"
# shellcheck source=lib/live-network.sh
source "$GUIDE_DIR/lib/live-network.sh"
# shellcheck source=lib/target-selection.sh
source "$GUIDE_DIR/lib/target-selection.sh"
# shellcheck source=lib/disk-selection.sh
source "$GUIDE_DIR/lib/disk-selection.sh"
# shellcheck source=lib/storage-layout.sh
source "$GUIDE_DIR/lib/storage-layout.sh"
# shellcheck source=lib/swapfile-size.sh
source "$GUIDE_DIR/lib/swapfile-size.sh"
# shellcheck source=lib/localization.sh
source "$GUIDE_DIR/lib/localization.sh"
# shellcheck source=lib/root-account.sh
source "$GUIDE_DIR/lib/root-account.sh"
# shellcheck source=lib/confirmation-preview.sh
source "$GUIDE_DIR/lib/confirmation-preview.sh"
# shellcheck source=lib/password-preview.sh
source "$GUIDE_DIR/lib/password-preview.sh"

abort() { echo; gum style 'Guide cancelled. No installation or disk operation was executed.'; exit 3; }
trap abort INT

keyboard_form() {
  gum style --foreground 8 --padding "$PADDING" "Choose the installed system's console keyboard layout." 'Wayland desktop layouts are configured separately.'
  # This guide offers US and ES console layouts only.
  local keyboards choice
  keyboards=$'English (US)|us\nSpanish (ES)|es'
  choice=$(printf '%s\n' "$keyboards" | cut -d '|' -f1 | gum choose --show-help --height 10 --selected "$keyboard_label" --header 'Select keyboard layout') || return $?
  keyboard_label=$choice
  keyboard=$(printf '%s\n' "$keyboards" | awk -F '|' -v c="$choice" '$1==c{print $2; exit}')
  # Do not change the live guest keyboard; this is a presentation comparison only.
}
input_field() {
  local variable=$1 prompt=$2 placeholder=$3 value
  value=$(gum input --show-help --value "${!variable}" --placeholder "$placeholder" --prompt "$prompt") || return $?
  printf -v "$variable" '%s' "$value"
}

username_form() {
  local value=$username
  while true; do
    gum style --foreground 8 --padding "$PADDING" "Choose the username you'll use to sign in." 'This user belongs to wheel and can administer the system with sudo.'
    value=$(gum input --show-help --value "$value" --placeholder 'Lowercase letters, digits, underscores, or dashes' --prompt 'Username> ') || return $?
    if [[ ${#value} -le 32 && $value != root && $value =~ ^[a-z_][a-z0-9_-]*\$?$ ]]; then
      username=$value
      return 0
    fi
    step "Let's setup your user account..."
    gum style --foreground 1 --padding "$PADDING" 'Use 1-32 characters, starting with a lowercase letter or underscore.' 'Only lowercase letters, digits, underscores, dashes, and an optional final $.' 'The name root is reserved.'
  done
}

review_form() {
  local field value choice
  # Render values as text, not CSV, so punctuation in answers stays literal.
  while IFS= read -r field && IFS= read -r value; do
    printf '%s%-12s %s\n' "$PADDING_LEFT_SPACES" "$field" "$value"
  done < <(printf '%s\n' Target "$target_label ($target_id)" Disk "$disk" Storage "$storage_label" Swapfile "$swapfile_size MiB" Timezone "$timezone" Language "$system_lang" Formats "$formats_label ($format_locale)" Locales "${enabled_locales[*]}" Internet "$live_network_status" Username "$username" Root "$root_account_label" Hostname "$hostname" Keyboard "$keyboard")
  echo
  gum style --foreground 8 --padding "$PADDING" 'Review only: this does not approve a plan or authorize disk changes.' 'Next: simulated confirmation, then password explanation; no installation runs.' 'A real flow needs bound plan/disk confirmation, then passwords, before execution.'
  choice=$(gum choose --show-help --height 3 --selected 'Continue to confirmation preview' --header 'Review navigation' 'Continue to confirmation preview' 'Back') || return $?
  case $choice in
    'Continue to confirmation preview') return 0 ;;
    'Back') return 1 ;;
    *) return 6 ;;
  esac
}

initialize_live_keyboard
target_id=''
target_label=''
live_network_status='Not checked'
keyboard_label='English (US)'
keyboard=us
username=mirroros
hostname=mirroros
timezone=Europe/Madrid
target_disk=''
disk=''
disk_path=''
storage_option='ext4-systemd-boot'
storage_label='ext4 + systemd-boot - Default'
swapfile_size=$(jq -er '.policy.swapfile_size.value | select(type == "number" and floor == . and . >= 512 and . <= 65536)' "$GUIDE_DIR/fixtures/installation-policy.json") || { printf 'Invalid swapfile default in the preview policy.\n' >&2; exit 6; }
initialize_localization_preview || { printf 'Invalid localization default in the preview policy.\n' >&2; exit 6; }
initialize_root_account_preview || { printf 'Invalid root account default in the preview policy.\n' >&2; exit 6; }
screen=0
going_back=false
titles=('Welcome to MirrorOS' 'Connect to the internet' 'Choose installation target' 'Choose installation disk' 'Choose storage layout' 'Choose swapfile size' 'Select your timezone' 'Choose system language' 'Choose regional formats' 'Choose installed console keyboard' 'Name your machine' "Let's setup your user account..." 'Choose root account policy' 'Review your choices' 'Confirmation preview - simulation only' 'Password requirements - preview only')
while (( screen < ${#titles[@]} )); do
  # Back navigation skips automatic preparation instead of bouncing forward.
  if [[ $going_back == true ]] && (( screen == 1 )); then screen=0; fi
  going_back=false
  # Network preparation draws a screen only when a connection is needed.
  if (( screen != 1 )); then step "${titles[screen]}"; fi
  status=0
  case $screen in
    0) welcome_form || status=$? ;;
    1) live_network_form || status=$? ;;
    2) target_selection_form || status=$? ;;
    3) disk_selection_form || status=$? ;;
    4) storage_layout_form || status=$? ;;
    5) swapfile_size_form || status=$? ;;
    6)
      if value=$(printf '%s\n' Europe/Madrid Europe/London UTC | gum choose --show-help --height 10 --selected "$timezone" --header 'Timezone'); then timezone=$value; else status=$?; fi
      ;;
    7) system_language_form || status=$? ;;
    8) regional_formats_form || status=$? ;;
    9) keyboard_form || status=$? ;;
    10)
      input_field hostname 'Hostname> ' "Letters, digits, and dashes (or return for 'mirroros')" || status=$?
      if (( status == 0 )); then hostname=${hostname:-mirroros}; fi
      ;;
    11) username_form || status=$? ;;
    12) root_account_form || status=$? ;;
    13) review_form || status=$? ;;
    14) confirmation_preview_form || status=$? ;;
    15) password_preview_form || status=$? ;;
  esac
  case $status in
    0) screen=$((screen + 1)) ;;
    1)
      going_back=true
      if (( screen > 0 )); then screen=$((screen - 1)); fi
      ;;
    130) abort ;;
    *) printf 'Guide stopped (exit %s). No installation or disk operation was executed.\n' "$status" >&2; exit "$status" ;;
  esac
done
clear_logo
echo
gum style 'Presentation demo finished. No installation or disk operation executed.'
gum style --foreground 8 'Synthetic example facts were used. No credentials or evidence were saved.'
exit 2
