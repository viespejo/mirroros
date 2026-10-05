load vm-support

setup() {
  reference_setup
  STOP_LIB_DIR="${REFERENCE_REPOSITORY_ROOT}/vm/reference/lib"
  STOP_RUN_ID='20261005T120000Z-11111111-2222-4333-8444-555555555555'
  STOP_BUILD_DIR="${REFERENCE_TEST_ROOT}/build/reference-vm/${STOP_RUN_ID}"
  STOP_EVIDENCE_DIR="${REFERENCE_TEST_ROOT}/evidence/reference-vm/${STOP_RUN_ID}"
  STOP_OTHER_PID=''
  mkdir -p -m 700 "$STOP_BUILD_DIR" "$STOP_EVIDENCE_DIR"
}

teardown() {
  if [[ -n "$STOP_OTHER_PID" ]]; then kill "$STOP_OTHER_PID" 2>/dev/null || true; fi
  reference_teardown
}

stop_module() {
  local snippet="$1"
  shift

  /usr/bin/bash -c '
    set -Eeuo pipefail
    umask 077
    source "$1/launch.sh"
    source "$1/stop-cleanup.sh"
    STOP_POLL_SECONDS=0.1
    snippet="$2"
    shift 2
    eval "$snippet"
  ' _ "$STOP_LIB_DIR" "$snippet" "$@"
}

stop_populate_build_dir() {
  : > "${STOP_BUILD_DIR}/disk.qcow2"
  : > "${STOP_BUILD_DIR}/OVMF_VARS.fd"
  : > "${STOP_BUILD_DIR}/nocloud-seed.iso"
  : > "${STOP_BUILD_DIR}/guest-report.json"
  mkdir "${STOP_BUILD_DIR}/nocloud"
  : > "${STOP_BUILD_DIR}/nocloud/user-data"
}

@test "only the owned QEMU receives SIGTERM and its exit is confirmed" {
  sleep 31 >/dev/null 2>&1 3>&- &
  STOP_OTHER_PID=$!

  run stop_module '
    sleep 31 >/dev/null 2>&1 &
    LAUNCH_QEMU_PID=$!
    stop_cleanup_stop_qemu
    printf "%s %s\n" "$STOP_QEMU_STATE" "$LAUNCH_QEMU_PID"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == terminated\ * ]]
  ! kill -0 "${output#* }" 2>/dev/null
  kill -0 "$STOP_OTHER_PID"
}

@test "SIGKILL follows when the owned QEMU ignores SIGTERM" {
  run stop_module '
    STOP_TERM_WAIT_SECONDS=1
    bash -c "trap \"\" TERM; while :; do sleep 0.1; done" >/dev/null 2>&1 &
    LAUNCH_QEMU_PID=$!
    sleep 0.3
    stop_cleanup_stop_qemu
    printf "%s %s\n" "$STOP_QEMU_STATE" "$LAUNCH_QEMU_PID"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == killed\ * ]]
  ! kill -0 "${output#* }" 2>/dev/null
}

@test "a process that is not a child of this shell is never signaled" {
  sleep 31 >/dev/null 2>&1 3>&- &
  STOP_OTHER_PID=$!

  run stop_module '
    LAUNCH_QEMU_PID="$1"
    stop_cleanup_stop_qemu
    printf "%s\n" "$STOP_QEMU_STATE"
  ' "$STOP_OTHER_PID"
  [ "$status" -eq 0 ]
  [ "$output" == 'already_exited' ]
  kill -0 "$STOP_OTHER_PID"
}

@test "a QEMU that was never started needs no stopping" {
  run stop_module '
    stop_cleanup_stop_qemu
    printf "%s\n" "$STOP_QEMU_STATE"
  '
  [ "$status" -eq 0 ]
  [ "$output" == 'not_started' ]
}

@test "an exit that cannot be confirmed preserves resources and reports recovery guidance" {
  stop_populate_build_dir

  run stop_module '
    STOP_TERM_WAIT_SECONDS=1
    STOP_KILL_WAIT_SECONDS=1
    LAUNCH_QEMU_PID=4242
    stop_cleanup_owned_running() { return 0; }
    kill() { :; }
    stop_status=0
    stop_cleanup_stop_qemu 2>/dev/null || stop_status=$?
    cleanup_status=0
    stop_cleanup_remove_resources "$1" || cleanup_status=$?
    printf "%s %s %s %s\n" "$stop_status" "$STOP_QEMU_STATE" "$cleanup_status" "$STOP_CLEANUP_OUTCOME"
    printf "%s\n" "${STOP_CLEANUP_LEFTOVERS[@]}"
    printf "%s\n" "$STOP_CLEANUP_GUIDANCE"
  ' "$STOP_BUILD_DIR"
  [ "$status" -eq 0 ]
  mapfile -t lines <<< "$output"
  [[ "${lines[0]}" == *"1 unconfirmed 1 preserved" ]]
  [ "${lines[1]}" == "build/reference-vm/${STOP_RUN_ID}" ]
  [[ "${lines[2]}" == *'keep the evidence'* ]]
  [ -e "${STOP_BUILD_DIR}/disk.qcow2" ]
  [ -e "${STOP_BUILD_DIR}/OVMF_VARS.fd" ]
  [ -e "${STOP_BUILD_DIR}/nocloud-seed.iso" ]
}

@test "resources are deleted after confirmed exit and evidence is retained" {
  stop_populate_build_dir
  printf 'serial' > "${STOP_EVIDENCE_DIR}/guest-serial.log"

  run stop_module '
    STOP_QEMU_STATE=terminated
    stop_cleanup_remove_resources "$1"
    printf "%s %s\n" "$STOP_CLEANUP_OUTCOME" "${#STOP_CLEANUP_LEFTOVERS[@]}"
  ' "$STOP_BUILD_DIR"
  [ "$status" -eq 0 ]
  [ "$output" == 'success 0' ]
  [ ! -e "$STOP_BUILD_DIR" ]
  [ -f "${STOP_EVIDENCE_DIR}/guest-serial.log" ]
}

@test "unexpected content in the run directory is never deleted" {
  stop_populate_build_dir
  printf 'keep' > "${STOP_BUILD_DIR}/unexpected.txt"

  run stop_module '
    STOP_QEMU_STATE=terminated
    cleanup_status=0
    stop_cleanup_remove_resources "$1" 2>/dev/null || cleanup_status=$?
    printf "%s %s\n" "$cleanup_status" "$STOP_CLEANUP_OUTCOME"
  ' "$STOP_BUILD_DIR"
  [ "$status" -eq 0 ]
  [ "$output" == '1 failure' ]
  [ -f "${STOP_BUILD_DIR}/unexpected.txt" ]
  [ ! -e "${STOP_BUILD_DIR}/disk.qcow2" ]
}

@test "cleanup refuses a directory outside build/reference-vm" {
  mkdir -p "${REFERENCE_TEST_ROOT}/elsewhere"
  printf 'keep' > "${REFERENCE_TEST_ROOT}/elsewhere/disk.qcow2"

  run stop_module '
    STOP_QEMU_STATE=terminated
    cleanup_status=0
    stop_cleanup_remove_resources "$1" || cleanup_status=$?
    printf "%s %s\n" "$cleanup_status" "$STOP_CLEANUP_OUTCOME"
  ' "${REFERENCE_TEST_ROOT}/elsewhere"
  [ "$status" -eq 0 ]
  [ "$output" == '1 failure' ]
  [ -f "${REFERENCE_TEST_ROOT}/elsewhere/disk.qcow2" ]
}
