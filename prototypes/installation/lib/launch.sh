#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared across the harness libraries sourced by harness.sh.
# Prototype harness: two-boot QEMU launch.
# Adapted from vm/reference/lib/launch.sh (not sourced). The VM shape comes from reference-vm.conf.
# Boot 1: the unmodified ISO, the NoCloud medium, and the fresh disk. Boot 2: the installed disk only.

LAUNCH_POLL_SECONDS=1
LAUNCH_QEMU_COMMAND=()
LAUNCH_QEMU_PID=''
LAUNCH_QEMU_STATUS=''
LAUNCH_OUTCOME=''
LAUNCH_DURATION_SECONDS=''
LAUNCH_SERIAL_PATH=''
LAUNCH_DISK_PATH=''
LAUNCH_VARS_PATH=''
LAUNCH_QEMU_VERSION=''

# Creates the fresh sparse disk and the fresh per-run UEFI variable store.
launch_prepare_disk() {
  local build_run_dir="$1"

  LAUNCH_DISK_PATH="${build_run_dir}/disk.qcow2"
  LAUNCH_VARS_PATH="${build_run_dir}/OVMF_VARS.fd"
  if ! qemu-img create -q -f "$REFERENCE_VM_DISK_FORMAT" "$LAUNCH_DISK_PATH" "$REFERENCE_VM_DISK_SIZE"; then
    printf '%s\n' 'MirrorOS prototype: creating the reference VM disk failed.' >&2
    return 5
  fi
  if ! cp --no-preserve=mode -- "$PROTO_OVMF_VARS_PATH" "$LAUNCH_VARS_PATH"; then
    printf '%s\n' 'MirrorOS prototype: creating the per-run UEFI variable store failed.' >&2
    return 5
  fi
  chmod 600 -- "$LAUNCH_DISK_PATH" "$LAUNCH_VARS_PATH"
}

# QEMU option values treat a comma as a separator; a literal comma is written as two commas.
launch_escape_option_value() {
  printf '%s' "${1//,/,,}"
}

# Options shared by every boot: the machine, firmware, disk, and the SLIRP NIC without forwarding.
# $1 is the disk boot index. The serial option is appended by the caller.
launch_common_options() {
  local disk_bootindex="$1"
  local ovmf_code_path
  local vars_path
  local disk_path

  ovmf_code_path="$(launch_escape_option_value "$PROTO_OVMF_CODE_PATH")"
  vars_path="$(launch_escape_option_value "$LAUNCH_VARS_PATH")"
  disk_path="$(launch_escape_option_value "$LAUNCH_DISK_PATH")"
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
    -drive "if=pflash,format=raw,unit=0,readonly=on,file=${ovmf_code_path}"
    -drive "if=pflash,format=raw,unit=1,file=${vars_path}"
    -drive "if=none,id=disk0,format=${REFERENCE_VM_DISK_FORMAT},file=${disk_path}"
    -device "virtio-blk-pci,drive=disk0,bootindex=${disk_bootindex}"
    -netdev "$REFERENCE_VM_NETDEV"
    -device "$REFERENCE_VM_NIC"
  )
}

# Boot 1. q35 has two IDE buses: the ISO uses bus=ide.0 and the seed bus=ide.1 (01-05 fix).
# Arguments: ISO path, seed path, serial log path.
launch_build_install_command() {
  local iso_path
  local seed_path

  iso_path="$(launch_escape_option_value "$1")"
  seed_path="$(launch_escape_option_value "$2")"
  LAUNCH_SERIAL_PATH="$3"
  launch_common_options 2
  LAUNCH_QEMU_COMMAND+=(
    -serial "file:${LAUNCH_SERIAL_PATH}"
    -drive "if=none,id=iso,media=cdrom,format=raw,readonly=on,file=${iso_path}"
    -device "ide-cd,drive=iso,bus=ide.0,bootindex=1"
    -drive "if=none,id=seed,media=cdrom,format=raw,readonly=on,file=${seed_path}"
    -device "ide-cd,drive=seed,bus=ide.1"
  )
}

# Boot 2: the installed disk only. Argument: serial log path.
launch_build_verify_command() {
  LAUNCH_SERIAL_PATH="$1"
  launch_common_options 1
  LAUNCH_QEMU_COMMAND+=(-serial "file:${LAUNCH_SERIAL_PATH}")
}

# Attended boot: the serial console is the terminal, and its traffic is also logged. Ctrl-C is passed
# to the guest, and Ctrl-A x quits QEMU. Arguments: ISO path, seed path, serial log path.
launch_build_attended_command() {
  local iso_path
  local seed_path

  iso_path="$(launch_escape_option_value "$1")"
  seed_path="$(launch_escape_option_value "$2")"
  LAUNCH_SERIAL_PATH="$3"
  launch_common_options 2
  LAUNCH_QEMU_COMMAND+=(
    -chardev "stdio,id=ser0,mux=on,signal=off,logfile=$(launch_escape_option_value "$LAUNCH_SERIAL_PATH")"
    -serial chardev:ser0
    -drive "if=none,id=iso,media=cdrom,format=raw,readonly=on,file=${iso_path}"
    -device "ide-cd,drive=iso,bus=ide.0,bootindex=1"
    -drive "if=none,id=seed,media=cdrom,format=raw,readonly=on,file=${seed_path}"
    -device "ide-cd,drive=seed,bus=ide.1"
  )
}

launch_collect_versions() {
  if ! LAUNCH_QEMU_VERSION="$(qemu-system-x86_64 --version 2>/dev/null | head -n 1)" || [[ -z "$LAUNCH_QEMU_VERSION" ]]; then
    LAUNCH_QEMU_VERSION='unknown QEMU version'
  fi
}

launch_qemu_running() {
  local state

  [[ -n "$LAUNCH_QEMU_PID" ]] && kill -0 "$LAUNCH_QEMU_PID" 2>/dev/null || return 1
  state="$(awk '{ print $3 }' "/proc/${LAUNCH_QEMU_PID}/stat" 2>/dev/null)" || return 1
  [[ "$state" != 'Z' ]]
}

# Starts the owned QEMU in the background. Argument: diagnostics log path.
launch_start() {
  local diagnostics_path="$1"

  LAUNCH_QEMU_PID=''
  LAUNCH_QEMU_STATUS=''
  : > "$LAUNCH_SERIAL_PATH" && : > "$diagnostics_path" || return 5
  chmod 600 -- "$LAUNCH_SERIAL_PATH" "$diagnostics_path"
  "${LAUNCH_QEMU_COMMAND[@]}" < /dev/null > /dev/null 2>> "$diagnostics_path" &
  LAUNCH_QEMU_PID=$!
}

# Runs the attended QEMU in the foreground on the caller's terminal.
launch_run_attended() {
  local status=0

  : > "$LAUNCH_SERIAL_PATH" || return 5
  chmod 600 -- "$LAUNCH_SERIAL_PATH"
  "${LAUNCH_QEMU_COMMAND[@]}" || status=$?
  LAUNCH_QEMU_STATUS="$status"
}

# Extracts the lines between run-bound markers (the last complete block) into a file.
# Arguments: serial log, marker name, run ID, output path.
launch_extract_block() {
  local serial_path="$1"
  local marker="$2"
  local run_id="$3"
  local output_path="$4"

  [[ -f "$serial_path" ]] || return 1
  awk -v begin="${marker}-BEGIN ${run_id}" -v end="${marker}-END ${run_id}" '
    { sub(/\r$/, "") }
    $0 == begin { collecting = 1; block = ""; next }
    collecting && $0 == end { last = block; found = 1; collecting = 0; next }
    collecting { block = block $0 "\n" }
    END { if (found) printf "%s", last; else exit 1 }
  ' "$serial_path" > "$output_path" || { rm -f -- "$output_path"; return 1; }
  chmod 600 -- "$output_path"
}

# A single-line report: the block must contain exactly one line.
launch_extract_report() {
  local serial_path="$1"
  local marker="$2"
  local run_id="$3"
  local output_path="$4"

  launch_extract_block "$serial_path" "$marker" "$run_id" "$output_path" || return 1
  if [[ "$(wc -l < "$output_path")" -ne 1 ]]; then
    rm -f -- "$output_path"
    return 1
  fi
}

# Boot 1: waits for the guest to power off (QEMU exit) or for the deadline.
# Sets LAUNCH_OUTCOME to exited or deadline. Never stops QEMU.
launch_wait_exit() {
  local deadline_seconds="$1"
  local started="$SECONDS"

  LAUNCH_OUTCOME=''
  while launch_qemu_running; do
    if [[ $((SECONDS - started)) -ge "$deadline_seconds" ]]; then
      LAUNCH_OUTCOME='deadline'
      LAUNCH_DURATION_SECONDS=$((SECONDS - started))
      return 0
    fi
    sleep "$LAUNCH_POLL_SECONDS"
  done
  if wait "$LAUNCH_QEMU_PID"; then LAUNCH_QEMU_STATUS=0; else LAUNCH_QEMU_STATUS=$?; fi
  LAUNCH_OUTCOME='exited'
  LAUNCH_DURATION_SECONDS=$((SECONDS - started))
}

# Boot 2: waits for the run-bound report, QEMU exit, or the deadline.
# Sets LAUNCH_OUTCOME to report, qemu_exited, or deadline. Never stops QEMU.
# Arguments: run ID, report path, deadline seconds, optional marker name (default MIRROROS-REPORT).
launch_wait_report() {
  local run_id="$1"
  local report_path="$2"
  local deadline_seconds="$3"
  local marker="${4:-MIRROROS-REPORT}"
  local started="$SECONDS"

  LAUNCH_OUTCOME=''
  while true; do
    if launch_extract_report "$LAUNCH_SERIAL_PATH" "$marker" "$run_id" "$report_path"; then
      LAUNCH_OUTCOME='report'
      break
    fi
    if ! launch_qemu_running; then
      if wait "$LAUNCH_QEMU_PID"; then LAUNCH_QEMU_STATUS=0; else LAUNCH_QEMU_STATUS=$?; fi
      # A report written just before exit must not be lost.
      if launch_extract_report "$LAUNCH_SERIAL_PATH" "$marker" "$run_id" "$report_path"; then
        LAUNCH_OUTCOME='report'
      else
        LAUNCH_OUTCOME='qemu_exited'
      fi
      break
    fi
    if [[ $((SECONDS - started)) -ge "$deadline_seconds" ]]; then
      LAUNCH_OUTCOME='deadline'
      break
    fi
    sleep "$LAUNCH_POLL_SECONDS"
  done
  LAUNCH_DURATION_SECONDS=$((SECONDS - started))
}
