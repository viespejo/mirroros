#!/usr/bin/bash

STOP_TERM_WAIT_SECONDS=10
STOP_KILL_WAIT_SECONDS=5
STOP_POLL_SECONDS=0.2
STOP_QEMU_STATE='not_started'
STOP_QEMU_EXIT_STATUS=''
STOP_CLEANUP_OUTCOME='pending'
STOP_CLEANUP_GUIDANCE=''
STOP_CLEANUP_LEFTOVERS=()

# True only while the recorded QEMU PID is alive and still a direct child of this shell, so a
# recycled PID or another VM is never signaled.
stop_cleanup_owned_running() {
  local parent_pid

  launch_qemu_running || return 1
  parent_pid="$(awk '{ print $4 }' "/proc/${LAUNCH_QEMU_PID}/stat" 2>/dev/null)" || return 1
  [[ "$parent_pid" == "$$" ]]
}

stop_cleanup_wait_exit() {
  local seconds="$1"
  local started="$SECONDS"

  while stop_cleanup_owned_running; do
    if [[ $((SECONDS - started)) -ge "$seconds" ]]; then
      return 1
    fi
    sleep "$STOP_POLL_SECONDS"
  done
  return 0
}

stop_cleanup_reap() {
  local status=0

  wait "$LAUNCH_QEMU_PID" 2>/dev/null || status=$?
  # shellcheck disable=SC2034 # Read by the qualification orchestrator.
  STOP_QEMU_EXIT_STATUS="$status"
}

# Stops only the owned QEMU: SIGTERM, wait, SIGKILL, wait. Returns 0 when its exit is confirmed
# (or it never ran) and 1 when the exit cannot be confirmed.
stop_cleanup_stop_qemu() {
  if [[ ! "$LAUNCH_QEMU_PID" =~ ^[0-9]+$ ]]; then
    STOP_QEMU_STATE='not_started'
    return 0
  fi
  if ! stop_cleanup_owned_running; then
    stop_cleanup_reap
    STOP_QEMU_STATE='already_exited'
    return 0
  fi

  kill -TERM -- "$LAUNCH_QEMU_PID" 2>/dev/null || true
  if stop_cleanup_wait_exit "$STOP_TERM_WAIT_SECONDS"; then
    stop_cleanup_reap
    STOP_QEMU_STATE='terminated'
    return 0
  fi

  kill -KILL -- "$LAUNCH_QEMU_PID" 2>/dev/null || true
  if stop_cleanup_wait_exit "$STOP_KILL_WAIT_SECONDS"; then
    stop_cleanup_reap
    STOP_QEMU_STATE='killed'
    return 0
  fi

  STOP_QEMU_STATE='unconfirmed'
  printf 'MirrorOS test: the exit of QEMU process %s could not be confirmed.\n' "$LAUNCH_QEMU_PID" >&2
  return 1
}

# Deletes the run's own disk, UEFI variable store, NoCloud staging and medium, and the build
# directory, but only after QEMU exit is confirmed. Evidence is never touched.
# Sets STOP_CLEANUP_OUTCOME to success, preserved, or failure. Returns 0 only on success.
stop_cleanup_remove_resources() {
  local build_run_dir="$1"
  local run_label="build/reference-vm/${build_run_dir##*/}"

  STOP_CLEANUP_LEFTOVERS=()
  STOP_CLEANUP_GUIDANCE=''

  if [[ "$STOP_QEMU_STATE" == 'unconfirmed' ]]; then
    STOP_CLEANUP_OUTCOME='preserved'
    STOP_CLEANUP_LEFTOVERS=("$run_label")
    STOP_CLEANUP_GUIDANCE="QEMU exit was not confirmed; run resources were preserved. Confirm the QEMU process for this run has exited, then remove only ${run_label}/ and keep the evidence (docs/procedures/test.md)."
    return 1
  fi

  if [[ "$build_run_dir" != */build/reference-vm/* || -L "$build_run_dir" || ! -d "$build_run_dir" ]]; then
    STOP_CLEANUP_OUTCOME='failure'
    STOP_CLEANUP_LEFTOVERS=("$run_label")
    STOP_CLEANUP_GUIDANCE="The run build directory was not a regular directory under build/reference-vm/ and was not removed. Inspect ${run_label} and remove it manually if it is yours (docs/procedures/test.md)."
    return 1
  fi

  if rm -f -- "${build_run_dir}/disk.qcow2" "${build_run_dir}/OVMF_VARS.fd" \
      "${build_run_dir}/nocloud-seed.iso" "${build_run_dir}/guest-report.json" && \
    rm -rf -- "${build_run_dir}/nocloud" && \
    rmdir -- "$build_run_dir"; then
    STOP_CLEANUP_OUTCOME='success'
    return 0
  fi

  # shellcheck disable=SC2034 # Read by the qualification orchestrator.
  STOP_CLEANUP_OUTCOME='failure'
  # shellcheck disable=SC2034 # Read by the qualification orchestrator.
  STOP_CLEANUP_LEFTOVERS=("$run_label")
  # shellcheck disable=SC2034 # Read by the qualification orchestrator.
  STOP_CLEANUP_GUIDANCE="Removing run resources failed. Remove only ${run_label}/ after confirming its QEMU has exited, and keep the evidence (docs/procedures/test.md)."
  return 1
}
