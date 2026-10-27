# Account presentation only: synthetic providers, no planning, credentials, or account operations.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced forms consume shared state and function doubles.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/screens.sh"
  CALLS="${BATS_TEST_TMPDIR}/calls"
  INPUT_COUNT="${BATS_TEST_TMPDIR}/input-count"
  : > "$CALLS"
  printf '0\n' > "$INPUT_COUNT"
  FLOW_INVALID_TEXT="${BATS_TEST_TMPDIR}/invalid.tsv"
  printf 'Synthetic hostname rejection.\tTry a valid synthetic hostname.\n' > "$FLOW_INVALID_TEXT"
  INPUT_STATUS=0 CHOOSE_STATUS=0 REJECT=false APPLY_STATUS=0
  ANSWER='Locked (default)' ROWS=40 COLS=149
  INPUT_VALUES=('synthetic-host' 'synthetic-user')
  declare -gA CHOICES=([hostname]=mirroros [user_name]=mirroros [root_account]=locked)
  ui_interactive() { return 1; }
  measure_terminal() {
    TERM_WIDTH=$COLS TERM_HEIGHT=$ROWS
    PADDING_LEFT=$(((COLS > 80 ? COLS - 80 : 0) / 2))
    LOGO_PADDING_LEFT=$(((COLS - LOGO_WIDTH) / 2))
    PADDING="0 0 0 $PADDING_LEFT"
  }
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    case $1 in
      style) printf 'style %s\n' "$*" ;;
      input)
        [[ $INPUT_STATUS == 0 ]] || return "$INPUT_STATUS"
        local count
        read -r count < "$INPUT_COUNT"
        printf '%s\n' "$((count + 1))" > "$INPUT_COUNT"
        printf '%s\n' "${INPUT_VALUES[count]}"
        ;;
      choose)
        [[ $CHOOSE_STATUS == 0 ]] || return "$CHOOSE_STATUS"
        printf '%s\n' "$ANSWER"
        ;;
    esac
  }
  flow_choice() { printf '%s\n' "${CHOICES[$1]}"; }
  flow_apply_choice() {
    printf 'apply %s %s\n' "$1" "$2" >> "$CALLS"
    if [[ $REJECT == true ]]; then REJECT=false; return 1; fi
    [[ $APPLY_STATUS == 0 ]] || return "$APPLY_STATUS"
    CHOICES[$1]=$2
  }
}

@test "accounts hostname retry separates provider error and preserves rejected value and blank default" {
  step() { printf 'step %s\n' "$*"; }
  INPUT_VALUES=('bad name' '') REJECT=true
  capture_retry() { hostname_form && printf 'end\n'; }
  run capture_retry
  [ "$status" -eq 0 ]
  [[ "$output" == *$'Try a valid synthetic hostname.\n\n'* ]]
  grep -qF -- '--value bad name --placeholder' "$CALLS"
  grep -qxF 'apply hostname mirroros' "$CALLS"
}

@test "accounts username retry places unchanged error after instructions with separated blocks" {
  step() { printf 'step %s\n' "$*"; }
  INPUT_VALUES=(root synthetic_user) REJECT=true
  capture_retry() { username_form && printf 'end\n'; }
  run capture_retry
  [ "$status" -eq 0 ]
  [[ "$output" == *$'with sudo.\n\nstyle style --foreground 1'* ]]
  [[ "$output" == *$'The name root is reserved.\n\n'* ]]
  grep -qxF 'apply user_name root' "$CALLS"
  grep -qxF 'apply user_name synthetic_user' "$CALLS"
  grep -qF -- '--value root --placeholder' "$CALLS"
}

@test "accounts root variants preserve current selection conditional disclaimer and mappings" {
  root_account_form > "${BATS_TEST_TMPDIR}/root-output"
  [ "${CHOICES[root_account]}" = locked ]
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 One password is asked, with repetition, after you approve the plan.' "$CALLS"
  grep -qF 'gum choose --header  --cursor › ' "$CALLS"
  grep -qF -- '--show-help --height 5 --selected Locked (default) Locked (default) Password login enabled' "$CALLS"
  run grep -qF 'Sharing the password' "$CALLS"
  [ "$status" -eq 1 ]
  CHOICES[root_account]=password ANSWER='Locked (default)'
  root_account_form > "${BATS_TEST_TMPDIR}/root-output"
  grep -qF -- '--selected Password login enabled Locked (default) Password login enabled' "$CALLS"
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 Sharing the password does not give root an independent recovery credential.' "$CALLS"
  [ "${CHOICES[root_account]}" = locked ]
  ANSWER='Password login enabled'
  root_account_form > /dev/null
  [ "${CHOICES[root_account]}" = password ]
}

@test "accounts forms preserve Esc Ctrl+C and provider failures without incomplete updates" {
  local form code
  for form in hostname_form username_form root_account_form; do
    for code in 1 130; do
      INPUT_STATUS=$code CHOOSE_STATUS=$code
      run "$form"
      [ "$status" -eq "$code" ]
    done
  done
  run grep -q '^apply ' "$CALLS"
  [ "$status" -eq 1 ]
  INPUT_STATUS=0 CHOOSE_STATUS=0 APPLY_STATUS=6
  for form in hostname_form username_form root_account_form; do
    printf '0\n' > "$INPUT_COUNT"
    run "$form"
    [ "$status" -eq 6 ]
  done
}

@test "accounts headings match welcome spacing and omit the symbol on short consoles" {
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  LOGO_WIDTH=16
  local title
  step 'Welcome to MirrorOS' > "${BATS_TEST_TMPDIR}/welcome-output"
  for title in 'Name your machine' "Let's setup your user account..." 'Choose root account policy'; do
    step "$title" > "${BATS_TEST_TMPDIR}/screen-output"
    # Compare the heading's symbol and spacing, not its title.
    [ "$(grep -c '█' "${BATS_TEST_TMPDIR}/screen-output")" -eq "$(grep -c '█' "${BATS_TEST_TMPDIR}/welcome-output")" ]
    [ "$(wc -l < "${BATS_TEST_TMPDIR}/screen-output")" -eq "$(wc -l < "${BATS_TEST_TMPDIR}/welcome-output")" ]
  done
  ROWS=20 COLS=74
  for title in 'Name your machine' "Let's setup your user account..." 'Choose root account policy'; do
    run step "$title"
    [ "$status" -eq 0 ]
    [[ "$output" != *'█'* ]]
    grep -qF "$title" "$CALLS"
  done
}
