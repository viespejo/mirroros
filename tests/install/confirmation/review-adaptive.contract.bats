# Adaptive review only: synthetic values and providers, no planning, secrets, or installation.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced presentation functions consume shared state and doubles.
# shellcheck disable=SC2030,SC2031 # Each Bats test has independent setup and state.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/screens.sh"
  FLOW_TMP=$BATS_TEST_TMPDIR FLOW_PLAN_FILE=synthetic-plan
  CALLS="${BATS_TEST_TMPDIR}/calls"
  CHOOSE_COUNT="${BATS_TEST_TMPDIR}/choose-count"
  PAGER_COUNT="${BATS_TEST_TMPDIR}/pager-count"
  : > "$CALLS"
  printf '0\n' > "$CHOOSE_COUNT"
  printf '0\n' > "$PAGER_COUNT"
  COLS=149 ROWS=60 CHOOSE_STATUS=0 PAGER_STATUS=0
  ANSWERS=('Continue to confirmation')
  WARNINGS=$'This machine matches no known profile; installing on it is experimental.\nThe target disk has no stable by_id; it is addressed by its path, which can change between boots.'
  live_network_status=Connected
  declare -gA FLOW_REVIEW=(
    [machine]='Unqualified (experimental)' [disk]='/dev/vda (32.0G) [vfat, ext4]'
    [storage_option]=btrfs-limine [storage_tier]=default
    [hibernation]=true [hibernation_label]='Enabled (swapfile 4096 MiB)' [swapfile_below_ram]=true
    [rule_graphics]='Kernel driver, nothing additional' [rule_cpu_microcode]='Installs amd-ucode'
    [rule_battery]='No battery detected' [rule_virtualization]='Virtual machine'
    [timezone]=Europe/Madrid [lang]=en_US.UTF-8 [regional_format]=follow_language
    [format_locale]=en_US.UTF-8 [locales]=en_US.UTF-8 [user_name]=mirroros
    [root_account]=locked [hostname]=mirroros [console_keymap]=us [plan_reference]=0123456789ab
  )
  ui_interactive() { return 1; }
  measure_terminal() {
    TERM_WIDTH=$COLS TERM_HEIGHT=$ROWS
    PADDING_LEFT=$(((COLS > 80 ? COLS - 80 : 0) / 2))
    printf -v PADDING_LEFT_SPACES '%*s' "$PADDING_LEFT" ''
    PADDING="0 0 0 $PADDING_LEFT"
    LOGO_PADDING_LEFT=0
  }
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    local count
    case $1 in
      style)
        shift
        while [[ ${1:-} == --* ]]; do shift 2; done
        printf '%s\n' "$@"
        ;;
      choose)
        [[ $CHOOSE_STATUS == 0 ]] || return "$CHOOSE_STATUS"
        read -r count < "$CHOOSE_COUNT"
        printf '%s\n' "$((count + 1))" > "$CHOOSE_COUNT"
        printf '%s\n' "${ANSWERS[count]}"
        ;;
      pager)
        read -r count < "$PAGER_COUNT"
        count=$((count + 1))
        printf '%s\n' "$count" > "$PAGER_COUNT"
        tee "${BATS_TEST_TMPDIR}/pager-${count}.txt" > /dev/null
        return "$PAGER_STATUS"
        ;;
    esac
  }
  flow_ensure_plan() { printf 'ensure\n' >> "$CALLS"; }
  flow_reached() { printf 'reached %s\n' "$1" >> "$CALLS"; }
  flow_load_review() { printf 'load review\n' >> "$CALLS"; }
  flow_assistant() {
    [[ $1 == review-warnings && $2 == "$FLOW_PLAN_FILE" ]] || return 6
    if [[ -n $WARNINGS ]]; then printf '%s\n' "$WARNINGS"; fi
  }
  flow_cli() {
    [[ $1 == review && $2 == complete && $3 == "$FLOW_PLAN_FILE" ]] || return 6
    printf 'Synthetic complete plan.\nThis plan is not approved.\nPlan reference: 0123456789ab\n'
  }
  flow_confirmed() { printf 'unexpected authorization\n' >> "$CALLS"; return 99; }
}

@test "review-adaptive exact height retains original rows and a two-row deficit groups only fitting lines" {
  review_select_layout
  [ "$REVIEW_GROUP_ACCOUNTS" = false ]
  [ "$REVIEW_GROUP_LOCALE" = false ]
  [ "$REVIEW_PAGED" = false ]
  [ "$REVIEW_REQUIRED_ROWS" -eq 42 ]
  ROWS=$REVIEW_REQUIRED_ROWS
  # The disposable demo's force variable has no effect in production.
  REVIEW_PREVIEW_FORCE_OVERFLOW=2
  review_select_layout
  [ "$REVIEW_GROUP_ACCOUNTS" = false ]
  [ "$REVIEW_GROUP_LOCALE" = false ]
  ROWS=$((ROWS - 2))
  review_select_layout
  [ "$REVIEW_GROUP_ACCOUNTS" = true ]
  [ "$REVIEW_GROUP_LOCALE" = true ]
  [ "$REVIEW_PAGED" = false ]
  [ "$REVIEW_REQUIRED_ROWS" -le "$ROWS" ]
  grep -qxF 'Hostname: mirroros | Username: mirroros | Root: Locked (default)' "$REVIEW_BODY_FILE"
  grep -qxF 'Timezone: Europe/Madrid | Language: en_US.UTF-8 | Locales: en_US.UTF-8' "$REVIEW_BODY_FILE"
}

@test "review-adaptive long account and locale groups stay separate without losing values or horizontal fit" {
  ROWS=20
  printf -v FLOW_REVIEW[hostname] '%064d' 0
  review_select_layout
  [ "$REVIEW_GROUP_ACCOUNTS" = false ]
  [ "$REVIEW_GROUP_LOCALE" = true ]
  [ "$REVIEW_PAGED" = true ]
  FLOW_REVIEW[hostname]=mirroros
  FLOW_REVIEW[timezone]=America/Argentina/Buenos_Aires
  FLOW_REVIEW[locales]='en_US.UTF-8 es_ES.UTF-8'
  review_select_layout
  [ "$REVIEW_GROUP_ACCOUNTS" = true ]
  [ "$REVIEW_GROUP_LOCALE" = false ]
  grep -qF America/Argentina/Buenos_Aires "$REVIEW_BODY_FILE"
  grep -qF 'en_US.UTF-8 es_ES.UTF-8' "$REVIEW_BODY_FILE"
  local line
  while IFS= read -r line; do [ "${#line}" -le "$REVIEW_WIDTH" ]; done < "$REVIEW_BODY_FILE"
}

@test "review-adaptive doubled-size geometry pages full wrapped content and recalculates when space returns" {
  COLS=74 ROWS=20
  review_select_layout
  [ "$REVIEW_PAGED" = true ]
  [ "$REVIEW_REQUIRED_ROWS" -gt "$ROWS" ]
  local line content=''
  while IFS= read -r line; do
    [ "${#line}" -le 73 ]
    content+=$line
  done < "$REVIEW_BODY_FILE"
  local warning='Below detected memory: hibernation may be unavailable under large memory workloads. It depends on used memory and free swapfile space.'
  [[ "${content//[[:space:]]/}" == *"${warning//[[:space:]]/}"* ]]
  COLS=149 ROWS=60
  review_select_layout
  [ "$REVIEW_PAGED" = false ]
  [ "$REVIEW_GROUP_ACCOUNTS" = false ]
  [ "$REVIEW_GROUP_LOCALE" = false ]
}

@test "review-adaptive paged inspection can reopen review and complete plan without changing answers or authorizing" {
  COLS=74 ROWS=20
  ANSWERS=('Inspect review' 'Inspect complete plan' Back)
  run review_form
  [ "$status" -eq 1 ]
  [ "$(< "$PAGER_COUNT")" -eq 4 ]
  cmp "${BATS_TEST_TMPDIR}/pager-1.txt" "${BATS_TEST_TMPDIR}/pager-2.txt"
  cmp "${BATS_TEST_TMPDIR}/pager-1.txt" "${BATS_TEST_TMPDIR}/pager-4.txt"
  cmp "${BATS_TEST_TMPDIR}/complete-plan.txt" "${BATS_TEST_TMPDIR}/pager-3.txt"
  grep -qF -- '--height 4 --selected Continue to confirmation Continue to confirmation Inspect review Inspect complete plan Back' "$CALLS"
  grep -qxF 'gum pager --border-foreground 4' "$CALLS"
  [ "$(grep -c '^ensure$' "$CALLS")" -eq 1 ]
  [ "${FLOW_REVIEW[hostname]}" = mirroros ]
  [ "${FLOW_REVIEW[plan_reference]}" = 0123456789ab ]
  run grep -q 'unexpected authorization' "$CALLS"
  [ "$status" -eq 1 ]
}

@test "review-adaptive paged Esc returns to navigation while Ctrl+C and failures never reach its menu" {
  COLS=74 ROWS=20
  local code
  for code in 130 5; do
    : > "$CALLS"
    PAGER_STATUS=$code
    run review_form
    [ "$status" -eq "$code" ]
    run grep -q 'gum choose' "$CALLS"
    [ "$status" -eq 1 ]
  done
  PAGER_STATUS=1
  run review_form
  [ "$status" -eq 0 ]
  grep -q 'gum choose' "$CALLS"
  run grep -q 'unexpected authorization' "$CALLS"
  [ "$status" -eq 1 ]
}

@test "review-adaptive disabled hibernation and private render failure preserve safety boundaries" {
  COLS=74 ROWS=20
  FLOW_REVIEW[hibernation]=false FLOW_REVIEW[hibernation_label]='Disabled (no swapfile)'
  FLOW_REVIEW[swapfile_below_ram]=false WARNINGS=''
  review_select_layout
  grep -qF 'Disabled (no swapfile)' "$REVIEW_BODY_FILE"
  grep -qF 'Hibernation is disabled: no swapfile will be created.' "$REVIEW_BODY_FILE"
  run grep -qF 'Below detected memory:' "$REVIEW_BODY_FILE"
  [ "$status" -eq 1 ]
  FLOW_TMP="${BATS_TEST_TMPDIR}/missing-directory"
  : > "$CALLS"
  run review_form
  [ "$status" -eq 6 ]
  run grep -qE 'gum (choose|pager)' "$CALLS"
  [ "$status" -eq 1 ]
}
