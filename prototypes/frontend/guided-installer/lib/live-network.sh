# shellcheck shell=bash
# shellcheck disable=SC2034 # Network state is consumed by the guide's review screen.
# Live network preparation only; never writes installed-system choices or credentials.

live_network_ready() {
  local routes_v4 routes_v6 status=0
  command -v ip >/dev/null && command -v curl >/dev/null || return 6
  routes_v4=$(ip -o -4 route show default) || return 5
  routes_v6=$(ip -o -6 route show default) || return 5
  [[ -n $routes_v4 || -n $routes_v6 ]] || return 1
  # Prototype endpoint matches the current discovery policy. Discovery remains authoritative.
  curl --silent --fail --proto '=https' --connect-timeout 5 --max-time 10 \
    --output /dev/null -- https://archlinux.org/ 2>/dev/null || status=$?
  case $status in
    0) return 0 ;;
    5|6|7|22|28|35|47|51|52|55|56|58|60|77|80|83|90|91) return 1 ;;
    *) printf 'The network preparation probe failed unexpectedly (exit %s).\n' "$status" >&2; return 5 ;;
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
        gum style --padding "$PADDING" 'Connect a network cable, then retry the connection check.'
        ;;
      'Wi-Fi')
        gum style --padding "$PADDING" 'Configure Wi-Fi with iwctl in another live console, then return here.'
        gum style --foreground 8 --padding "$PADDING" 'Select Show connection instructions for the complete Wi-Fi setup steps.'
        ;;
      *) return 6 ;;
    esac
    if [[ $failed == true ]]; then
      gum style --foreground 1 --padding "$PADDING" 'Could not verify internet access. Check your connection and retry.'
    fi
    action=$(gum choose --show-help --height "${#actions[@]}" --selected 'Retry connection check' "${actions[@]}") || return $?
    case $action in
      'Retry connection check')
        gum style --foreground 8 --padding "$PADDING" 'Checking internet connection...'
        status=0
        live_network_ready || status=$?
        case $status in
          0) live_network_status='Connected'; return 0 ;;
          1) live_network_status='Not connected'; failed=true ;;
          *) return "$status" ;;
        esac
        ;;
      'Show connection instructions')
        [[ $method == 'Wi-Fi' && -r "$GUIDE_DIR/instructions/live-wifi.txt" ]] || return 6
        status=0
        gum pager < "$GUIDE_DIR/instructions/live-wifi.txt" || status=$?
        case $status in
          0|1) ;;
          *) return "$status" ;;
        esac
        ;;
      Back) return 1 ;;
      *) return 6 ;;
    esac
  done
}

live_network_form() {
  local action status check_connection=true
  while true; do
    if [[ $check_connection == true ]]; then
      step 'Preparing installation'
      gum style --foreground 8 --padding "$PADDING" 'Checking internet connection...'
      status=0
      live_network_ready || status=$?
      case $status in
        0) live_network_status='Connected'; return 0 ;;
        1) live_network_status='Not connected' ;;
        *) return "$status" ;;
      esac
    fi
    check_connection=true
    step 'Connect to the internet'
    gum style --foreground 8 --padding "$PADDING" 'Internet access is needed to prepare and install MirrorOS.' 'This connection is for the live environment only.'
    action=$(gum choose --show-help --height 3 --selected 'Ethernet' \
      'Ethernet' 'Wi-Fi' 'Cancel') || return $?
    case $action in
      Ethernet|'Wi-Fi')
        status=0
        live_network_method_form "$action" || status=$?
        case $status in
          0) return 0 ;;
          1) check_connection=false ;;
          *) return "$status" ;;
        esac
        ;;
      Cancel) abort ;;
      *) return 6 ;;
    esac
  done
}
