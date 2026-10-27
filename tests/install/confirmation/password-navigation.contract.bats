# Password navigation with synthetic fixtures only; no credentials, planning, engine, or disk operations.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced forms consume shared state and function doubles.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/screens.sh"
  CALLS="${BATS_TEST_TMPDIR}/calls"
  COUNT="${BATS_TEST_TMPDIR}/count"
  : > "$CALLS"
  printf '0\n' > "$COUNT"
  SCENARIO=restart
  FLOW_PASSWORD=stale_synthetic_value
  FLOW_CONFIRMED=true
  declare -gA FLOW_REVIEW=([user_name]=synthetic_user [root_account]=locked)
  flow_reached() { printf 'reached %s\n' "$1" >> "$CALLS"; }
  flow_load_review() { return 0; }
  flow_cancel() { printf 'cancel %s\n' "$1" >> "$CALLS"; exit 3; }
  step() { printf 'step %s\n' "$1" >> "$CALLS"; }
  gum() {
    local number
    [[ $1 == input ]] || return 0
    [[ $2 == --password ]] || return 6
    read -r number < "$COUNT"
    number=$((number + 1))
    printf '%s\n' "$number" > "$COUNT"
    printf 'input %s\n' "$number" >> "$CALLS"
    case "$SCENARIO:$number" in
      restart:1 | back:1 | cancel_confirm:1) printf 'synthetic-first\n' ;;
      restart:2 | back:2) return 1 ;;
      restart:3 | restart:4) printf 'synthetic-replacement\n' ;;
      back:3) return 1 ;;
      cancel_first:1 | cancel_confirm:2) return 130 ;;
      *) return 6 ;;
    esac
  }
}

@test "password navigation Confirm Esc discards the first value and restarts both masked fields" {
  check_restart() {
    password_form || return $?
    [[ $FLOW_PASSWORD == synthetic-replacement && $FLOW_CONFIRMED == true ]]
  }
  run check_restart
  [ "$status" -eq 0 ]
  [ "$(< "$COUNT")" -eq 4 ]
  [ "$(grep -c '^step Password$' "$CALLS")" -eq 1 ]
  run grep -E 'synthetic-first|synthetic-replacement|cancel ' "$CALLS"
  [ "$status" -eq 1 ]
}

@test "password navigation Password Esc after repetition Back leaves no accepted value" {
  SCENARIO=back
  check_back() {
    local result=0
    password_form || result=$?
    [[ $result == 1 && -z $FLOW_PASSWORD ]]
  }
  run check_back
  [ "$status" -eq 0 ]
  [ "$(< "$COUNT")" -eq 3 ]
  grep -qxF 'step Password' "$CALLS"
}

@test "password navigation Ctrl+C still cancels from either masked field" {
  local scenario expected
  for scenario in cancel_first cancel_confirm; do
    SCENARIO=$scenario
    printf '0\n' > "$COUNT"
    : > "$CALLS"
    run password_form
    [ "$status" -eq 3 ]
    grep -qxF 'cancel password' "$CALLS"
    if [[ $scenario == cancel_first ]]; then expected=1; else expected=2; fi
    [ "$(< "$COUNT")" -eq "$expected" ]
  done
}
