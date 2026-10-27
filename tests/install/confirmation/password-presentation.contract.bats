# Presentation with synthetic masked values only; no credentials, authorization, or engine.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced presentation consumes shared state and doubles.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/screens.sh"
  CALLS="${BATS_TEST_TMPDIR}/calls"
  COUNT="${BATS_TEST_TMPDIR}/count"
  : > "$CALLS"
  printf '0\n' > "$COUNT"
  SCENARIO=valid
  PADDING='0 0 0 34'
  declare -gA FLOW_REVIEW=([user_name]=synthetic_user [root_account]=locked)
  flow_reached() { return 0; }
  flow_load_review() { return 0; }
  step() { printf 'step %s\n' "$1"; }
  gum() {
    local number
    printf 'gum %s\n' "$*" >> "$CALLS"
    case $1 in
      style) printf 'style %s\n' "$*" ;;
      input)
        read -r number < "$COUNT"
        number=$((number + 1))
        printf '%s\n' "$number" > "$COUNT"
        case "$SCENARIO:$number" in
          valid:*) printf 'synthetic-match\n' ;;
          errors:1 | errors:2) printf '\n' ;;
          errors:3) printf 'synthetic-one\n' ;;
          errors:4) printf 'synthetic-two\n' ;;
          errors:5) printf 'synthetic-discarded\n' ;;
          errors:6) return 1 ;;
          errors:7) return 1 ;;
          *) return 6 ;;
        esac
        ;;
    esac
  }
}

@test "password presentation uses secondary blocks and accented masked fields for both root policies" {
  local policy
  for policy in locked password; do
    FLOW_REVIEW[root_account]=$policy
    : > "$CALLS"
    capture_password() { password_form && printf 'end\n'; }
    run capture_password
    [ "$status" -eq 0 ]
    [[ "$output" == *$'One password is used for synthetic_user.'* ]]
    [[ "$output" == *$'\n\nstyle style --foreground 8'* ]]
    [[ "$output" == *$'Passwords never belong in the plan, review, or retained evidence.\n'* ]]
    grep -qxF 'gum input --password --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --prompt Password> ' "$CALLS"
    grep -qxF 'gum input --password --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --prompt Confirm> ' "$CALLS"
    if [[ $policy == locked ]]; then
      [[ "$output" == *'Root stays locked; no password is assigned to root.'* ]]
    else
      [[ "$output" == *'Root receives the same password as your user, not a second password.'* ]]
    fi
    run grep -F synthetic-match "$CALLS"
    [ "$status" -eq 1 ]
  done
}

@test "password presentation separates retry errors after instructions and clears error on Confirm Esc" {
  SCENARIO=errors
  run password_form
  [ "$status" -eq 1 ]
  [[ "$output" == *$'retained evidence.\n\nstyle style --foreground 1 --padding 0 0 0 34 Password can\x27t be blank\n\n'* ]]
  [[ "$output" == *$'retained evidence.\n\nstyle style --foreground 1 --padding 0 0 0 34 Passwords didn\x27t match\n\n'* ]]
  [ "$(grep -c '^gum style --foreground 1' "$CALLS")" -eq 2 ]
  [ "$(< "$COUNT")" -eq 7 ]
  run grep -E 'synthetic-one|synthetic-two|synthetic-discarded' "$CALLS"
  [ "$status" -eq 1 ]
}

@test "password presentation heading uses reviewed spacing and omits symbol on short consoles" {
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  LOGO_WIDTH=16
  measure_terminal() {
    TERM_WIDTH=149 TERM_HEIGHT=$ROWS PADDING_LEFT=34 LOGO_PADDING_LEFT=66
  }
  clear_logo() { printf 'logo %s\n' "${1:-full}"; }
  ROWS=40
  run step Password
  [ "$status" -eq 0 ]
  [[ "$output" == $'logo full\n\n\nstyle style --padding 0 0 0 34 Password' ]]
  ROWS=20
  run step Password
  [ "$status" -eq 0 ]
  [[ "$output" == $'logo compact\nstyle style --padding 0 0 0 34 Password' ]]
}
