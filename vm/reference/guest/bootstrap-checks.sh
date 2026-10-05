#!/usr/bin/bash
# Guest-side bootstrap checks, delivered through the temporary NoCloud medium.
# nocloud.sh prepends MIRROROS_RUN_ID, MIRROROS_HTTPS_URL, and MIRROROS_HTTPS_TIMEOUT_SECONDS.
# Read-only: no package installation, no installer, no disk writes. The only output is one JSON
# report on the serial console, wrapped in run-bound marker lines.
set -u

: "${MIRROROS_RUN_ID:?}" "${MIRROROS_HTTPS_URL:?}" "${MIRROROS_HTTPS_TIMEOUT_SECONDS:?}"

NETWORK_WAIT_SECONDS=60
SERIAL_DEVICE=/dev/ttyS0
declare -A CHECK_STATUS=()
declare -A CHECK_DETAIL=()
IPV4_ADDRESS=''
HTTP_STATUS='null'
TLS_VERIFIED='false'

sanitize() {
  local text="${1//[^A-Za-z0-9 ._:\/=,+@-]/_}"
  printf '%s' "${text:0:200}"
}

record() {
  CHECK_STATUS[$1]="$2"
  CHECK_DETAIL[$1]="$(sanitize "$3")"
}

wait_for() {
  local deadline=$((SECONDS + NETWORK_WAIT_SECONDS))

  while ! "$@" >/dev/null 2>&1; do
    [[ "$SECONDS" -lt "$deadline" ]] || return 1
    sleep 2
  done
}

first_ipv4_address() {
  local line
  local address

  line="$(ip -4 -o addr show scope global 2>/dev/null | head -n 1)" || return 1
  [[ -n "$line" ]] || return 1
  address="$(awk '{ split($4, parts, "/"); print parts[1] }' <<< "$line")"
  [[ -n "$address" ]] || return 1
  printf '%s\n' "$address"
}

has_default_route() {
  [[ -n "$(ip -4 route show default 2>/dev/null)" ]]
}

resolves_archlinux() {
  [[ -n "$(getent ahostsv4 archlinux.org 2>/dev/null)" ]]
}

check_uefi_mode() {
  if [[ -d /sys/firmware/efi ]]; then
    record uefi_mode passed 'guest booted in UEFI mode'
  else
    record uefi_mode failed 'firmware interface /sys/firmware/efi is absent'
  fi
}

check_root_shell() {
  if /usr/bin/bash -c '[[ "$(id -u)" -eq 0 ]]' >/dev/null 2>&1; then
    record root_shell passed 'a root shell executes commands'
  else
    record root_shell failed 'a root shell could not be confirmed'
  fi
}

check_native_install_tools() {
  local tool
  local -a missing=()

  for tool in pacstrap genfstab arch-chroot archinstall; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if [[ "${#missing[@]}" -eq 0 ]]; then
    record native_install_tools passed 'pacstrap genfstab arch-chroot archinstall are available'
  else
    record native_install_tools failed "missing: ${missing[*]}"
  fi
}

check_ipv4_address() {
  if IPV4_ADDRESS="$(wait_for_value first_ipv4_address)"; then
    record ipv4_address passed 'a global IPv4 address is assigned'
  else
    IPV4_ADDRESS=''
    record ipv4_address failed "no global IPv4 address within ${NETWORK_WAIT_SECONDS}s"
  fi
}

wait_for_value() {
  local deadline=$((SECONDS + NETWORK_WAIT_SECONDS))
  local value

  while ! value="$("$@" 2>/dev/null)"; do
    [[ "$SECONDS" -lt "$deadline" ]] || return 1
    sleep 2
  done
  printf '%s\n' "$value"
}

check_default_route() {
  if wait_for has_default_route; then
    record default_route passed 'an IPv4 default route exists'
  else
    record default_route failed "no IPv4 default route within ${NETWORK_WAIT_SECONDS}s"
  fi
}

check_dns_resolution() {
  if wait_for resolves_archlinux; then
    record dns_resolution passed 'archlinux.org resolves to an IPv4 address'
  else
    record dns_resolution failed "archlinux.org did not resolve within ${NETWORK_WAIT_SECONDS}s"
  fi
}

check_https_request() {
  local output
  local curl_status
  local code
  local verify

  if output="$(curl --silent --show-error --proto '=https' --max-time "$MIRROROS_HTTPS_TIMEOUT_SECONDS" \
    --output /dev/null --write-out '%{http_code} %{ssl_verify_result}' "$MIRROROS_HTTPS_URL" 2>/dev/null)"; then
    curl_status=0
  else
    curl_status=$?
  fi

  code="${output%% *}"
  verify="${output##* }"
  if [[ "$code" =~ ^[0-9]{3}$ && "$code" != '000' ]]; then
    HTTP_STATUS="$((10#$code))"
  fi
  if [[ "$curl_status" -eq 0 && "$verify" == '0' ]]; then
    TLS_VERIFIED='true'
  fi

  if [[ "$curl_status" -eq 0 && "$verify" == '0' && "$HTTP_STATUS" == '200' ]]; then
    record https_request passed 'HTTPS request returned 200 with a validated certificate'
  else
    record https_request failed "curl status ${curl_status}, TLS verify result ${verify}, HTTP status ${HTTP_STATUS}"
  fi
}

emit_report() {
  local -a ids=(uefi_mode root_shell native_install_tools ipv4_address default_route dns_resolution https_request)
  local id
  local result=passed
  local checks=''
  local extra
  local body

  for id in "${ids[@]}"; do
    extra=''
    [[ "${CHECK_STATUS[$id]}" == 'passed' ]] || result=failed
    case "$id" in
      ipv4_address)
        [[ -z "$IPV4_ADDRESS" ]] || extra=",\"address\":\"${IPV4_ADDRESS}\""
        ;;
      https_request)
        extra=",\"http_status\":${HTTP_STATUS},\"tls_verified\":${TLS_VERIFIED}"
        ;;
    esac
    checks+="${checks:+,}\"${id}\":{\"status\":\"${CHECK_STATUS[$id]}\",\"detail\":\"${CHECK_DETAIL[$id]}\"${extra}}"
  done
  body="{\"schema_version\":1,\"run_id\":\"${MIRROROS_RUN_ID}\",\"checks\":{${checks}},\"result\":\"${result}\"}"

  {
    printf '\nMIRROROS-REPORT-BEGIN %s\n' "$MIRROROS_RUN_ID"
    printf '%s\n' "$body"
    printf 'MIRROROS-REPORT-END %s\n' "$MIRROROS_RUN_ID"
  } > "$SERIAL_DEVICE"
}

check_uefi_mode
check_root_shell
check_native_install_tools
check_ipv4_address
check_default_route
check_dns_resolution
check_https_request
emit_report
