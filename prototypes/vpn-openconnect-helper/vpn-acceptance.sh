#!/usr/bin/bash
# Temporary acceptance tooling, not a MirrorOS-delivered VPN command.
set +x
set +v
set -Eeuo pipefail
umask 077

fail() { printf '%s\n' "$1" >&2; return 2; }
# shellcheck source=./vpn-preferences.sh
source "${BASH_SOURCE[0]%/*}/vpn-preferences.sh"

parse_auth() {
  local input=$1 output=$2 line key value
  local assignment="^([A-Z_]+)='([^']*)'$"
  local -A fields=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    [[ "$line" =~ $assignment ]] || { fail 'Unsupported authentication output; stop and review privately.'; return 2; }
    key=${BASH_REMATCH[1]}
    value=${BASH_REMATCH[2]}
    case "$key" in COOKIE|HOST|FINGERPRINT|RESOLVE|CONNECT_URL) ;; *) fail 'Unexpected authentication field.'; return 2 ;; esac
    [[ ! -v "fields[$key]" ]] || { fail 'Duplicate authentication field.'; return 2; }
    [[ ! "$value" =~ [[:cntrl:]] ]] || { fail 'Invalid authentication field.'; return 2; }
    fields[$key]=$value
  done < "$input"
  for key in COOKIE HOST FINGERPRINT RESOLVE; do
    [[ -n "${fields[$key]:-}" ]] || { fail 'Required authentication field missing.'; return 2; }
  done
  {
    printf 'vpn.secrets.cookie:%s\n' "${fields[COOKIE]}"
    printf 'vpn.secrets.gwcert:%s\n' "${fields[FINGERPRINT]}"
    printf 'vpn.secrets.gateway:%s\n' "${fields[HOST]}"
    printf 'vpn.secrets.resolve:%s\n' "${fields[RESOLVE]}"
  } > "$output"
}

cleanup() {
  local exit_status=$?
  trap - EXIT HUP INT TERM
  if [[ "${activating:-0}" == 1 && "${connected:-0}" != 1 ]]; then
    if ! nmcli connection down uuid "$profile_uuid" > /dev/null 2>&1; then
      printf 'Check privately that no partial VPN connection remains active.\n' >&2
    fi
  fi
  if [[ -n "${runtime:-}" && -d "$runtime" ]]; then
    rm -f -- "$runtime/auth.conf" "$runtime/auth.result" "$runtime/passwd"
    rmdir -- "$runtime"
  fi
  exit "$exit_status"
}

main() {
  (( $# == 0 )) || { fail 'This script accepts no arguments; enter private data only at prompts.'; return 2; }
  (( EUID != 0 )) || { fail 'Run as the graphical user, not with sudo.'; return 2; }
  [[ -z "${SSH_CONNECTION:-}" && -t 0 && -t 1 && -t 2 ]] || { fail 'Run locally in an unrecorded graphical terminal, not over SSH or a pipe.'; return 2; }
  local tool
  for tool in nmcli openconnect findmnt stat mktemp jq; do
    command -v "$tool" > /dev/null || { fail 'A required tool is unavailable.'; return 2; }
  done
  [[ "${XDG_RUNTIME_DIR:-}" == "/run/user/$EUID" && ! -L "$XDG_RUNTIME_DIR" ]] || { fail 'Unexpected user runtime directory.'; return 2; }
  [[ "$(stat -c %u "$XDG_RUNTIME_DIR")" == "$EUID" && "$(stat -c %a "$XDG_RUNTIME_DIR")" == 700 ]] || { fail 'User runtime directory is not private.'; return 2; }
  [[ "$(findmnt -n -o FSTYPE --target "$XDG_RUNTIME_DIR")" == tmpfs ]] || { fail 'User runtime directory is not on tmpfs.'; return 2; }
  local profile service data key item gateway username answer active_ids preferences_dir preferences
  local -a entries
  printf 'Temporary VPN acceptance helper. Do not use terminal recording or share its output.\n'
  printf 'Existing NetworkManager VPN profile name (private): '
  IFS= read -r profile
  [[ -n "$profile" && ! "$profile" =~ [[:cntrl:]] ]] || { fail 'Invalid profile name.'; return 2; }
  profile_uuid=$(nmcli -g connection.uuid connection show "$profile")
  [[ "$profile_uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || { fail 'Could not resolve one existing profile.'; return 2; }
  service=$(nmcli -g vpn.service-type connection show uuid "$profile_uuid")
  [[ "$service" == org.freedesktop.NetworkManager.openconnect ]] || { fail 'Profile is not the NetworkManager OpenConnect plugin.'; return 2; }
  active_ids=$(nmcli -g UUID connection show --active)
  if grep -qxF "$profile_uuid" <<< "$active_ids"; then fail 'Profile is already active; do not replace it during this test.'; return 2; fi
  data=$(nmcli -g vpn.data connection show uuid "$profile_uuid")
  IFS=, read -r -a entries <<< "$data"
  for key in cookie-flags gwcert-flags gateway-flags resolve-flags; do
    local found=0
    for item in "${entries[@]}"; do
      if [[ "$item" =~ ^[[:space:]]*${key}[[:space:]]*=[[:space:]]*2[[:space:]]*$ ]]; then found=1; fi
    done
    (( found == 1 )) || { fail 'Profile must already set cookie/gwcert/gateway/resolve flags to 2 (not saved). No profile was changed.'; return 2; }
  done
  preferences_dir="$HOME/.mirroros-vpn-acceptance"
  preferences="$preferences_dir/$profile_uuid.json"
  if [[ -e "$preferences_dir" || -L "$preferences_dir" ]]; then
    private_preferences_dir "$preferences_dir" || return 2
  fi
  if [[ -e "$preferences" || -L "$preferences" ]]; then
    load_preferences "$preferences" || return 2
    printf 'Reusing the private gateway and username saved for this profile.\n'
  else
    printf 'VPN HTTPS gateway including group path (private): '
    IFS= read -r gateway
    printf 'VPN username (private; not a password): '
    IFS= read -r username
    validate_preferences "$gateway" "$username" || return 2
    printf 'Optional: save ONLY gateway and username under ~/.mirroros-vpn-acceptance for this profile?\n'
    printf 'Type SAVE to retain them privately, or press Enter for this connection only: '
    IFS= read -r answer
    if [[ "$answer" == SAVE ]]; then
      save_preferences "$preferences_dir" "$profile_uuid" "$gateway" "$username" || return 2
      printf 'Private preferences saved. No password, OTP, cookie or certificate was stored.\n'
    fi
  fi
  printf 'This authenticates and activates the existing VPN via NetworkManager; routes/DNS may change.\n'
  printf 'Type CONNECT to authorize, or anything else to cancel: '
  IFS= read -r answer
  [[ "$answer" == CONNECT ]] || { printf 'Cancelled.\n'; return 3; }
  runtime=''
  activating=0
  connected=0
  trap cleanup EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  runtime=$(mktemp -d "$XDG_RUNTIME_DIR/mirroros-vpn-acceptance.XXXXXXXX")
  printf 'server = %s\nuser = %s\n' "$gateway" "$username" > "$runtime/auth.conf"
  unset gateway username data entries
  openconnect --protocol=anyconnect --authenticate --config "$runtime/auth.conf" > "$runtime/auth.result"
  parse_auth "$runtime/auth.result" "$runtime/passwd"
  activating=1
  nmcli connection up uuid "$profile_uuid" passwd-file "$runtime/passwd"
  connected=1
  rm -f -- "$runtime/auth.conf" "$runtime/auth.result" "$runtime/passwd"
  rmdir -- "$runtime"
  runtime=''
  printf 'VPN activated by NetworkManager; temporary authentication files removed.\n'
  printf 'Privately check corporate access, expected routes and DNS. Share pass/fail only.\n'
  printf 'Disconnect later through NetworkManager. No profile or global DNS setting was changed by this script.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
