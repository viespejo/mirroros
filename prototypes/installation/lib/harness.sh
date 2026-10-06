#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared across the harness libraries sourced by harness.sh.
# Prototype harness orchestrator. Sourced by each engine's `run` entry point, which sets
# PROTO_ENGINE_NAME and PROTO_ENGINE_DIR before calling proto_main. The engine is the only difference
# between prototypes: everything else here is shared.
#
# Exit statuses: 0 passed; 2 refusal, precondition, or scan finding; 3 the engine failed;
# 4 a postcondition failed; 5 infrastructure failure (deadline, missing report, medium or disk);
# 6 internal or damaged checkout; 130/143 interrupted.

PROTO_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROTO_REPOSITORY_ROOT="$(cd -- "${PROTO_LIB_DIR}/../../.." && pwd -P)"

PROTO_ENGINE_NAME="${PROTO_ENGINE_NAME:-}"
PROTO_ENGINE_DIR="${PROTO_ENGINE_DIR:-}"
PROTO_OVMF_CODE_PATH='/usr/share/edk2/x64/OVMF_CODE.4m.fd'
PROTO_OVMF_VARS_PATH='/usr/share/edk2/x64/OVMF_VARS.4m.fd'
PROTO_KVM_PROBE_SECONDS=20

PROTO_VARIANT='normal'
PROTO_MODE='unattended'
PROTO_STATUS=0
PROTO_STAGE=''
PROTO_FINALIZED=0
PROTO_INSTALL_OUTCOME='not_run'
PROTO_INSTALL_QEMU_STATUS=''
PROTO_INSTALL_SECONDS=''
PROTO_ENGINE_EXIT=''
PROTO_VERIFY_OUTCOME='not_run'
PROTO_VERIFY_QEMU_STATUS=''
PROTO_VERIFY_SECONDS=''
PROTO_VERIFY_RESULT=''
PROTO_NOCLOUD_SCAN='not_run'

BUNDLE_DIR=''
BUNDLE_ISO=''
BUNDLE_ISO_SHA256=''
BUNDLE_ARTIFACT_COMMIT=''
BUNDLE_ARTIFACT_RUN_ID=''

for PROTO_LIBRARY in config.sh resources.sh secrets.sh nocloud.sh launch.sh stop-cleanup.sh evidence.sh; do
  PROTO_LIBRARY_PATH="${PROTO_LIB_DIR}/${PROTO_LIBRARY}"
  if [[ ! -f "$PROTO_LIBRARY_PATH" || ! -r "$PROTO_LIBRARY_PATH" ]]; then
    printf 'MirrorOS prototype: incomplete or damaged checkout; a harness library is missing: %s\n' \
      "$PROTO_LIBRARY_PATH" >&2
    exit 6
  fi
  # shellcheck disable=SC1090 # Harness libraries are resolved relative to this file.
  source "$PROTO_LIBRARY_PATH" || exit 6
done

proto_usage() {
  printf '%s\n' \
    "Usage: ${PROTO_ENGINE_NAME}/run [--variant normal|unreachable-mirrors] [--attended] BUNDLE_DIRECTORY" \
    '' \
    'Runs the shared prototype scenario against the unmodified qualified bundle in the reference VM.' \
    'Default: unattended two-boot run. --attended: boot 1 only, interactive on the serial console.' \
    'Raw results: evidence/prototypes/installation/<engine>/<run-id>/ (ignored).'
}

# Keeps the first failure as the primary status.
proto_mark_failure() {
  if [[ "$PROTO_STATUS" -eq 0 ]]; then
    PROTO_STATUS="$1"
    PROTO_STAGE="$2"
  fi
}

proto_parse_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help|-h) proto_usage; return 100 ;;
      --attended) PROTO_MODE='attended'; shift ;;
      --variant)
        [[ "$#" -ge 2 && ( "$2" == 'normal' || "$2" == 'unreachable-mirrors' ) ]] || {
          printf '%s\n' 'MirrorOS prototype: --variant accepts normal or unreachable-mirrors.' >&2
          return 2
        }
        PROTO_VARIANT="$2"
        shift 2
        ;;
      -*)
        printf 'MirrorOS prototype: unsupported option: %s\n' "$1" >&2
        return 2
        ;;
      *)
        [[ -z "$BUNDLE_DIR" ]] || { printf '%s\n' 'MirrorOS prototype: only one bundle directory is accepted.' >&2; return 2; }
        BUNDLE_DIR="$1"
        shift
        ;;
    esac
  done
  if [[ -z "$BUNDLE_DIR" ]]; then
    printf '%s\n' 'MirrorOS prototype: the bundle directory argument is missing.' >&2
    return 2
  fi
  if [[ "$PROTO_MODE" == 'attended' && "$PROTO_VARIANT" != 'normal' ]]; then
    printf '%s\n' 'MirrorOS prototype: --attended supports only the normal variant.' >&2
    return 2
  fi
  if [[ ! -d "$BUNDLE_DIR" ]] || ! BUNDLE_DIR="$(cd -- "$BUNDLE_DIR" && pwd -P)"; then
    printf '%s\n' 'MirrorOS prototype: the bundle directory is not an accessible directory.' >&2
    return 2
  fi
}

proto_check_preconditions() {
  local tool
  local firmware_path

  if [[ "$EUID" -eq 0 ]]; then
    printf '%s\n' 'MirrorOS prototype: do not run as root; run as a normal user with functional KVM access.' >&2
    return 2
  fi
  for tool in qemu-system-x86_64 qemu-img xorriso jq gitleaks git timeout sha256sum od; do
    if ! command -v "$tool" > /dev/null 2>&1; then
      printf 'MirrorOS prototype: required tool is missing: %s. No host remediation is attempted.\n' "$tool" >&2
      return 2
    fi
  done
  for firmware_path in "$PROTO_OVMF_CODE_PATH" "$PROTO_OVMF_VARS_PATH"; do
    if [[ ! -f "$firmware_path" || ! -r "$firmware_path" ]]; then
      printf 'MirrorOS prototype: OVMF firmware is missing or unreadable: %s.\n' "$firmware_path" >&2
      return 2
    fi
  done
  if ! timeout "$PROTO_KVM_PROBE_SECONDS" qemu-system-x86_64 -machine q35,accel=kvm -cpu host -m 128 \
    -display none -nodefaults -S -monitor stdio <<< 'quit' > /dev/null 2>&1; then
    printf '%s\n' 'MirrorOS prototype: KVM is not functional for this user; no fallback is attempted.' >&2
    return 2
  fi
  if [[ ! -d "$PROTO_ENGINE_DIR/guest" ]]; then
    printf 'MirrorOS prototype: the engine guest directory is missing: %s/guest\n' "$PROTO_ENGINE_DIR" >&2
    return 6
  fi
}

# The qualified ISO is used unmodified: the bundle must match its own checksums.
proto_admit_bundle() {
  local metadata="${BUNDLE_DIR}/artifact-metadata.json"
  local -a isos=()

  if [[ ! -f "${BUNDLE_DIR}/SHA256SUMS" || ! -f "$metadata" ]]; then
    printf '%s\n' 'MirrorOS prototype: the bundle is not admissible: SHA256SUMS or artifact-metadata.json is missing.' >&2
    return 2
  fi
  if ! (cd -- "$BUNDLE_DIR" && sha256sum --check --quiet SHA256SUMS > /dev/null 2>&1); then
    printf '%s\n' 'MirrorOS prototype: the bundle is not admissible: its checksums do not match.' >&2
    return 2
  fi
  mapfile -t isos < <(find "$BUNDLE_DIR" -maxdepth 1 -type f -name '*.iso')
  if [[ "${#isos[@]}" -ne 1 ]]; then
    printf '%s\n' 'MirrorOS prototype: the bundle is not admissible: exactly one ISO is required.' >&2
    return 2
  fi
  BUNDLE_ISO="${isos[0]}"
  if ! BUNDLE_ISO_SHA256="$(jq -er '.artifact.iso.sha256' "$metadata")" || \
    ! BUNDLE_ARTIFACT_COMMIT="$(jq -er '.execution.commit' "$metadata")" || \
    ! BUNDLE_ARTIFACT_RUN_ID="$(jq -er '.execution.run_id' "$metadata")"; then
    printf '%s\n' 'MirrorOS prototype: the bundle metadata is incomplete.' >&2
    return 2
  fi
}

proto_stage_install() {
  local status=0

  PROTO_INSTALL_OUTCOME='started'
  launch_build_install_command "$BUNDLE_ISO" "$NOCLOUD_SEED_FILE" "${EVIDENCE_RUN_DIR}/serial-install.log"
  launch_start "${EVIDENCE_RUN_DIR}/qemu-install-diagnostics.log" || status=$?
  if [[ "$status" -ne 0 ]]; then
    proto_mark_failure 5 qemu-launch
    return 0
  fi
  printf 'MirrorOS prototype: boot 1: installing (deadline %s s).\n' "$PROTO_INSTALL_DEADLINE_SECONDS" >&2
  launch_wait_exit "$PROTO_INSTALL_DEADLINE_SECONDS"
  PROTO_INSTALL_OUTCOME="$LAUNCH_OUTCOME"
  PROTO_INSTALL_QEMU_STATUS="$LAUNCH_QEMU_STATUS"
  PROTO_INSTALL_SECONDS="$LAUNCH_DURATION_SECONDS"
  if [[ "$LAUNCH_OUTCOME" == 'deadline' ]]; then
    proto_mark_failure 5 install-deadline
  fi
  # Whatever the outcome, keep what the guest printed: mirrorlist, disk state, and install report.
  launch_extract_block "${EVIDENCE_RUN_DIR}/serial-install.log" MIRROROS-MIRRORLIST "$RUN_ID" "${EVIDENCE_RUN_DIR}/mirrorlist.txt" || true
  launch_extract_block "${EVIDENCE_RUN_DIR}/serial-install.log" MIRROROS-DISKSTATE "$RUN_ID" "${EVIDENCE_RUN_DIR}/disk-state.txt" || true
  if launch_extract_report "${EVIDENCE_RUN_DIR}/serial-install.log" MIRROROS-INSTALL "$RUN_ID" "${EVIDENCE_RUN_DIR}/install-report.json" && \
    jq -e --arg id "$RUN_ID" '.run_id == $id and (.engine_exit_status | type == "number")' "${EVIDENCE_RUN_DIR}/install-report.json" > /dev/null 2>&1; then
    PROTO_ENGINE_EXIT="$(jq -r '.engine_exit_status' "${EVIDENCE_RUN_DIR}/install-report.json")"
    if [[ "$PROTO_ENGINE_EXIT" -ne 0 ]]; then
      proto_mark_failure 3 engine-failed
    elif [[ "$PROTO_VARIANT" != 'normal' ]]; then
      proto_mark_failure 6 injection-not-effective
    fi
  else
    rm -f -- "${EVIDENCE_RUN_DIR}/install-report.json"
    proto_mark_failure 5 install-report
  fi
}

proto_stage_verify() {
  local status=0

  PROTO_VERIFY_OUTCOME='started'
  launch_build_verify_command "${EVIDENCE_RUN_DIR}/serial-verify.log"
  launch_start "${EVIDENCE_RUN_DIR}/qemu-verify-diagnostics.log" || status=$?
  if [[ "$status" -ne 0 ]]; then
    proto_mark_failure 5 qemu-launch
    return 0
  fi
  printf 'MirrorOS prototype: boot 2: verifying the installed disk (deadline %s s).\n' "$PROTO_VERIFY_DEADLINE_SECONDS" >&2
  launch_wait_report "$RUN_ID" "${EVIDENCE_RUN_DIR}/verify-report.json" "$PROTO_VERIFY_DEADLINE_SECONDS"
  PROTO_VERIFY_OUTCOME="$LAUNCH_OUTCOME"
  PROTO_VERIFY_QEMU_STATUS="$LAUNCH_QEMU_STATUS"
  PROTO_VERIFY_SECONDS="$LAUNCH_DURATION_SECONDS"
  if [[ "$LAUNCH_OUTCOME" != 'report' ]]; then
    proto_mark_failure 5 "verify-${LAUNCH_OUTCOME}"
    return 0
  fi
  if ! jq -e --arg id "$RUN_ID" '.run_id == $id and .kind == "postconditions" and (.checks | type == "object") and (.result == "passed" or .result == "failed")' \
    "${EVIDENCE_RUN_DIR}/verify-report.json" > /dev/null 2>&1; then
    proto_mark_failure 5 verify-report
    return 0
  fi
  PROTO_VERIFY_RESULT="$(jq -r '.result' "${EVIDENCE_RUN_DIR}/verify-report.json")"
  if [[ "$PROTO_VERIFY_RESULT" != 'passed' ]]; then
    proto_mark_failure 4 postconditions
  fi
}

proto_run_stages() {
  local status=0

  proto_secrets_generate || { proto_mark_failure 5 secrets; return 0; }
  printf 'MirrorOS prototype: run %s (%s, %s): preparing the NoCloud medium.\n' "$RUN_ID" "$PROTO_ENGINE_NAME" "$PROTO_VARIANT" >&2
  proto_nocloud_prepare "$RUN_ID" "$BUILD_RUN_DIR" "$EVIDENCE_RUN_DIR" "${PROTO_ENGINE_DIR}/guest" \
    "$REFERENCE_VM_NOCLOUD_LABEL" "$REFERENCE_VM_GUEST_HTTPS_URL" "$REFERENCE_VM_GUEST_HTTPS_TIMEOUT_SECONDS" \
    "$PROTO_VARIANT" "$PROTO_MODE" || status=$?
  case "$status" in
    0) PROTO_NOCLOUD_SCAN='passed' ;;
    2) PROTO_NOCLOUD_SCAN='findings'; proto_mark_failure 2 nocloud-scan; return 0 ;;
    5) PROTO_NOCLOUD_SCAN='failed'; proto_mark_failure 5 nocloud; return 0 ;;
    *) proto_mark_failure 6 nocloud; return 0 ;;
  esac

  launch_prepare_disk "$BUILD_RUN_DIR" || { proto_mark_failure 5 disk-preparation; return 0; }

  if [[ "$PROTO_MODE" == 'attended' ]]; then
    PROTO_INSTALL_OUTCOME='attended'
    launch_build_attended_command "$BUNDLE_ISO" "$NOCLOUD_SEED_FILE" "${EVIDENCE_RUN_DIR}/serial-install.log"
    printf '%s\n' 'MirrorOS prototype: attended session. Log in on the serial console as instructed by the runner; Ctrl-A x quits QEMU.' >&2
    launch_run_attended || proto_mark_failure 5 qemu-launch
    PROTO_INSTALL_QEMU_STATUS="$LAUNCH_QEMU_STATUS"
    return 0
  fi

  proto_stage_install
  if [[ "$PROTO_STATUS" -eq 0 ]]; then
    proto_stage_verify
  fi
}

proto_finalize() {
  if [[ "$PROTO_FINALIZED" -eq 1 ]]; then
    return 0
  fi
  PROTO_FINALIZED=1
  trap 'PROTO_STATUS=130' INT
  trap 'PROTO_STATUS=143' TERM

  if ! stop_cleanup_stop_qemu; then
    proto_mark_failure 5 qemu-stop
  fi
  stop_cleanup_remove_resources "$BUILD_RUN_DIR" || true
  if [[ -n "$STOP_CLEANUP_GUIDANCE" ]]; then
    printf 'MirrorOS prototype: %s\n' "$STOP_CLEANUP_GUIDANCE" >&2
  fi
  evidence_write_metadata "$EVIDENCE_RUN_DIR" || proto_mark_failure 5 metadata-write
  evidence_finalize || true
}

proto_handle_signal() {
  proto_mark_failure "$1" "signal-$2"
  proto_finalize
  exit "$PROTO_STATUS"
}

proto_handle_exit() {
  if [[ "$PROTO_FINALIZED" -eq 0 ]]; then
    proto_mark_failure 6 internal
    proto_finalize
    exit "$PROTO_STATUS"
  fi
}

proto_main() {
  local status=0

  if [[ -z "$PROTO_ENGINE_NAME" || -z "$PROTO_ENGINE_DIR" ]]; then
    printf '%s\n' 'MirrorOS prototype: the engine entry point did not define PROTO_ENGINE_NAME and PROTO_ENGINE_DIR.' >&2
    return 6
  fi
  proto_parse_arguments "$@" || { status=$?; [[ "$status" -eq 100 ]] && return 0; return "$status"; }
  proto_check_preconditions || return $?
  proto_admit_bundle || return $?
  proto_config_load "${PROTO_REPOSITORY_ROOT}/vm/reference/reference-vm.conf" || return $?
  launch_collect_versions
  evidence_capture_commit "$PROTO_REPOSITORY_ROOT" || return $?

  umask 077
  proto_resources_new_id || return $?
  proto_resources_prepare "$PROTO_REPOSITORY_ROOT" "$PROTO_ENGINE_NAME" "$RUN_ID" || return $?

  trap 'proto_handle_signal 130 INT' INT
  trap 'proto_handle_signal 143 TERM' TERM
  trap proto_handle_exit EXIT

  proto_run_stages
  proto_finalize
  return "$PROTO_STATUS"
}
