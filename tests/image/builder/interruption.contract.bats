load builder-support

setup() {
  builder_setup
}

teardown() {
  if [[ -n "${BUILDER_PROCESS_PID:-}" ]] && kill -0 "$BUILDER_PROCESS_PID" 2>/dev/null; then
    kill -TERM "$BUILDER_PROCESS_PID" 2>/dev/null || true
    wait "$BUILDER_PROCESS_PID" 2>/dev/null || true
  fi
  builder_teardown
}

builder_last_evidence_run() {
  find "${BUILDER_REPOSITORY_ROOT}/evidence/archiso-build" \
    -mindepth 1 -maxdepth 1 -type d -print | sort | tail -n 1
}

builder_last_result() {
  find "${BUILDER_REPOSITORY_ROOT}/evidence/archiso-build" \
    -mindepth 2 -maxdepth 2 -name execution-result.json -print | sort | tail -n 1
}

builder_wait_for_call() {
  local expected="$1"
  local attempt=0

  while [[ "$attempt" -lt 200 ]]; do
    if grep -Fq -- "$expected" "$BUILDER_CALL_LOG"; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 0.05
  done
  return 1
}

@test "SIGINT and SIGTERM stop, preserve diagnostics, and retain their conventional statuses" {
  local signal_name
  local expected_status
  local logs_line
  local scan_line
  local remove_line
  local result_path

  for signal_name in INT TERM; do
    BUILDER_DOCKER_BUILD_DELAY=1 builder_launch
    builder_wait_for_call 'docker exec --env SOURCE_DATE_EPOCH='
    kill -s "$signal_name" "$BUILDER_PROCESS_PID"
    builder_wait

    if [[ "$signal_name" == 'INT' ]]; then
      expected_status=130
    else
      expected_status=143
    fi
    [ "$BUILDER_COMMAND_STATUS" -eq "$expected_status" ]
    result_path="$(builder_last_result)"
    [ -f "${result_path%/*}/gitleaks-final-1.json" ]
    grep -Fq '"outcome": "interrupted"' "$result_path"
    grep -Fq "\"exit_status\": ${expected_status}" "$result_path"
    grep -Fq '"cleanup": {' "$result_path"
    grep -Fq 'docker stop -t 30' "$BUILDER_CALL_LOG"

    logs_line="$(grep -n '^docker logs ' "$BUILDER_CALL_LOG" | cut -d: -f1)"
    scan_line="$(grep -n 'gitleaks dir .*gitleaks-diagnostics.json' "$BUILDER_CALL_LOG" | cut -d: -f1)"
    remove_line="$(grep -n '^docker rm ' "$BUILDER_CALL_LOG" | cut -d: -f1)"
    [ "$logs_line" -lt "$scan_line" ]
    [ "$scan_line" -lt "$remove_line" ]
  done
}

@test "a second signal aborts interruption cleanup and preserves the first signal status" {
  BUILDER_DOCKER_BUILD_DELAY=1 BUILDER_DOCKER_STOP_DELAY=2 builder_launch
  builder_wait_for_call 'docker exec --env SOURCE_DATE_EPOCH='
  kill -TERM "$BUILDER_PROCESS_PID"
  builder_wait_for_call 'docker stop -t 30 '
  kill -INT "$BUILDER_PROCESS_PID"
  builder_wait

  [ "$BUILDER_COMMAND_STATUS" -eq 143 ]
  grep -Fq 'a second signal interrupted cleanup' "$BUILDER_STDERR_PATH"
  ! grep -Fq 'docker rm ' "$BUILDER_CALL_LOG"
  [ -f "$(builder_last_evidence_run)/run.lock" ]
}
