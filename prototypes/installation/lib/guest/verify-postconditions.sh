#!/usr/bin/bash
# Postcondition checks on the installed system (boot 2). Installed by each engine's install script
# through mirroros_proto_install_verifier and run once by mirroros-proto-verify.service.
# Read-only: it changes nothing. The only output is one JSON report on the serial console, wrapped
# in run-bound marker lines. This unit is identical for both engines and is known prototype
# contamination: it exists only in prototype installations.
set -u

ENV_FILE=/etc/mirroros-proto/verify.env
# shellcheck disable=SC1090 # Written into the target by mirroros_proto_install_verifier.
source "$ENV_FILE" || exit 1
: "${MIRROROS_RUN_ID:?}" "${MIRROROS_HTTPS_URL:?}" "${MIRROROS_HTTPS_TIMEOUT_SECONDS:?}"

NETWORK_WAIT_SECONDS=60
SERIAL_DEVICE=/dev/ttyS0
EXPECTED_HOSTNAME='mirroros-ref'
EXPECTED_USER='mirroros'
EXPECTED_TIMEZONE='Europe/Madrid'
EXPECTED_SWAP_BYTES=4294967296
EXPECTED_ESP_BYTES=1073741824
ESP_TOLERANCE_BYTES=2097152
ESP_PARTITION_TYPE='c12a7328-f81f-11d2-ba4b-00a0c93ec93b'
SELECTED_ENTRY_VARIABLE='/sys/firmware/efi/efivars/LoaderEntrySelected-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f'

declare -a CHECK_IDS=()
declare -A CHECK_STATUS=()
declare -A CHECK_DETAIL=()
HTTP_STATUS='null'
TLS_VERIFIED='false'
ROOT_DEV=''
ROOT_UUID=''
ESP_DEV=''
DISK=''
SWAP_OFFSET=''
DEFAULT_ENTRY_FILE=''

sanitize() {
  local text="${1//[^A-Za-z0-9 ._:\/=,+@-]/_}"
  printf '%s' "${text:0:240}"
}

record() {
  CHECK_IDS+=("$1")
  CHECK_STATUS[$1]="$2"
  CHECK_DETAIL[$1]="$(sanitize "$3")"
}

pass() { record "$1" passed "$2"; }
fail() { record "$1" failed "$2"; }

# Records passed or failed according to the status of the command after the detail arguments.
verdict() {
  local id="$1"
  local ok_detail="$2"
  local bad_detail="$3"
  shift 3
  if "$@" > /dev/null 2>&1; then pass "$id" "$ok_detail"; else fail "$id" "$bad_detail"; fi
}

wait_for() {
  local deadline=$((SECONDS + NETWORK_WAIT_SECONDS))

  while ! "$@" > /dev/null 2>&1; do
    [[ "$SECONDS" -lt "$deadline" ]] || return 1
    sleep 2
  done
}

has_default_route() { [[ -n "$(ip -4 route show default 2> /dev/null)" ]]; }
resolves_archlinux() { [[ -n "$(getent ahostsv4 archlinux.org 2> /dev/null)" ]]; }

gather_facts() {
  local disk_name

  ROOT_DEV="$(findmnt -no SOURCE / 2> /dev/null)"
  ROOT_UUID="$(findmnt -no UUID / 2> /dev/null)"
  ESP_DEV="$(findmnt -no SOURCE /boot 2> /dev/null)"
  disk_name="$(lsblk -no PKNAME "$ROOT_DEV" 2> /dev/null | head -n 1)"
  [[ -z "$disk_name" ]] || DISK="/dev/${disk_name}"
  SWAP_OFFSET="$(filefrag -v /swapfile 2> /dev/null | awk '$1 == "0:" { gsub(/\./, "", $4); print $4; exit }')"
}

entry_options() {
  sed -n 's/^options[[:space:]]\{1,\}//p' "$1" | head -n 1
}

# ---- storage ----------------------------------------------------------------------------------

check_storage() {
  local pttype
  local partitions
  local esp_fstype
  local esp_size
  local esp_type
  local root_fstype
  local bad_fstab
  local uuid_lines
  local swap_lines

  pttype="$(lsblk -dno PTTYPE "$DISK" 2> /dev/null)"
  partitions="$(lsblk -nlo TYPE "$DISK" 2> /dev/null | grep -c '^part$')"
  if [[ "$pttype" == 'gpt' ]]; then pass storage_gpt 'partition table is GPT'; else fail storage_gpt "partition table is ${pttype:-unknown}"; fi
  if [[ "$partitions" -eq 2 ]]; then pass storage_two_partitions 'exactly two partitions'; else fail storage_two_partitions "${partitions} partitions"; fi

  esp_fstype="$(findmnt -no FSTYPE /boot 2> /dev/null)"
  esp_size="$(lsblk -bdno SIZE "$ESP_DEV" 2> /dev/null)"
  esp_type="$(lsblk -dno PARTTYPE "$ESP_DEV" 2> /dev/null | tr '[:upper:]' '[:lower:]')"
  if [[ "$esp_fstype" == 'vfat' && "$esp_type" == "$ESP_PARTITION_TYPE" && "$esp_size" =~ ^[0-9]+$ ]] && \
    [[ "$esp_size" -ge $((EXPECTED_ESP_BYTES - ESP_TOLERANCE_BYTES)) && "$esp_size" -le $((EXPECTED_ESP_BYTES + ESP_TOLERANCE_BYTES)) ]]; then
    pass storage_esp "1 GiB FAT32 ESP at /boot, ${esp_size} bytes"
  else
    fail storage_esp "ESP at /boot: fstype ${esp_fstype:-none}, type ${esp_type:-none}, size ${esp_size:-none}"
  fi

  root_fstype="$(findmnt -no FSTYPE / 2> /dev/null)"
  if [[ "$root_fstype" == 'ext4' ]]; then pass storage_root_ext4 'root is ext4'; else fail storage_root_ext4 "root is ${root_fstype:-unknown}"; fi

  bad_fstab="$(awk '!/^[[:space:]]*(#|$)/ && $3 != "swap" && $1 !~ /^UUID=/ { print $1 }' /etc/fstab)"
  uuid_lines="$(awk '!/^[[:space:]]*(#|$)/ && $1 ~ /^UUID=/' /etc/fstab | wc -l)"
  swap_lines="$(awk '!/^[[:space:]]*(#|$)/ && $1 == "/swapfile" && $3 == "swap"' /etc/fstab | wc -l)"
  if [[ -z "$bad_fstab" && "$uuid_lines" -eq 2 && "$swap_lines" -eq 1 ]]; then
    pass storage_fstab_uuid 'fstab lists the root and ESP by UUID and one swapfile entry'
  else
    fail storage_fstab_uuid "fstab: ${uuid_lines} UUID entries, ${swap_lines} swapfile entries, non-UUID: ${bad_fstab:-none}"
  fi
}

# ---- swap and boot ----------------------------------------------------------------------------

check_swap() {
  local size
  local mode

  size="$(stat -c %s /swapfile 2> /dev/null)"
  mode="$(stat -c %a /swapfile 2> /dev/null)"
  if [[ "$size" == "$EXPECTED_SWAP_BYTES" && "$mode" == '600' ]]; then
    pass swap_file "4 GiB /swapfile with mode ${mode}"
  else
    fail swap_file "swapfile size ${size:-none}, mode ${mode:-none}"
  fi
  if swapon --noheadings --show=NAME 2> /dev/null | grep -qx '/swapfile'; then
    pass swap_active '/swapfile is active'
  else
    fail swap_active '/swapfile is not active'
  fi
}

check_boot() {
  local status_output
  local status_code=0
  local selected
  local entry_name
  local options
  local token
  local missing=''
  local linux_path
  local initrd_path
  local extras=''
  local cmdline
  local resume_ok=1

  if [[ -d /sys/firmware/efi ]]; then pass boot_uefi 'guest booted in UEFI mode'; else fail boot_uefi '/sys/firmware/efi is absent'; fi

  status_output="$(bootctl status --no-pager 2>&1)" || status_code=$?
  if [[ "$status_code" -eq 0 ]] && ! grep -qiE 'warning|error|failed|not installed' <<< "$status_output"; then
    pass boot_bootctl_clean 'bootctl status exits 0 without warnings'
  else
    fail boot_bootctl_clean "bootctl status exit ${status_code}: $(grep -iE 'warning|error|failed|not installed' <<< "$status_output" | head -n 1)"
  fi

  if selected="$(tail -c +5 "$SELECTED_ENTRY_VARIABLE" 2> /dev/null | tr -d '\0')" && [[ -n "$selected" ]]; then
    entry_name="$selected"
    [[ -f "/boot/loader/entries/${entry_name}" ]] || entry_name="${selected}.conf"
    DEFAULT_ENTRY_FILE="/boot/loader/entries/${entry_name}"
  fi
  if [[ -f "$DEFAULT_ENTRY_FILE" ]]; then
    linux_path="$(sed -n 's/^linux[[:space:]]\{1,\}//p' "$DEFAULT_ENTRY_FILE" | head -n 1)"
    [[ -f "/boot${linux_path}" ]] || missing+=" ${linux_path:-linux}"
    while read -r initrd_path; do
      [[ -n "$initrd_path" && -f "/boot${initrd_path}" ]] || missing+=" ${initrd_path:-initrd}"
    done < <(sed -n 's/^initrd[[:space:]]\{1,\}//p' "$DEFAULT_ENTRY_FILE")
    if [[ -z "$missing" ]]; then
      pass boot_default_entry_files "default entry ${entry_name} has its kernel and initramfs on the ESP"
    else
      fail boot_default_entry_files "default entry ${entry_name} is missing:${missing}"
    fi
  else
    fail boot_default_entry_files "the selected boot entry could not be resolved (${selected:-no selection})"
  fi

  if compgen -G '/boot/EFI/Linux/*.efi' > /dev/null; then fail boot_no_uki 'a unified kernel image exists on the ESP'; else pass boot_no_uki 'no unified kernel image'; fi

  if grep -Eq '^[[:space:]]*timeout[[:space:]]+3[[:space:]]*$' /boot/loader/loader.conf 2> /dev/null && \
    grep -Eq '^[[:space:]]*editor[[:space:]]+(no|0|false)[[:space:]]*$' /boot/loader/loader.conf 2> /dev/null; then
    pass boot_loader_conf 'timeout 3 and editor no'
  else
    fail boot_loader_conf 'loader.conf does not set timeout 3 and editor no'
  fi

  verdict boot_update_service 'systemd-boot-update.service is enabled' 'systemd-boot-update.service is not enabled' \
    systemctl is-enabled systemd-boot-update.service

  # Entries are compared by semantics (option tokens), never by file name.
  cmdline="$(< /proc/cmdline)"
  missing=''
  for token in "root=UUID=${ROOT_UUID}" 'rw' "resume=UUID=${ROOT_UUID}" "resume_offset=${SWAP_OFFSET}"; do
    [[ -n "$SWAP_OFFSET" && " ${cmdline} " == *" ${token} "* ]] || missing+=" ${token}"
  done
  [[ " ${cmdline} " != *' quiet '* ]] || missing+=' (unexpected quiet)'
  for token in $cmdline; do
    case "$token" in
      BOOT_IMAGE=* | initrd=* | "root=UUID=${ROOT_UUID}" | rw | "resume=UUID=${ROOT_UUID}" | "resume_offset=${SWAP_OFFSET}") ;;
      *) extras+=" ${token}" ;;
    esac
  done
  if [[ -z "$missing" ]]; then
    pass boot_cmdline "expected tokens present; extra tokens:${extras:- none}"
  else
    fail boot_cmdline "missing or unexpected:${missing}"
  fi

  # The default entry's own options must carry the real resume values.
  if [[ -f "$DEFAULT_ENTRY_FILE" ]]; then
    options=" $(entry_options "$DEFAULT_ENTRY_FILE") "
    [[ -n "$SWAP_OFFSET" && "$options" == *" resume=UUID=${ROOT_UUID} "* && "$options" == *" resume_offset=${SWAP_OFFSET} "* ]] || resume_ok=0
  else
    resume_ok=0
  fi
  if [[ "$resume_ok" -eq 1 ]]; then
    pass swap_resume_match "resume UUID and offset ${SWAP_OFFSET} in the default entry match the swapfile"
  else
    fail swap_resume_match "default entry resume values do not match swapfile offset ${SWAP_OFFSET:-unknown}"
  fi
}

# ---- localization -----------------------------------------------------------------------------

check_localization() {
  local locales

  locales="$(locale -a 2> /dev/null)"
  if grep -qixE 'en_US\.utf-?8' <<< "$locales" && grep -qixE 'es_ES\.utf-?8' <<< "$locales" && \
    grep -qE '^en_US\.UTF-8 UTF-8' /etc/locale.gen && grep -qE '^es_ES\.UTF-8 UTF-8' /etc/locale.gen; then
    pass locale_generated 'en_US.UTF-8 and es_ES.UTF-8 are generated'
  else
    fail locale_generated 'en_US.UTF-8 and es_ES.UTF-8 are not both generated'
  fi
  if grep -qFx 'LANG=en_US.UTF-8' /etc/locale.conf 2> /dev/null && ! grep -qE '^(LC_|LANGUAGE)' /etc/locale.conf 2> /dev/null; then
    pass locale_lang 'LANG=en_US.UTF-8 without LC_ overrides'
  else
    fail locale_lang '/etc/locale.conf is not LANG=en_US.UTF-8 alone'
  fi
  if grep -qFx 'KEYMAP=us' /etc/vconsole.conf 2> /dev/null; then pass console_keymap 'console keymap us'; else fail console_keymap 'console keymap is not us'; fi
}

# ---- time and identity ------------------------------------------------------------------------

check_time_identity() {
  local timezone
  local local_rtc
  local ntp

  timezone="$(timedatectl show --property=Timezone --value 2> /dev/null)"
  local_rtc="$(timedatectl show --property=LocalRTC --value 2> /dev/null)"
  ntp="$(timedatectl show --property=NTP --value 2> /dev/null)"
  if [[ "$timezone" == "$EXPECTED_TIMEZONE" ]]; then pass time_zone "$timezone"; else fail time_zone "time zone ${timezone:-unknown}"; fi
  if [[ "$local_rtc" == 'no' ]]; then pass time_rtc_utc 'hardware clock is UTC'; else fail time_rtc_utc "LocalRTC ${local_rtc:-unknown}"; fi
  if [[ "$ntp" == 'yes' ]] && systemctl is-active --quiet systemd-timesyncd.service; then
    pass time_ntp 'NTP is on and systemd-timesyncd is active'
  else
    fail time_ntp "NTP ${ntp:-unknown}; systemd-timesyncd not active"
  fi
  if [[ "$(hostnamectl hostname --static 2> /dev/null)" == "$EXPECTED_HOSTNAME" ]] && ! grep -qE '^127\.0\.1\.1' /etc/hosts; then
    pass identity_hostname "hostname ${EXPECTED_HOSTNAME} without a 127.0.1.1 entry"
  else
    fail identity_hostname "hostname is $(hostnamectl hostname --static 2> /dev/null) or /etc/hosts has a 127.0.1.1 entry"
  fi
}

# ---- network ----------------------------------------------------------------------------------

check_network() {
  local output
  local curl_status
  local code
  local verify

  verdict network_manager_active 'NetworkManager is active' 'NetworkManager is not active' systemctl is-active --quiet NetworkManager.service
  if wait_for has_default_route; then pass network_default_route 'an IPv4 default route exists'; else fail network_default_route "no IPv4 default route within ${NETWORK_WAIT_SECONDS}s"; fi
  if wait_for resolves_archlinux; then pass network_dns 'archlinux.org resolves'; else fail network_dns "archlinux.org did not resolve within ${NETWORK_WAIT_SECONDS}s"; fi

  if output="$(curl --silent --show-error --proto '=https' --max-time "$MIRROROS_HTTPS_TIMEOUT_SECONDS" \
    --output /dev/null --write-out '%{http_code} %{ssl_verify_result}' "$MIRROROS_HTTPS_URL" 2> /dev/null)"; then
    curl_status=0
  else
    curl_status=$?
  fi
  code="${output%% *}"
  verify="${output##* }"
  if [[ "$code" =~ ^[0-9]{3}$ && "$code" != '000' ]]; then HTTP_STATUS="$((10#$code))"; fi
  if [[ "$curl_status" -eq 0 && "$verify" == '0' ]]; then TLS_VERIFIED='true'; fi
  if [[ "$curl_status" -eq 0 && "$verify" == '0' && "$HTTP_STATUS" == '200' ]]; then
    pass network_https 'HTTPS request returned 200 with a validated certificate'
  else
    fail network_https "curl status ${curl_status}, TLS verify result ${verify}, HTTP status ${HTTP_STATUS}"
  fi
}

# ---- accounts ---------------------------------------------------------------------------------

check_accounts() {
  local root_state
  local user_state
  local primary
  local groups
  local extra_groups=''
  local group
  local shell
  local rights

  root_state="$(passwd -S root 2> /dev/null | awk '{ print $2 }')"
  user_state="$(passwd -S "$EXPECTED_USER" 2> /dev/null | awk '{ print $2 }')"
  if [[ "$root_state" == 'P' ]]; then pass account_root_password 'root has a usable password'; else fail account_root_password "root password state ${root_state:-unknown}"; fi
  if [[ "$user_state" == 'P' ]]; then pass account_user_password "${EXPECTED_USER} has a usable password"; else fail account_user_password "user password state ${user_state:-unknown}"; fi

  primary="$(id -gn "$EXPECTED_USER" 2> /dev/null)"
  groups="$(id -Gn "$EXPECTED_USER" 2> /dev/null)"
  for group in $groups; do
    [[ "$group" == "$primary" ]] || extra_groups+="${extra_groups:+ }${group}"
  done
  if [[ "$extra_groups" == 'wheel' ]]; then pass account_user_groups "${EXPECTED_USER} is in wheel only"; else fail account_user_groups "supplementary groups: ${extra_groups:-none}"; fi

  shell="$(getent passwd "$EXPECTED_USER" | cut -d: -f7)"
  if [[ "$shell" == '/bin/bash' || "$shell" == '/usr/bin/bash' ]]; then pass account_user_shell "shell ${shell}"; else fail account_user_shell "shell ${shell:-unknown}"; fi

  if visudo -c > /dev/null 2>&1 && \
    grep -rqE '^%wheel[[:space:]]+ALL=\(ALL(:ALL)?\)[[:space:]]+ALL[[:space:]]*$' /etc/sudoers.d 2> /dev/null && \
    ! grep -rhE '^[^#]*(NOPASSWD|!tty_tickets)' /etc/sudoers /etc/sudoers.d 2> /dev/null | grep -q .; then
    pass account_sudoers 'a wheel sudoers drop-in passes visudo -c without NOPASSWD or !tty_tickets'
  else
    fail account_sudoers 'sudoers drop-in missing, invalid, or relaxed'
  fi
  rights="$(sudo -n -l -U "$EXPECTED_USER" 2> /dev/null)"
  if grep -qE '\(ALL( : |:)ALL\) ALL' <<< "$rights" && ! grep -q 'NOPASSWD' <<< "$rights"; then
    pass account_sudo_rights "${EXPECTED_USER} may run all commands with a password"
  else
    fail account_sudo_rights "sudo rights for ${EXPECTED_USER} are not (ALL:ALL) ALL with a password"
  fi
}

# ---- system -----------------------------------------------------------------------------------

check_system() {
  local option
  local value
  local bad=''

  if [[ "$(sysctl -n kernel.sysrq 2> /dev/null)" == '1' ]]; then pass system_sysrq 'kernel.sysrq = 1'; else fail system_sysrq "kernel.sysrq is $(sysctl -n kernel.sysrq 2> /dev/null)"; fi

  for option in Color VerbosePkgLists ILoveCandy; do
    [[ "$(pacman-conf "$option" 2> /dev/null)" == "$option" ]] || bad+=" ${option}"
  done
  value="$(pacman-conf ParallelDownloads 2> /dev/null)"
  [[ "$value" == '5' ]] || bad+=" ParallelDownloads=${value:-unset}"
  if [[ -z "$bad" ]]; then pass system_pacman_conf 'Color, ParallelDownloads = 5, VerbosePkgLists, ILoveCandy'; else fail system_pacman_conf "unexpected pacman-conf:${bad}"; fi

  verdict system_fstrim_timer 'fstrim.timer is enabled' 'fstrim.timer is not enabled' systemctl is-enabled fstrim.timer
}

emit_report() {
  local id
  local result=passed
  local checks=''
  local extra
  local body

  for id in "${CHECK_IDS[@]}"; do
    extra=''
    [[ "${CHECK_STATUS[$id]}" == 'passed' ]] || result=failed
    if [[ "$id" == 'network_https' ]]; then
      extra=",\"http_status\":${HTTP_STATUS},\"tls_verified\":${TLS_VERIFIED}"
    fi
    checks+="${checks:+,}\"${id}\":{\"status\":\"${CHECK_STATUS[$id]}\",\"detail\":\"${CHECK_DETAIL[$id]}\"${extra}}"
  done
  body="{\"schema_version\":1,\"kind\":\"postconditions\",\"run_id\":\"${MIRROROS_RUN_ID}\",\"checks\":{${checks}},\"result\":\"${result}\"}"

  {
    printf '\nMIRROROS-REPORT-BEGIN %s\n' "$MIRROROS_RUN_ID"
    printf '%s\n' "$body"
    printf 'MIRROROS-REPORT-END %s\n' "$MIRROROS_RUN_ID"
  } > "$SERIAL_DEVICE"
}

gather_facts
check_storage
check_swap
check_boot
check_localization
check_time_identity
check_network
check_accounts
check_system
emit_report
