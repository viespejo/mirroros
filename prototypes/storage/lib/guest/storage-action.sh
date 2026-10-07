#!/usr/bin/bash
# Storage prototype action runner, executed on the installed system by mirroros-storage-action.service.
# Prototype-only (known prototype contamination, like the 02-01 verification unit).
#
# Every disk boot of a storage run attaches the run's NoCloud medium. This script mounts it, reads
# the action from seed.env, performs it, and writes one run-bound JSON report to the serial console
# between MIRROROS-ACTION marker lines. Without the medium it does nothing, so a system that boots
# without it (for example the confirm-failure or an attended boot) is not touched.
#
# Actions (MIRROROS_ACTION):
#   prepare     write the /home marker, then power off
#   damage      install the synthetic damage package (MIRROROS_DAMAGE=d1|d2) with pacman -U, power off
#   post-check  check the /home marker and the journal retention, then power off
#   hibernate   request hibernation; after a resume, report it and power off
set -u

ENV_FILE=/etc/mirroros-proto/storage.env
SERIAL_DEVICE=/dev/ttyS0
SEED_MOUNT=/run/mirroros-seed
STATE_DIR=/var/lib/mirroros-proto
HIBERNATE_STATE="${STATE_DIR}/hibernate-token"
MARKER_FILE=/home/mirroros/.mirroros-marker
SEED_WAIT_SECONDS=30
HIBERNATE_WAIT_SECONDS=180

# shellcheck disable=SC1090 # Written into the target by mirroros_storage_install_support.
source "$ENV_FILE" || exit 1
: "${MIRROROS_SEED_LABEL:?}" "${MIRROROS_STORAGE_VARIANT:?}"

sanitize() {
  local text="${1//[^A-Za-z0-9 ._:\/=,+@-]/_}"
  printf '%s' "${text:0:240}"
}

# Prints one report. Arguments: phase, then key=value pairs. A value that is exactly true, false,
# null, or an unsigned integer is written as is; anything else is written as a sanitized string.
emit() {
  local phase="$1"
  local body=''
  local pair
  local key
  local value

  shift
  for pair in "$@"; do
    key="${pair%%=*}"
    value="${pair#*=}"
    [[ "$value" =~ ^([0-9]+|true|false|null)$ ]] || value="\"$(sanitize "$value")\""
    body+=",\"${key}\":${value}"
  done
  {
    printf '\nMIRROROS-ACTION-BEGIN %s\n' "$MIRROROS_RUN_ID"
    printf '{"schema_version":1,"kind":"action","run_id":"%s","action":"%s","variant":"%s","phase":"%s","boot_id":"%s"%s}\n' \
      "$MIRROROS_RUN_ID" "$MIRROROS_ACTION" "$MIRROROS_STORAGE_VARIANT" "$phase" \
      "$(< /proc/sys/kernel/random/boot_id)" "$body"
    printf 'MIRROROS-ACTION-END %s\n' "$MIRROROS_RUN_ID"
  } > "$SERIAL_DEVICE"
}

mount_seed() {
  local deadline=$((SECONDS + SEED_WAIT_SECONDS))
  local device

  mkdir -p -- "$SEED_MOUNT"
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    if device="$(blkid -L "$MIRROROS_SEED_LABEL" 2> /dev/null)" && [[ -n "$device" ]] && \
      mount -o ro -- "$device" "$SEED_MOUNT" 2> /dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

snapshot_count() {
  if [[ "$MIRROROS_STORAGE_VARIANT" == 'control' ]] || ! command -v snapper > /dev/null 2>&1; then
    printf 'null'
    return 0
  fi
  snapper --csvout --no-headers -c root list --columns number 2> /dev/null | grep -c '^[0-9]' || true
}

power_off() {
  sync
  systemctl --no-block poweroff
}

action_prepare() {
  local written=false

  if printf '%s\n' "$MIRROROS_MARKER_VALUE" > "$MARKER_FILE" && \
    chown mirroros:mirroros "$MARKER_FILE" && sync; then
    written=true
  fi
  emit completed "marker_written=${written}" "snapshots=$(snapshot_count)"
  power_off
}

action_damage() {
  local package
  local before
  local status=0

  package="$(find "${SEED_MOUNT}/engine/packages" -maxdepth 1 -name "mirroros-damage-${MIRROROS_DAMAGE}-*.pkg.tar.zst" | head -n 1)"
  if [[ -z "$package" ]]; then
    emit completed 'package_found=false'
    power_off
    return 0
  fi
  before="$(snapshot_count)"
  pacman -U --noconfirm --noprogressbar -- "$package" > /dev/null 2>&1 || status=$?
  emit completed "damage=${MIRROROS_DAMAGE}" "pacman_exit=${status}" "snapshots_before=${before}" "snapshots_after=$(snapshot_count)"
  power_off
}

action_post_check() {
  local present=false
  local matches=false
  local boots
  local persistent=false

  if [[ -f "$MARKER_FILE" ]]; then
    present=true
    [[ "$(< "$MARKER_FILE")" == "$MIRROROS_MARKER_VALUE" ]] && matches=true
  fi
  boots="$(journalctl --list-boots --no-pager 2> /dev/null | grep -c . || true)"
  [[ -d /var/log/journal ]] && persistent=true
  emit completed "marker_present=${present}" "marker_matches=${matches}" "journal_boots=${boots}" "journal_persistent=${persistent}"
  power_off
}

# The same process continues after a successful resume: systemd-hibernate.service leaves its
# activating state only when the resumed system carries on, so seeing it end after it was active proves
# the resume. A failed service means the hibernation was refused. A fresh boot that finds the state
# file means the image was not resumed (the boot started from scratch).
action_hibernate() {
  local token
  local state
  local seen_active=false
  local deadline
  local kernel_restored=false

  install -d -m 0700 -- "$STATE_DIR"
  if [[ -f "$HIBERNATE_STATE" ]]; then
    token="$(< "$HIBERNATE_STATE")"
    rm -f -- "$HIBERNATE_STATE"
    emit not_resumed "token=t${token}" "cmdline_resume=$(grep -o 'resume=[^ ]*' /proc/cmdline | tr '\n' ' ')"
    power_off
    return 0
  fi
  token="$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"
  printf '%s\n' "$token" > "$HIBERNATE_STATE" && sync
  emit requesting "token=t${token}" "swap_active=$(swapon --noheadings --show=NAME | tr '\n' ' ')"
  systemctl --no-block hibernate
  deadline=$((SECONDS + HIBERNATE_WAIT_SECONDS))
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    state="$(systemctl show --property=ActiveState --value systemd-hibernate.service 2> /dev/null)"
    # The process can be frozen before it ever sees the service activating; the sleep message proves the resume.
    if journalctl -b --no-pager 2> /dev/null | grep -qE "System returned from sleep operation 'hibernate'|PM: (hibernation: )?Image restored successfully"; then
      seen_active=true
      state=inactive
      break
    fi
    case "$state" in
      activating | active) seen_active=true ;;
      failed) break ;;
      inactive) [[ "$seen_active" == 'false' ]] || break ;;
      *) ;;
    esac
    sleep 1
  done
  rm -f -- "$HIBERNATE_STATE"
  if journalctl -k --no-pager 2> /dev/null | grep -qE 'PM: (hibernation: )?Image restored successfully'; then
    kernel_restored=true
  fi
  if [[ "$seen_active" == 'true' && "$state" == 'inactive' ]]; then
    emit resumed "token=t${token}" "kernel_image_restored=${kernel_restored}"
  else
    emit not_hibernated "token=t${token}" "service_state=${state}" "waited_seconds=${HIBERNATE_WAIT_SECONDS}"
  fi
  power_off
}

main() {
  mount_seed || exit 0
  # shellcheck disable=SC1091 # Written by the host harness on the NoCloud medium.
  source "${SEED_MOUNT}/seed.env" || exit 0
  : "${MIRROROS_RUN_ID:?}"
  [[ -n "${MIRROROS_ACTION:-}" ]] || exit 0
  case "$MIRROROS_ACTION" in
    prepare) action_prepare ;;
    damage) action_damage ;;
    post-check) action_post_check ;;
    hibernate) action_hibernate ;;
    *) emit unknown_action ;;
  esac
}

main "$@"
