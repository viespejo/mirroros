# Review presentation only: synthetic providers, no discovery, planning, credentials, or engine.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced forms consume shared state and function doubles.
# shellcheck disable=SC2030,SC2031 # Each Bats test has independent setup; state is not shared between test subshells.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/screens.sh"
  CALLS="${BATS_TEST_TMPDIR}/calls"
  CHOOSE_COUNT="${BATS_TEST_TMPDIR}/choose-count"
  : > "$CALLS"
  printf '0\n' > "$CHOOSE_COUNT"
  FLOW_TMP=$BATS_TEST_TMPDIR FLOW_PLAN_FILE=synthetic-plan
  ROWS=40 COLS=149 PLAN_STATUS=0 CLI_STATUS=0 CHOOSE_STATUS=0 PAGER_STATUS=0
  WARNINGS='' live_network_status=Connected
  ANSWERS=('Continue to confirmation')
  declare -gA FLOW_REVIEW=(
    [machine]='Recognized (reference-vm)' [disk]='/dev/vda (32.0G) [vfat, ext4]'
    [storage_option]=btrfs-limine [storage_tier]=default
    [hibernation]=true [hibernation_label]='Enabled (swapfile 4096 MiB)' [swapfile_below_ram]=false
    [rule_graphics]='Kernel driver, nothing additional' [rule_cpu_microcode]='Installs amd-ucode'
    [rule_battery]='No battery detected' [rule_virtualization]='Virtual machine'
    [timezone]=Europe/Madrid [lang]=en_US.UTF-8 [regional_format]=follow_language
    [format_locale]=en_US.UTF-8 [locales]=en_US.UTF-8 [user_name]=mirroros
    [root_account]=locked [hostname]=synthetic-host [console_keymap]=us [plan_reference]=0123456789ab
  )
  ui_interactive() { return 1; }
  measure_terminal() {
    TERM_WIDTH=$COLS TERM_HEIGHT=$ROWS
    PADDING_LEFT=$(((COLS > 80 ? COLS - 80 : 0) / 2))
    printf -v PADDING_LEFT_SPACES '%*s' "$PADDING_LEFT" ''
    LOGO_PADDING_LEFT=0
    PADDING="0 0 0 $PADDING_LEFT"
  }
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    case $1 in
      style)
        shift
        while [[ ${1:-} == --* ]]; do shift 2; done
        printf '%s\n' "$@"
        ;;
      choose)
        [[ $CHOOSE_STATUS == 0 ]] || return "$CHOOSE_STATUS"
        local count
        read -r count < "$CHOOSE_COUNT"
        printf '%s\n' "$((count + 1))" > "$CHOOSE_COUNT"
        printf '%s\n' "${ANSWERS[count]}"
        ;;
      pager)
        tee "${BATS_TEST_TMPDIR}/pager-input" > /dev/null
        return "$PAGER_STATUS"
        ;;
    esac
  }
  flow_ensure_plan() { printf 'ensure\n' >> "$CALLS"; return "$PLAN_STATUS"; }
  flow_reached() { printf 'reached %s\n' "$1" >> "$CALLS"; }
  flow_load_review() { printf 'load review\n' >> "$CALLS"; }
  flow_assistant() {
    [[ $1 == review-warnings && $2 == "$FLOW_PLAN_FILE" ]] || return 6
    if [[ -n $WARNINGS ]]; then printf '%s\n' "$WARNINGS"; fi
  }
  flow_cli() {
    [[ $1 == review && $2 == complete && $3 == "$FLOW_PLAN_FILE" ]] || return 6
    [[ $CLI_STATUS == 0 ]] || return "$CLI_STATUS"
    printf 'Synthetic complete plan.\nThis plan is not approved.\nPlan reference: 0123456789ab\n'
  }
  flow_confirmed() { printf 'unexpected authorization\n' >> "$CALLS"; return 99; }
  measure_terminal
}

@test "review warnings preserve full text aligned continuations and bounded lines at wide and narrow sizes" {
  local width line limit
  local warning='Below detected memory: hibernation may be unavailable under large memory workloads. It depends on used memory and free swapfile space.'
  local long_word
  printf -v long_word '%090d' 0
  for width in 149 74 1; do
    COLS=$width
    measure_terminal
    limit=80
    if ((width < 80)); then limit=$((width > 1 ? width - 1 : 1)); fi
    run ui_warning_block "$warning" "$long_word"
    [ "$status" -eq 0 ]
    [ "${output//[[:space:]]/}" = "${warning//[[:space:]]/}$long_word" ]
    while IFS= read -r line; do [ "${#line}" -le "$limit" ]; done <<< "$output"
    grep -qF "gum style --foreground 3 --padding $PADDING " "$CALLS"
  done
}

@test "review retains every row safety text and separated shared selector without warnings" {
  run review_form
  [ "$status" -eq 0 ]
  [[ "$output" == *'synthetic-host'* ]]
  [[ "$output" == *'0123456789ab'* ]]
  [[ "$output" == *'Installs amd-ucode'* ]]
  [[ "$output" == *'Enabled (swapfile 4096 MiB)'* ]]
  [[ "$output" == *$'After the base system is verified, the graphical environment is configured.\n\n\nReview only:'* ]]
  [[ "$output" == *'Review only: this does not approve a plan or authorize disk changes.'* ]]
  local next='Next: confirm the disk to erase, then set the password. Installation starts after that.'
  [[ "${output//[[:space:]]/}" == *"${next//[[:space:]]/}"* ]]
  grep -qxF 'gum choose --header  --cursor ›  --cursor.foreground 4 --cursor.background 0 --selected.foreground 4 --selected.background 0 --item.foreground 7 --show-help --height 3 --selected Continue to confirmation Continue to confirmation Inspect complete plan Back' "$CALLS"
  run grep -q 'gum style --foreground 3' "$CALLS"
  [ "$status" -eq 1 ]
}

@test "review multiple warnings and disabled hibernation retain complete conditional information" {
  WARNINGS=$'This machine matches no known profile; installing on it is experimental.\nThe target disk has no stable by_id; it is addressed by its path, which can change between boots.'
  FLOW_REVIEW[swapfile_below_ram]=true
  run review_form
  [ "$status" -eq 0 ]
  [[ "$output" == *'This machine matches no known profile; installing on it is experimental.'* ]]
  [[ "$output" == *'Below detected memory:'* ]]
  [[ "$output" == *'free swapfile space.'* ]]
  [ "$(grep -cE '^(This machine|The target disk|Below detected memory)' "${FLOW_TMP}/review-body.txt")" -eq 3 ]
  printf '0\n' > "$CHOOSE_COUNT"
  FLOW_REVIEW[hibernation]=false FLOW_REVIEW[hibernation_label]='Disabled (no swapfile)'
  FLOW_REVIEW[swapfile_below_ram]=false WARNINGS=''
  run review_form
  [ "$status" -eq 0 ]
  [[ "$output" == *'Disabled (no swapfile)'* ]]
  [[ "$output" == *'Hibernation is disabled: no swapfile will be created.'* ]]
  [[ "$output" != *'Below detected memory:'* ]]
}

@test "review complete plan keeps exact text blue-gray border return statuses and no authorization" {
  local code
  ANSWERS=('Inspect complete plan' 'Continue to confirmation')
  for code in 0 1 130 5; do
    printf '0\n' > "$CHOOSE_COUNT"
    PAGER_STATUS=$code
    run review_form
    if [[ $code == 0 || $code == 1 ]]; then
      [ "$status" -eq 0 ]
    else
      [ "$status" -eq "$code" ]
    fi
    cmp "${FLOW_TMP}/complete-plan.txt" "${BATS_TEST_TMPDIR}/pager-input"
  done
  grep -qxF 'gum pager --border-foreground 4' "$CALLS"
  [ "${FLOW_REVIEW[hostname]}" = synthetic-host ]
  run grep -q 'unexpected authorization' "$CALLS"
  [ "$status" -eq 1 ]
  printf '0\n' > "$CHOOSE_COUNT"
  CLI_STATUS=5
  run review_form
  [ "$status" -eq 6 ]
}

@test "review preserves Back Esc Ctrl+C and plan failure before rendering" {
  ANSWERS=(Back)
  run review_form
  [ "$status" -eq 1 ]
  local code
  for code in 1 130 6; do
    CHOOSE_STATUS=$code
    run review_form
    [ "$status" -eq "$code" ]
  done
  : > "$CALLS"
  PLAN_STATUS=2
  run review_form
  [ "$status" -eq 2 ]
  [ "$(wc -l < "$CALLS")" -eq 1 ]
  grep -qxF ensure "$CALLS"
}

@test "review heading omits symbol and retains two top margin lines at every height" {
  local height
  for height in 40 20; do
    ROWS=$height
    run step 'Review your choices'
    [ "$status" -eq 0 ]
    [ "$output" = $'\033[H\033[2J\033[0m\033[37m\n\nReview your choices' ]
    [[ "$output" != *'█'* ]]
  done
}
