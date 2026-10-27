#!/usr/bin/bash
# shellcheck disable=SC2034 # Live state is read by the screen and flow libraries that source this file.
# Live-environment preparation of the guided installer: the live console keyboard and live connectivity.
#
# Everything here concerns the live session only. It never writes an installed-system choice, never asks for
# or stores a Wi-Fi credential, and never copies a live connection into the installed system. It starts or
# restarts no service, changes no clock, and bypasses neither TLS nor signature verification.
#
# Presentation text adapted from the frozen reference (prototypes/frontend/guided-installer/lib/live-console.sh
# and live-network.sh); see install/confirmation/UPSTREAM.md.

readonly LIVE_CLOCK_WAIT_SECONDS=60
readonly LIVE_KEYRING_WAIT_SECONDS=600
# Prototype endpoint, matching the current discovery policy. Discovery remains authoritative.
readonly LIVE_HTTPS_URL='https://archlinux.org/'
readonly LIVE_NETWORK_NOT_READY=10
readonly LIVE_CLOCK_NOT_READY=11
readonly LIVE_KEYRING_NOT_READY=12

live_network_status='Not checked'
live_keyboard_label='English (US)'
live_keyboard_source='Console default'

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
  if ! command -v loadkeys > /dev/null; then
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

# Text size is console-local presentation state, never an installed-system choice.
live_console_text_size_form() {
  local choice
  gum style --foreground 8 --padding "$PADDING" 'Original restores the font selected at startup.' 'Original x2 doubles the saved font, preserving every glyph.'
  echo
  choice=$(ui_choose --show-help --height 2 --selected "$UI_TEXT_SIZE" 'Original' 'Original x2') || return $?
  ui_apply_text_size "$choice"
}

# Waits for the ISO's enabled systemd-timesyncd to report synchronization. The wait counts one-second sleeps
# instead of reading the wall clock, so a clock step during synchronization cannot shorten or extend it:
# at most LIVE_CLOCK_WAIT_SECONDS seconds per attempt. Returns 0, LIVE_CLOCK_NOT_READY, or 5.
live_clock_ready() {
  local attempt synchronized
  command -v timedatectl > /dev/null || return 6
  for ((attempt = 0; attempt <= LIVE_CLOCK_WAIT_SECONDS; attempt++)); do
    synchronized=$(timedatectl show --property=NTPSynchronized --value 2> /dev/null) || return 5
    if [[ $synchronized == yes ]]; then return 0; fi
    if ((attempt < LIVE_CLOCK_WAIT_SECONDS)); then sleep 1; fi
  done
  return "$LIVE_CLOCK_NOT_READY"
}

# Waits for pacman-init.service to report active, with the same one-second sleeps as the clock wait, at most
# LIVE_KEYRING_WAIT_SECONDS seconds per attempt. It starts nothing and changes no signature policy. A screen is drawn
# only when the keyring is not ready on the first look. Returns 0, LIVE_KEYRING_NOT_READY (the wait expired or the
# service failed), or 6.
live_keyring_ready() {
  local attempt state drawn=false
  command -v systemctl > /dev/null || return 6
  for ((attempt = 0; attempt <= LIVE_KEYRING_WAIT_SECONDS; attempt++)); do
    state=$(systemctl is-active pacman-init.service 2> /dev/null < /dev/null) || true
    case $state in
      active) return 0 ;;
      failed) return "$LIVE_KEYRING_NOT_READY" ;;
    esac
    if [[ $drawn == false ]]; then
      step 'Preparing the package keyring'
      gum style --foreground 8 --padding "$PADDING" 'Waiting for the package keyring to be initialized...'
      drawn=true
    fi
    if ((attempt < LIVE_KEYRING_WAIT_SECONDS)); then sleep 1; fi
  done
  return "$LIVE_KEYRING_NOT_READY"
}

# One coordinated attempt: route, name resolution, time readiness, then the validated HTTPS check, so a clock
# failure is never reported as a generic network failure. Returns 0, LIVE_NETWORK_NOT_READY,
# LIVE_CLOCK_NOT_READY, or an unexpected status (5 or 6).
live_prepare_check() {
  local routes_v4 routes_v6 host status=0
  command -v ip > /dev/null && command -v curl > /dev/null && command -v getent > /dev/null || return 6
  routes_v4=$(ip -o -4 route show default) || return 5
  routes_v6=$(ip -o -6 route show default) || return 5
  [[ -n $routes_v4 || -n $routes_v6 ]] || return "$LIVE_NETWORK_NOT_READY"
  host=${LIVE_HTTPS_URL#https://}
  host=${host%%/*}
  getent ahosts "$host" > /dev/null 2>&1 || return "$LIVE_NETWORK_NOT_READY"
  gum style --foreground 8 --padding "$PADDING" 'Checking system clock...'
  live_clock_ready || status=$?
  [[ $status -eq 0 ]] || return "$status"
  curl --silent --fail --proto '=https' --connect-timeout 5 --max-time 10 \
    --output /dev/null -- "$LIVE_HTTPS_URL" 2> /dev/null || status=$?
  case $status in
    0) return 0 ;;
    5 | 6 | 7 | 22 | 28 | 35 | 47 | 51 | 52 | 55 | 56 | 58 | 60 | 77 | 80 | 83 | 90 | 91) return "$LIVE_NETWORK_NOT_READY" ;;
    *)
      flow_log "live preparation: the HTTPS probe failed unexpectedly (curl exit ${status})"
      return 5
      ;;
  esac
}

live_network_method_form() {
  local method=$1 action status failed=false
  local -a actions=('Retry connection check' 'Back')
  if [[ $method == 'Wi-Fi' ]]; then
    actions=('Retry connection check' 'Show connection instructions' 'Back')
  fi
  while true; do
    step "Connect with $method"
    case $method in
      Ethernet)
        gum style --foreground 8 --padding "$PADDING" 'Connect a network cable, then retry the connection check.'
        ;;
      'Wi-Fi')
        gum style --foreground 8 --padding "$PADDING" 'Configure Wi-Fi with iwctl in another live console, then return here.'
        gum style --foreground 8 --padding "$PADDING" 'Select Show connection instructions for the complete Wi-Fi setup steps.'
        ;;
      *) return 6 ;;
    esac
    if [[ $failed == true ]]; then
      echo
      gum style --foreground 1 --padding "$PADDING" 'Could not verify internet access. Check your connection and retry.'
    fi
    echo
    action=$(ui_choose --show-help --height "${#actions[@]}" --selected 'Retry connection check' "${actions[@]}") || return $?
    case $action in
      'Retry connection check')
        gum style --foreground 8 --padding "$PADDING" 'Checking internet connection...'
        status=0
        live_prepare_check || status=$?
        case $status in
          0) live_network_status='Connected'; return 0 ;;
          "$LIVE_NETWORK_NOT_READY") live_network_status='Not connected'; failed=true ;;
          *) return "$status" ;;
        esac
        ;;
      'Show connection instructions')
        [[ $method == 'Wi-Fi' && -r "${FLOW_CODE_ROOT}/install/confirmation/instructions/live-wifi.txt" ]] || return 6
        status=0
        gum pager --border-foreground 4 < "${FLOW_CODE_ROOT}/install/confirmation/instructions/live-wifi.txt" || status=$?
        case $status in
          0 | 1) ;;
          *) return "$status" ;;
        esac
        ;;
      Back) return 1 ;;
      *) return 6 ;;
    esac
  done
}

# The connectivity screen: Ethernet or Wi-Fi guidance for the live environment only. Returns 0 when the
# coordinated check passed, 1 for Back, LIVE_CLOCK_NOT_READY when the clock was the reason, or another status.
live_connect_form() {
  local action status
  while true; do
    step 'Connect to the internet'
    gum style --foreground 8 --padding "$PADDING" 'Internet access is needed to prepare and install MirrorOS.' 'This connection is for the live environment only.'
    echo
    action=$(ui_choose --show-help --height 3 --selected 'Ethernet' \
      'Ethernet' 'Wi-Fi' 'Cancel') || return $?
    case $action in
      Ethernet | 'Wi-Fi')
        status=0
        live_network_method_form "$action" || status=$?
        case $status in
          1) ;;
          *) return "$status" ;;
        esac
        ;;
      Cancel) flow_cancel preparation ;;
      *) return 6 ;;
    esac
  done
}

# The clock failure screen. Returns 0 to retry the whole check, or 1 for Esc; Cancel ends the run.
live_clock_form() {
  local action
  step 'Waiting for the system clock'
  gum style --foreground 8 --padding "$PADDING" 'Accurate time is needed to verify secure connections and package signatures.'
  gum style --foreground 8 --padding "$PADDING" 'Automatic time synchronization is enabled. Make sure the network works, then retry.'
  echo
  action=$(ui_choose --show-help --height 2 --selected 'Retry clock check' 'Retry clock check' 'Cancel') || return $?
  case $action in
    'Retry clock check') return 0 ;;
    Cancel) flow_cancel preparation ;;
    *) return 6 ;;
  esac
}

# The keyring failure screen. Returns 0 to retry the keyring check, or 1 for Esc; Cancel ends the run.
live_keyring_form() {
  local action
  step 'Package keyring not ready'
  gum style --foreground 8 --padding "$PADDING" 'Package signatures cannot be verified until the keyring is ready.' 'Wait a moment, then retry.'
  echo
  action=$(ui_choose --show-help --height 2 --selected 'Retry keyring check' 'Retry keyring check' 'Cancel') || return $?
  case $action in
    'Retry keyring check') return 0 ;;
    Cancel) flow_cancel preparation ;;
    *) return 6 ;;
  esac
}

# Live preparation: it draws a screen that needs attention only when the coordinated check or the keyring wait
# fails. Returns 0 when the live environment is ready, 1 for Back, or another status for the flow to normalize.
live_preparation_form() {
  local status mode=check
  while true; do
    case $mode in
      check)
        step 'Preparing installation'
        gum style --foreground 8 --padding "$PADDING" 'Checking internet connection...'
        status=0
        live_prepare_check || status=$?
        case $status in
          0) live_network_status='Connected'; mode=keyring ;;
          "$LIVE_NETWORK_NOT_READY")
            live_network_status='Not connected'
            flow_log 'live preparation: live_network_not_ready'
            mode=connect
            ;;
          "$LIVE_CLOCK_NOT_READY")
            flow_log 'live preparation: live_clock_not_ready'
            mode=clock
            ;;
          *) return "$status" ;;
        esac
        ;;
      connect)
        status=0
        live_connect_form || status=$?
        case $status in
          0) live_network_status='Connected'; mode=keyring ;;
          "$LIVE_CLOCK_NOT_READY") flow_log 'live preparation: live_clock_not_ready'; mode=clock ;;
          *) return "$status" ;;
        esac
        ;;
      clock)
        status=0
        live_clock_form || status=$?
        case $status in
          0) mode=check ;;
          *) return "$status" ;;
        esac
        ;;
      keyring)
        status=0
        live_keyring_ready || status=$?
        case $status in
          0) return 0 ;;
          "$LIVE_KEYRING_NOT_READY") flow_log 'live preparation: live_keyring_not_ready'; mode=keyring_failed ;;
          *) return "$status" ;;
        esac
        ;;
      keyring_failed)
        status=0
        live_keyring_form || status=$?
        case $status in
          0) mode=keyring ;;
          *) return "$status" ;;
        esac
        ;;
    esac
  done
}
