#!/usr/bin/bash

LAUNCH_POLL_SECONDS=1
LAUNCH_QEMU_COMMAND=()
LAUNCH_QEMU_PID=''
LAUNCH_QEMU_STATUS=''
LAUNCH_OUTCOME=''
LAUNCH_VERDICT=''
LAUNCH_SERIAL_PATH=''
LAUNCH_REPORT_PATH=''
LAUNCH_DISK_PATH=''
LAUNCH_VARS_PATH=''
LAUNCH_QEMU_VERSION=''
LAUNCH_OVMF_VERSION=''
LAUNCH_VM_CONFIGURATION_JSON=''

launch_load_configuration() {
  local config_path="$1"
  local name

  if [[ ! -f "$config_path" || ! -r "$config_path" ]]; then
    printf 'MirrorOS test: incomplete or damaged checkout; the reference VM configuration is missing: %s\n' \
      "$config_path" >&2
    return 6
  fi
  # shellcheck disable=SC1090 # The versioned configuration path is resolved by the caller.
  if ! source "$config_path"; then
    printf 'MirrorOS test: the reference VM configuration could not be loaded: %s\n' "$config_path" >&2
    return 6
  fi
  for name in REFERENCE_VM_CONFIG_VERSION REFERENCE_VM_MACHINE REFERENCE_VM_ACCEL REFERENCE_VM_CPU \
    REFERENCE_VM_SMP REFERENCE_VM_MEMORY_MIB REFERENCE_VM_DISK_SIZE REFERENCE_VM_DISK_FORMAT \
    REFERENCE_VM_NETDEV REFERENCE_VM_NIC REFERENCE_VM_NOCLOUD_LABEL REFERENCE_VM_GLOBAL_DEADLINE_SECONDS \
    REFERENCE_VM_GUEST_HTTPS_URL REFERENCE_VM_GUEST_HTTPS_TIMEOUT_SECONDS; do
    if [[ -z "${!name:-}" ]]; then
      printf 'MirrorOS test: the reference VM configuration does not define %s.\n' "$name" >&2
      return 6
    fi
  done
}

# Creates the fresh sparse disk and the fresh per-run UEFI variable store.
launch_prepare_disk() {
  local build_run_dir="$1"

  LAUNCH_DISK_PATH="${build_run_dir}/disk.qcow2"
  LAUNCH_VARS_PATH="${build_run_dir}/OVMF_VARS.fd"
  if ! qemu-img create -q -f "$REFERENCE_VM_DISK_FORMAT" "$LAUNCH_DISK_PATH" "$REFERENCE_VM_DISK_SIZE"; then
    printf '%s\n' 'MirrorOS test: creating the reference VM disk failed.' >&2
    return 5
  fi
  if ! cp --no-preserve=mode -- "$PRECONDITIONS_OVMF_VARS_PATH" "$LAUNCH_VARS_PATH"; then
    printf '%s\n' 'MirrorOS test: creating the per-run UEFI variable store failed.' >&2
    return 5
  fi
  chmod 600 -- "$LAUNCH_DISK_PATH" "$LAUNCH_VARS_PATH"
}

# QEMU option values treat a comma as a separator; a literal comma is written as two commas.
launch_escape_option_value() {
  printf '%s' "${1//,/,,}"
}

# Builds the fixed QEMU command. Only the ISO, the NoCloud medium, the empty disk, firmware,
# one SLIRP NIC without forwarding, and the serial file are given to the guest.
launch_build_command() {
  local iso_path
  local seed_path
  local evidence_run_dir="$3"
  local ovmf_code_path
  local vars_path
  local disk_path

  iso_path="$(launch_escape_option_value "$1")"
  seed_path="$(launch_escape_option_value "$2")"
  ovmf_code_path="$(launch_escape_option_value "$PRECONDITIONS_OVMF_CODE_PATH")"
  vars_path="$(launch_escape_option_value "$LAUNCH_VARS_PATH")"
  disk_path="$(launch_escape_option_value "$LAUNCH_DISK_PATH")"
  LAUNCH_SERIAL_PATH="${evidence_run_dir}/guest-serial.log"
  LAUNCH_QEMU_COMMAND=(
    qemu-system-x86_64
    -machine "${REFERENCE_VM_MACHINE},accel=${REFERENCE_VM_ACCEL}"
    -cpu "$REFERENCE_VM_CPU"
    -smp "$REFERENCE_VM_SMP"
    -m "$REFERENCE_VM_MEMORY_MIB"
    -display none
    -nodefaults
    -no-user-config
    -monitor none
    -serial "file:${LAUNCH_SERIAL_PATH}"
    -drive "if=pflash,format=raw,unit=0,readonly=on,file=${ovmf_code_path}"
    -drive "if=pflash,format=raw,unit=1,file=${vars_path}"
    -drive "if=none,id=iso,media=cdrom,format=raw,readonly=on,file=${iso_path}"
    -device "ide-cd,drive=iso,bus=ide.0,bootindex=1"
    -drive "if=none,id=seed,media=cdrom,format=raw,readonly=on,file=${seed_path}"
    -device "ide-cd,drive=seed,bus=ide.1"
    -drive "if=none,id=disk0,format=${REFERENCE_VM_DISK_FORMAT},file=${disk_path}"
    -device "virtio-blk-pci,drive=disk0,bootindex=2"
    -netdev "$REFERENCE_VM_NETDEV"
    -device "$REFERENCE_VM_NIC"
  )
}

launch_describe_configuration() {
  # shellcheck disable=SC2034 # Read by the qualification orchestrator.
  LAUNCH_VM_CONFIGURATION_JSON="$(printf '{"config_version":%s,"machine":"%s","accel":"%s","cpu":"%s","smp":%s,"memory_mib":%s,"disk":{"format":"%s","size":"%s","interface":"virtio-blk","fresh_per_run":true},"network":{"netdev":"%s","nic":"%s","port_forwarding":false},"firmware":{"code":"%s","vars":"fresh per-run copy of %s","secure_boot":false},"display":"none","serial":"file","nocloud_label":"%s","global_deadline_seconds":%s,"guest_https_url":"%s","guest_https_timeout_seconds":%s}' \
    "$REFERENCE_VM_CONFIG_VERSION" "$REFERENCE_VM_MACHINE" "$REFERENCE_VM_ACCEL" "$REFERENCE_VM_CPU" \
    "$REFERENCE_VM_SMP" "$REFERENCE_VM_MEMORY_MIB" "$REFERENCE_VM_DISK_FORMAT" "$REFERENCE_VM_DISK_SIZE" \
    "$REFERENCE_VM_NETDEV" "$REFERENCE_VM_NIC" "$PRECONDITIONS_OVMF_CODE_PATH" "$PRECONDITIONS_OVMF_VARS_PATH" \
    "$REFERENCE_VM_NOCLOUD_LABEL" "$REFERENCE_VM_GLOBAL_DEADLINE_SECONDS" "$REFERENCE_VM_GUEST_HTTPS_URL" \
    "$REFERENCE_VM_GUEST_HTTPS_TIMEOUT_SECONDS")"
}

launch_collect_versions() {
  local ovmf_sha
  local ovmf_package=''

  if ! LAUNCH_QEMU_VERSION="$(qemu-system-x86_64 --version 2>/dev/null | head -n 1)" || [[ -z "$LAUNCH_QEMU_VERSION" ]]; then
    LAUNCH_QEMU_VERSION='unknown QEMU version'
  fi
  if command -v pacman >/dev/null 2>&1; then
    ovmf_package="$(pacman -Qo "$PRECONDITIONS_OVMF_CODE_PATH" 2>/dev/null | awk '{ print $(NF-1), $NF }')" || ovmf_package=''
  fi
  if ! ovmf_sha="$(sha256sum -- "$PRECONDITIONS_OVMF_CODE_PATH" 2>/dev/null)" || [[ -z "$ovmf_sha" ]]; then
    ovmf_sha='unavailable'
  fi
  # shellcheck disable=SC2034 # Read by the qualification orchestrator.
  LAUNCH_OVMF_VERSION="${ovmf_package:-unknown package} (${PRECONDITIONS_OVMF_CODE_PATH##*/} sha256 ${ovmf_sha%% *})"
}

launch_qemu_running() {
  local state

  [[ -n "$LAUNCH_QEMU_PID" ]] && kill -0 "$LAUNCH_QEMU_PID" 2>/dev/null || return 1
  state="$(awk '{ print $3 }' "/proc/${LAUNCH_QEMU_PID}/stat" 2>/dev/null)" || return 1
  [[ "$state" != 'Z' ]]
}

# Starts the owned QEMU process in the background. Stopping it is the caller's responsibility.
launch_start() {
  local evidence_run_dir="$1"
  local diagnostics_path="${evidence_run_dir}/qemu-diagnostics.log"

  : > "$LAUNCH_SERIAL_PATH" && : > "$diagnostics_path" || return 5
  chmod 600 -- "$LAUNCH_SERIAL_PATH" "$diagnostics_path"
  "${LAUNCH_QEMU_COMMAND[@]}" < /dev/null > /dev/null 2>> "$diagnostics_path" &
  LAUNCH_QEMU_PID=$!
}

# Extracts the single-line report bound to the run ID from the serial file.
launch_extract_report() {
  local serial_path="$1"
  local run_id="$2"
  local report_path="$3"
  local body

  [[ -f "$serial_path" ]] || return 1
  body="$(awk -v id="$run_id" '
    { sub(/\r$/, "") }
    $0 == "MIRROROS-REPORT-BEGIN " id { collecting = 1; line = ""; count = 0; next }
    collecting && $0 == "MIRROROS-REPORT-END " id { if (count == 1) { last = line; found = 1 } collecting = 0; next }
    collecting { line = $0; count++ }
    END { if (found) print last; else exit 1 }
  ' "$serial_path")" || return 1
  printf '%s\n' "$body" > "$report_path" && chmod 600 -- "$report_path"
}

# Waits for the run-bound report, QEMU exit, or the global deadline measured from this call.
# Sets LAUNCH_OUTCOME to report, qemu_exited, or deadline. Never stops QEMU.
launch_wait() {
  local run_id="$1"
  local build_run_dir="$2"
  local deadline_seconds="$3"
  local started="$SECONDS"

  LAUNCH_REPORT_PATH="${build_run_dir}/guest-report.json"
  while true; do
    if launch_extract_report "$LAUNCH_SERIAL_PATH" "$run_id" "$LAUNCH_REPORT_PATH"; then
      LAUNCH_OUTCOME='report'
      return 0
    fi
    if ! launch_qemu_running; then
      if wait "$LAUNCH_QEMU_PID"; then LAUNCH_QEMU_STATUS=0; else LAUNCH_QEMU_STATUS=$?; fi
      # A report written just before exit must not be lost.
      if launch_extract_report "$LAUNCH_SERIAL_PATH" "$run_id" "$LAUNCH_REPORT_PATH"; then
        LAUNCH_OUTCOME='report'
      else
        LAUNCH_OUTCOME='qemu_exited'
      fi
      return 0
    fi
    if [[ $((SECONDS - started)) -ge "$deadline_seconds" ]]; then
      LAUNCH_OUTCOME='deadline'
      return 0
    fi
    sleep "$LAUNCH_POLL_SECONDS"
  done
}

# Maps the wait outcome and the validated report to a normalized status.
# 0 guest checks passed, 4 a check failed, 5 no accepted report (deadline, QEMU exit, invalid report).
launch_evaluate() {
  local documents_cli="$1"
  local run_id="$2"
  local status

  case "$LAUNCH_OUTCOME" in
    report) ;;
    deadline)
      printf 'MirrorOS test: the %s-second global deadline expired before a guest report arrived; not qualified.\n' \
        "$REFERENCE_VM_GLOBAL_DEADLINE_SECONDS" >&2
      return 5
      ;;
    qemu_exited)
      printf 'MirrorOS test: QEMU exited (status %s) before a guest report arrived; not qualified.\n' \
        "${LAUNCH_QEMU_STATUS:-unknown}" >&2
      return 5
      ;;
    *)
      printf '%s\n' 'MirrorOS test: internal contract violation: no launch outcome was recorded.' >&2
      return 6
      ;;
  esac

  # shellcheck disable=SC2034 # Read by the qualification orchestrator.
  if LAUNCH_VERDICT="$(node "$documents_cli" validate-report --report "$LAUNCH_REPORT_PATH" --run-id "$run_id" 2>/dev/null)"; then
    status=0
  else
    status=$?
  fi
  case "$status" in
    0) ;;
    4) printf '%s\n' 'MirrorOS test: the guest reported a failed check; not qualified.' >&2 ;;
    5) printf '%s\n' 'MirrorOS test: the guest report is incomplete, inconsistent, or not bound to this run; not qualified.' >&2 ;;
    *) printf 'MirrorOS test: guest report validation failed internally (status %s).\n' "$status" >&2 ;;
  esac
  return "$status"
}
