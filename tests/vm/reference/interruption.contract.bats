load vm-support

setup() {
  reference_setup
  INTERRUPTION_OUTCOME_MODULE="${REFERENCE_REPOSITORY_ROOT}/vm/reference/lib/outcome.sh"
  INTERRUPTION_PID_FILE="${REFERENCE_TEST_ROOT}/qemu.pid"
  export REFERENCE_QEMU_PID_FILE="$INTERRUPTION_PID_FILE"
}

teardown() {
  if [[ -s "$INTERRUPTION_PID_FILE" ]]; then kill "$(<"$INTERRUPTION_PID_FILE")" 2>/dev/null || true; fi
  reference_teardown
}

@test "the first non-success is kept and later failures never replace it" {
  run reference_run_module "$INTERRUPTION_OUTCOME_MODULE" '
    outcome_mark_failure 4 guest-checks
    outcome_mark_failure 5 cleanup
    outcome_mark_failure 2 evidence-scan
    printf "%s %s\n" "$OUTCOME_PRIMARY_STATUS" "$OUTCOME_FAILED_STAGE"
  '
  [ "$status" -eq 0 ]
  [ "$output" == '4 guest-checks' ]
}

@test "a cleanup failure after success yields 5" {
  run reference_run_module "$INTERRUPTION_OUTCOME_MODULE" '
    outcome_note_cleanup failure "recover manually" "build/reference-vm/x"
    printf "%s %s %s\n" "$OUTCOME_PRIMARY_STATUS" "$OUTCOME_FAILED_STAGE" "$OUTCOME_CLEANUP_OUTCOME"
  '
  [ "$status" -eq 0 ]
  [ "$output" == '5 cleanup failure' ]
}

@test "a cleanup failure never replaces an earlier non-success" {
  run reference_run_module "$INTERRUPTION_OUTCOME_MODULE" '
    outcome_mark_failure 4 guest-checks
    outcome_note_cleanup preserved "recover manually" "build/reference-vm/x"
    printf "%s %s %s\n" "$OUTCOME_PRIMARY_STATUS" "$OUTCOME_FAILED_STAGE" "$OUTCOME_CLEANUP_OUTCOME"
  '
  [ "$status" -eq 0 ]
  [ "$output" == '4 guest-checks preserved' ]
}

@test "a successful cleanup leaves success untouched" {
  run reference_run_module "$INTERRUPTION_OUTCOME_MODULE" '
    outcome_note_cleanup success ""
    printf "%s [%s] %s\n" "$OUTCOME_PRIMARY_STATUS" "$(outcome_next_action)" "$OUTCOME_CLEANUP_OUTCOME"
  '
  [ "$status" -eq 0 ]
  [ "$output" == '0 [] success' ]
}

@test "signals map to 130 and 143 but never replace an earlier non-success" {
  run reference_run_module "$INTERRUPTION_OUTCOME_MODULE" '
    outcome_mark_interrupted 130 INT
    printf "%s %s\n" "$OUTCOME_PRIMARY_STATUS" "$OUTCOME_FAILED_STAGE"
    OUTCOME_PRIMARY_STATUS=0
    OUTCOME_FAILED_STAGE=""
    outcome_mark_interrupted 143 TERM
    printf "%s %s\n" "$OUTCOME_PRIMARY_STATUS" "$OUTCOME_FAILED_STAGE"
    OUTCOME_PRIMARY_STATUS=0
    outcome_mark_failure 4 guest-checks
    outcome_mark_interrupted 130 INT
    printf "%s %s\n" "$OUTCOME_PRIMARY_STATUS" "$OUTCOME_FAILED_STAGE"
  '
  [ "$status" -eq 0 ]
  mapfile -t lines <<< "$output"
  [ "${lines[0]}" == '130 signal-INT' ]
  [ "${lines[1]}" == '143 signal-TERM' ]
  [ "${lines[2]}" == '4 guest-checks' ]
}

interruption_assert_clean_interrupt() {
  local expected_status="$1"
  local expected_stage="$2"
  local evidence_dir

  [ "$REFERENCE_COMMAND_STATUS" -eq "$expected_status" ]
  [ -s "$INTERRUPTION_PID_FILE" ]
  ! kill -0 "$(<"$INTERRUPTION_PID_FILE")" 2>/dev/null
  evidence_dir="$(reference_e2e_evidence_dir)"
  [ -f "${evidence_dir}/result.json" ]
  [ "$(reference_json "${evidence_dir}/result.json" 'r.status')" == "$expected_status" ]
  [ "$(reference_json "${evidence_dir}/result.json" 'r.failed_stage')" == "$expected_stage" ]
  [ "$(reference_json "${evidence_dir}/result.json" 'r.cleanup.outcome')" == 'success' ]
  [ -z "$(ls -A "${REFERENCE_REPOSITORY_ROOT}/build/reference-vm")" ]
  [ -f "${evidence_dir}/guest-serial.log" ]
  grep -Fq "NOT QUALIFIED (exit ${expected_status})" "$REFERENCE_STDOUT_PATH"
}

@test "SIGINT stops only the owned QEMU, cleans up, records the result, and exits 130" {
  reference_prepare_e2e
  export REFERENCE_QEMU_MODE=hang

  reference_invoke_signalled INT 4 "$REFERENCE_BUNDLE_DIR"
  interruption_assert_clean_interrupt 130 signal-INT
}

@test "SIGTERM stops the owned QEMU, cleans up, records the result, and exits 143" {
  reference_prepare_e2e
  export REFERENCE_QEMU_MODE=hang

  reference_invoke_signalled TERM 4 "$REFERENCE_BUNDLE_DIR"
  interruption_assert_clean_interrupt 143 signal-TERM
}
