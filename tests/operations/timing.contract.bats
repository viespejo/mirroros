setup() {
  TIMING_SOURCE_ROOT="$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  source "$TIMING_SOURCE_ROOT/operations/lib/timing.sh"
}

teardown() {
  unset -f read date
}

clock_at() {
  CLOCK_TEXT="$1"
  # shellcheck disable=SC2162 # The production caller supplies -r through the argument vector.
  read() { builtin read "$@" <<< "$CLOCK_TEXT"; }
}

@test "uptime uses the first centisecond field and no per-sample external commands" {
  clock_at '0012.34 999.99'
  # Reading and arithmetic must work without date, awk, cut, or any other executable.
  local saved_path="$PATH"
  # shellcheck disable=SC2123 # Deliberately prove that sampling requires no executable lookup.
  PATH=/nonexistent
  timing_begin total
  clock_at '0013.56 999.99'
  timing_end total
  PATH="$saved_path"
  [ "${TIMING_SUM[total]}" -eq 1220 ]
  [ -z "${TIMING_REASON[total]:-}" ]
}

@test "repeated intervals accumulate only actual visits and unstarted work is absent" {
  clock_at '10.00 0.00'
  timing_begin total
  timing_begin review interactive
  clock_at '11.00 0.00'
  timing_end review
  clock_at '20.00 0.00'
  timing_begin review interactive
  clock_at '22.00 0.00'
  timing_end_all
  [ "${TIMING_SUM[review]}" -eq 3000 ]
  [ "${TIMING_SUM[total]}" -eq 12000 ]
  [ "${#TIMING_IDS[@]}" -eq 2 ]
  [[ "$(timing_json)" != *confirmation* ]]
  [[ "$(timing_json)" == *'"classification":"interactive"'* ]]
}

@test "nested intervals stay contained and duplicate begin does not reset a start" {
  clock_at '10.00 0.00'
  timing_begin total
  timing_begin configure
  clock_at '10.10 0.00'
  timing_begin configure
  timing_begin step.example
  clock_at '10.30 0.00'
  timing_end step.example
  clock_at '10.50 0.00'
  timing_end_all
  [ "${TIMING_SUM[configure]}" -eq 500 ]
  [ "${TIMING_SUM[step.example]}" -eq 200 ]
}

@test "wall clock changes are irrelevant to intervals" {
  date() { return 99; }
  SECONDS=9999
  clock_at '1.00 0.00'
  timing_begin total
  SECONDS=0
  clock_at '1.10 0.00'
  timing_end total
  [ "${TIMING_SUM[total]}" -eq 100 ]
}

@test "malformed and bounded-out readings are unavailable without echoing input" {
  local bad
  for bad in '' 'bad-input' '-1.00 0.00' '1.2 0.00' '1.234 0.00' '1000000000000.00 0.00' '1e3 0.00'; do
    clock_at "$bad"
    timing_begin total
    timing_end total
    [[ "$(timing_json)" == *'"status":"unavailable","reason":"clock_'* ]]
    [[ "$(timing_json)" != *duration_ms* ]]
    [[ "$(timing_json)" != *bad-input* ]]
  done
}

@test "unreadable clock returns success and omits duration instead of changing outcomes" {
  # shellcheck disable=SC2329 # Invoked indirectly by the sourced production clock reader.
  read() { return 1; }
  timing_begin total
  timing_end_all
  [ "$(timing_json)" = '{"total":{"status":"unavailable","reason":"clock_unreadable"},"intervals":[]}' ]
}

@test "a regressing reading invalidates the measurement and repeated visits cannot repair it" {
  clock_at '10.00 0.00'
  timing_begin total
  clock_at '9.00 0.00'
  timing_end total
  clock_at '11.00 0.00'
  timing_begin total
  clock_at '12.00 0.00'
  timing_end total
  [[ "$(timing_json)" == *'"reason":"clock_regressed"'* ]]
  [[ "$(timing_json)" != *duration_ms* ]]
}

@test "a failed end reading never manufactures a zero duration" {
  clock_at '0.00 0.00'
  timing_begin total
  clock_at 'invalid'
  timing_end_all
  [[ "$(timing_json)" == *clock_malformed* ]]
  [[ "$(timing_json)" != *duration_ms* ]]
}

@test "valid zero duration is available and closing unstarted work adds nothing" {
  clock_at '0.00 0.00'
  timing_end not_started
  timing_begin total
  timing_end_all
  [ "$(timing_json)" = '{"total":{"status":"available","duration_ms":0},"intervals":[]}' ]
}
