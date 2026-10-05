load vm-support

setup() {
  reference_setup
  reference_install_e2e_doubles
  EVIDENCE_LIB_DIR="${REFERENCE_REPOSITORY_ROOT}/vm/reference/lib"
  EVIDENCE_RUN_ID='20261005T120000Z-11111111-2222-4333-8444-555555555555'
  EVIDENCE_DIR="${REFERENCE_TEST_ROOT}/evidence/reference-vm/${EVIDENCE_RUN_ID}"
  EVIDENCE_PID_FILE="${REFERENCE_TEST_ROOT}/qemu.pid"
  mkdir -p -m 700 "$EVIDENCE_DIR"
  export REFERENCE_CALL_LOG REFERENCE_QEMU_PID_FILE="$EVIDENCE_PID_FILE"
  export PATH="${REFERENCE_DOUBLE_DIR}:${PATH}"
}

teardown() {
  if [[ -s "$EVIDENCE_PID_FILE" ]]; then kill "$(<"$EVIDENCE_PID_FILE")" 2>/dev/null || true; fi
  reference_teardown
}

evidence_module() {
  local snippet="$1"
  shift

  /usr/bin/bash -c '
    set -Eeuo pipefail
    umask 077
    source "$1/outcome.sh"
    source "$1/evidence.sh"
    RUN_ID="$2"
    EVIDENCE_RUN_DIR="$3"
    DOCUMENTS_CLI="$4"
    QUALIFY_BUNDLE_ADMISSION="{\"iso_name\":\"test.iso\",\"iso_sha256\":\"$(printf "b%.0s" {1..64})\",\"build_commit\":\"$(printf "a%.0s" {1..40})\",\"build_run_id\":\"build-run\"}"
    LAUNCH_VM_CONFIGURATION_JSON="{\"machine\":\"q35\"}"
    LAUNCH_QEMU_VERSION="QEMU emulator version 9.9.9"
    LAUNCH_OVMF_VERSION="ovmf test"
    LAUNCH_VERDICT='\''{"errors":[],"passed":true,"failed_checks":[]}'\''
    OUTCOME_TEST_COMMIT="$(printf "c%.0s" {1..40})"
    OUTCOME_TEST_DIRTY=false
    OUTCOME_STARTED_EPOCH="$(date -u +%s)"
    outcome_set_scan nocloud passed
    outcome_record_tool_status nocloud_prepare 0
    snippet="$5"
    shift 5
    eval "$snippet"
  ' _ "$EVIDENCE_LIB_DIR" "$EVIDENCE_RUN_ID" "$EVIDENCE_DIR" \
    "${REFERENCE_REPOSITORY_ROOT}/vm/reference/bootstrap-documents.mjs" "$snippet" "$@"
}

@test "a clean evidence scan passes, keeps a private redacted report, and leaves the status alone" {
  run evidence_module '
    scan_status=0
    evidence_scan "$EVIDENCE_RUN_DIR" || scan_status=$?
    printf "%s %s %s %s\n" "$scan_status" "${OUTCOME_SCANS[evidence]}" "${OUTCOME_TOOL_STATUSES[evidence_scan]}" "$OUTCOME_PRIMARY_STATUS"
  '
  [ "$status" -eq 0 ]
  [ "$output" == '0 passed 0 0' ]
  [ "$(stat -c '%a' "${EVIDENCE_DIR}/gitleaks-evidence.json")" == '600' ]
  grep -Fq -- '--redact' "$REFERENCE_CALL_LOG"
}

@test "scan findings yield 2, keep the report private, and name the evidence directory" {
  export REFERENCE_GITLEAKS_FAIL_ON='/evidence/'

  run evidence_module '
    scan_status=0
    evidence_scan "$EVIDENCE_RUN_DIR" || scan_status=$?
    printf "%s %s %s %s\n" "$scan_status" "${OUTCOME_SCANS[evidence]}" "$OUTCOME_PRIMARY_STATUS" "$OUTCOME_FAILED_STAGE"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *'2 findings 2 evidence-scan' ]]
  [[ "$output" == *'stays private'* ]]
  [ "$(stat -c '%a' "${EVIDENCE_DIR}/gitleaks-evidence.json")" == '600' ]
}

@test "a scanner execution failure yields 5 with the original status recorded" {
  export REFERENCE_GITLEAKS_FAIL_ON='/evidence/'
  export REFERENCE_GITLEAKS_STATUS=126

  run evidence_module '
    scan_status=0
    evidence_scan "$EVIDENCE_RUN_DIR" || scan_status=$?
    printf "%s %s %s %s\n" "$scan_status" "${OUTCOME_SCANS[evidence]}" "$OUTCOME_PRIMARY_STATUS" "${OUTCOME_TOOL_STATUSES[evidence_scan]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *'5 failed 5 126' ]]
}

@test "scan findings after an earlier failure keep the earlier status but are recorded" {
  export REFERENCE_GITLEAKS_FAIL_ON='/evidence/'

  run evidence_module '
    outcome_mark_failure 4 guest-checks
    evidence_scan "$EVIDENCE_RUN_DIR" || true
    printf "%s %s %s\n" "$OUTCOME_PRIMARY_STATUS" "$OUTCOME_FAILED_STAGE" "${OUTCOME_SCANS[evidence]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *'4 guest-checks findings' ]]
}

@test "finalization writes a private valid result and renders the summary from it" {
  run evidence_module '
    outcome_note_cleanup success ""
    evidence_finalize
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *'PASSED (exit 0)'* ]]
  [ "$(stat -c '%a' "${EVIDENCE_DIR}/result.json")" == '600' ]
  [ "$(reference_json "${EVIDENCE_DIR}/result.json" 'r.status')" == '0' ]
  [ "$(reference_json "${EVIDENCE_DIR}/result.json" 'r.scans.evidence')" == 'passed' ]
  [ "$(reference_json "${EVIDENCE_DIR}/result.json" 'Object.values(r.checks).every(s => s === "passed")')" == 'true' ]
  [ "$(reference_json "${EVIDENCE_DIR}/result.json" 'r.nocloud_note.includes("NoCloud")')" == 'true' ]
  [ -z "$(find "$EVIDENCE_DIR" -name '.result-input*')" ]
}

@test "a failed guest check is reported per check and the other checks keep their results" {
  run evidence_module '
    LAUNCH_VERDICT='\''{"errors":[],"passed":false,"failed_checks":["https_request"]}'\''
    outcome_mark_failure 4 guest-checks
    outcome_note_cleanup success ""
    evidence_finalize
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *'NOT QUALIFIED (exit 4)'* ]]
  [ "$(reference_json "${EVIDENCE_DIR}/result.json" 'r.checks.https_request')" == 'failed' ]
  [ "$(reference_json "${EVIDENCE_DIR}/result.json" 'r.checks.uefi_mode')" == 'passed' ]
  [ "$(reference_json "${EVIDENCE_DIR}/result.json" 'r.failed_stage')" == 'guest-checks' ]
}

@test "without an accepted guest report no check is credited" {
  run evidence_module '
    LAUNCH_VERDICT=""
    outcome_mark_failure 5 deadline
    outcome_note_cleanup success ""
    evidence_finalize
  '
  [ "$status" -eq 0 ]
  [ "$(reference_json "${EVIDENCE_DIR}/result.json" 'Object.values(r.checks).every(s => s === "not_run")')" == 'true' ]
  [ "$(reference_json "${EVIDENCE_DIR}/result.json" 'r.status')" == '5' ]
}

@test "findings in the final scan rewrite the result as status 2" {
  export REFERENCE_GITLEAKS_FAIL_ON='/evidence/'

  run evidence_module '
    outcome_note_cleanup success ""
    evidence_finalize
    printf "%s\n" "$OUTCOME_PRIMARY_STATUS"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *'NOT QUALIFIED (exit 2)'* ]]
  [ "$(reference_json "${EVIDENCE_DIR}/result.json" 'r.status')" == '2' ]
  [ "$(reference_json "${EVIDENCE_DIR}/result.json" 'r.scans.evidence')" == 'findings' ]
}

evidence_prepare_run() {
  reference_prepare_e2e
  EVIDENCE_BUNDLE_BEFORE="$(reference_snapshot_bundle "$REFERENCE_BUNDLE_DIR")"
}

evidence_assert_run_artifacts() {
  local evidence_dir
  local file

  evidence_dir="$(reference_e2e_evidence_dir)"
  [ "$(stat -c '%a' "$evidence_dir")" == '700' ]
  for file in result.json guest-serial.log qemu-diagnostics.log gitleaks-nocloud.json gitleaks-evidence.json; do
    [ "$(stat -c '%a' "${evidence_dir}/${file}")" == '600' ]
  done
  [ -z "$(ls -A "${REFERENCE_REPOSITORY_ROOT}/build/reference-vm")" ]
  [ "$(reference_snapshot_bundle "$REFERENCE_BUNDLE_DIR")" == "$EVIDENCE_BUNDLE_BEFORE" ]
  # The terminal shows only progress and the summary, never raw guest output.
  ! grep -Fq 'SERIAL-NOISE-MARKER' "$REFERENCE_STDOUT_PATH" "$REFERENCE_STDERR_PATH"
  grep -Fq 'SERIAL-NOISE-MARKER' "${evidence_dir}/guest-serial.log"
}

@test "a complete simulated run exits 0 with scanned private evidence and cleaned resources" {
  evidence_prepare_run
  export REFERENCE_QEMU_MODE=pass

  reference_invoke "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
  evidence_assert_run_artifacts
  result="$(reference_e2e_evidence_dir)/result.json"
  [ "$(reference_json "$result" 'r.status')" == '0' ]
  [ "$(reference_json "$result" 'r.test_code.dirty')" == 'false' ]
  [ "$(reference_json "$result" 'r.test_code.commit')" == "$(git -C "$REFERENCE_REPOSITORY_ROOT" rev-parse HEAD)" ]
  [ "$(reference_json "$result" 'r.cleanup.outcome')" == 'success' ]
  [ "$(reference_json "$result" 'r.scans.nocloud + r.scans.evidence')" == 'passedpassed' ]
  [ "$(reference_json "$result" 'r.versions.qemu')" == 'QEMU emulator version 9.9.9' ]
  grep -Fq 'PASSED (exit 0)' "$REFERENCE_STDOUT_PATH"
}

@test "a failed guest check exits 4 with the evidence retained" {
  evidence_prepare_run
  export REFERENCE_QEMU_MODE=fail

  reference_invoke "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 4 ]
  evidence_assert_run_artifacts
  result="$(reference_e2e_evidence_dir)/result.json"
  [ "$(reference_json "$result" 'r.checks.https_request')" == 'failed' ]
  [ "$(reference_json "$result" 'r.failed_stage')" == 'guest-checks' ]
}

@test "QEMU exiting before a report exits 5 and credits no check" {
  evidence_prepare_run
  export REFERENCE_QEMU_MODE=exit

  reference_invoke "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 5 ]
  evidence_assert_run_artifacts
  result="$(reference_e2e_evidence_dir)/result.json"
  [ "$(reference_json "$result" 'r.failed_stage')" == 'qemu-exit' ]
  [ "$(reference_json "$result" 'Object.values(r.checks).every(s => s === "not_run")')" == 'true' ]
  [ "$(reference_json "$result" 'r.original_tool_statuses.qemu')" == '3' ]
}

@test "secret-scan findings in the evidence exit 2 even when the guest checks passed" {
  evidence_prepare_run
  export REFERENCE_QEMU_MODE=pass
  export REFERENCE_GITLEAKS_FAIL_ON='/evidence/'

  reference_invoke "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 2 ]
  result="$(reference_e2e_evidence_dir)/result.json"
  [ "$(reference_json "$result" 'r.status')" == '2' ]
  [ "$(reference_json "$result" 'r.scans.evidence')" == 'findings' ]
  [ "$(reference_json "$result" 'r.cleanup.outcome')" == 'success' ]
  [ -f "$(reference_e2e_evidence_dir)/guest-serial.log" ]
}
