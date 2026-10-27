# Adaptive diagnostics only: synthetic providers, Gum, logs, records, and power doubles.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced functions consume shared state and doubles.
# shellcheck disable=SC2030,SC2031 # Bats isolates run calls and test state.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/flow.sh"
  FLOW_TMP="${BATS_TEST_TMPDIR}/private"
  LOGO_PATH="${BATS_TEST_TMPDIR}/symbol.txt"
  printf 'synthetic-symbol\nsecond-symbol-row\nthird-symbol-row\n' > "$LOGO_PATH"
  local segment
  printf -v segment 'synthetic-%0120d' 0
  FLOW_RUN_DIR="${BATS_TEST_TMPDIR}/${segment}/${segment}/run"
  mkdir -p "$FLOW_TMP" "${FLOW_RUN_DIR}/engine" "${FLOW_RUN_DIR}/plans" "${FLOW_RUN_DIR}/discovery/initial"
  RECORD="${FLOW_RUN_DIR}/engine/engine-run.json"
  LOG="${FLOW_RUN_DIR}/engine/engine.log"
  printf '%s\n' '{"postconditions":{"checks":[{"id":"kernel_installed","status":"passed"},{"id":"boot_resume_parameters","status":"failed","detail":"Expected the approved resume device and offset in the synthetic boot entry; observed a different offset. No live system is checked."},{"id":"network_manager_enabled","status":"failed","detail":"Expected NetworkManager.service enabled; observed disabled in the synthetic target."}]}}' > "$RECORD"
  printf '%s\n' '[synthetic] Earlier log line excluded from the tail.' > "$LOG"
  for index in {1..15}; do
    printf '[synthetic %02d] Could not validate /preview/target/usr/lib/systemd/system/synthetic-service-with-a-long-name.service: expected an enabled unit with its required configuration; observed an unavailable dependency.\n' "$index" >> "$LOG"
  done
  printf '{}\n' > "${FLOW_RUN_DIR}/discovery/initial/target-facts.json"
  FLOW_ENGINE_FAILED_OPERATION=install_packages FLOW_ENGINE_FAILED_STATUS=5 FLOW_ENGINE_DESTRUCTIVE=true
  FLOW_ENGINE_UNVERIFIED=false FLOW_PLAN_ARG='' FLOW_PLAN_FILE='' FLOW_PLAN_SEQ=0
  FLOW_CHOICES="${FLOW_TMP}/choices.json" FLOW_PLAN_CHOICES="${FLOW_TMP}/plan-choices.json"
  FLOW_STDERR="${FLOW_TMP}/stderr" FLOW_INVALID_TEXT="${FLOW_TMP}/invalid.tsv"
  printf '{}\n' > "$FLOW_CHOICES"
  CALLS="${BATS_TEST_TMPDIR}/calls" POWER="${BATS_TEST_TMPDIR}/power"
  CHOOSE_COUNT="${BATS_TEST_TMPDIR}/choose-count" PAGER_COUNT="${BATS_TEST_TMPDIR}/pager-count"
  : > "$CALLS"
  : > "$POWER"
  printf '0\n' > "$CHOOSE_COUNT"
  printf '0\n' > "$PAGER_COUNT"
  COLS=74 ROWS=20 PAGER_STATUS=0 CHOOSE_STATUS=0
  ANSWERS=('Return to shell')
  printf -v CAUSE '%01200d' 0
  CAUSE="Synthetic diagnostic: $CAUSE"
  NEXT_STEP='Regenerate and review the installation plan.'
  CONFIGURE_STEP=desktop/compositor/providers/hyprland
  measure_terminal() {
    TERM_WIDTH=$COLS TERM_HEIGHT=$ROWS
    PADDING_LEFT=$(((COLS > 80 ? COLS - 80 : 0) / 2))
    PADDING="0 0 0 $PADDING_LEFT"
  }
  ui_interactive() { return 1; }
  flow_leave_interactive() { :; }
  flow_enter_interactive() { :; }
  flow_log() { :; }
  flow_log_diagnostics() { :; }
  flow_reached() { :; }
  timing_end() { :; }
  timing_end_all() { :; }
  timing_json() { printf '{}\n'; }
  flow_cancel() { printf 'cancel %s\n' "$1" >> "$CALLS"; exit 3; }
  flow_power_action() { printf '%s\n' "$1" >> "$POWER"; }
  flow_run_discovery() { printf 'discover\n' >> "$CALLS"; return 2; }
  flow_plan() { printf 'plan\n' >> "$CALLS"; return 2; }
  flow_cli() {
    case $1 in
      reasons) printf '[]\n' ;;
      record) printf 'record %s %s\n' "$7" "$8" >> "$CALLS" ;;
      *) return 6 ;;
    esac
  }
  flow_assistant() {
    case $1 in
      recoverable) return 0 ;;
      reasons-text) printf '%s\t%s\n' "$CAUSE" "$NEXT_STEP" ;;
      get) printf '%s\n' "$CONFIGURE_STEP" ;;
      *) return 6 ;;
    esac
  }
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    local kind=$1 padding=0 text line count
    shift
    case $kind in
      style)
        while (($#)); do
          case $1 in
            --foreground) shift 2 ;;
            --padding) padding=${2##* }; shift 2 ;;
            *) break ;;
          esac
        done
        for text in "$@"; do
          while IFS= read -r line; do printf '%*s%s\n' "$padding" '' "$line"; done <<< "$text"
        done
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
      *) return 6 ;;
    esac
  }
  compact() { tr -d '[:space:]'; }
}

@test "error-adaptive exact fit stays inline and a one-row deficit pages the full sanitized tail" {
  COLS=149 ROWS=300
  ui_diagnostic_select_layout 4 "$FLOW_RUN_DIR" ui_engine_failure install_packages 5 true "$LOG" "$FLOW_RUN_DIR"
  [ "$UI_DIAGNOSTIC_PAGED" = false ]
  ROWS=$UI_DIAGNOSTIC_REQUIRED_ROWS
  ui_diagnostic_select_layout 4 "$FLOW_RUN_DIR" ui_engine_failure install_packages 5 true "$LOG" "$FLOW_RUN_DIR"
  [ "$UI_DIAGNOSTIC_PAGED" = false ]
  ROWS=$((ROWS - 1))
  ui_diagnostic_select_layout 4 "$FLOW_RUN_DIR" ui_engine_failure install_packages 5 true "$LOG" "$FLOW_RUN_DIR"
  [ "$UI_DIAGNOSTIC_PAGED" = true ]
  local content line
  content=$(compact < "$UI_DIAGNOSTIC_FILE")
  [[ "$content" == *'[synthetic01]'* && "$content" == *'[synthetic15]'* ]]
  [[ "$content" != *'Earlierlogline'* ]]
  [[ "$content" == *"Rundirectory:$FLOW_RUN_DIR"* ]]
  while IFS= read -r line; do
    [ "${#line}" -le 80 ]
    [[ $line != *$'\033'* ]]
  done < "$UI_DIAGNOSTIC_FILE"
}

@test "error-adaptive narrow engine inspector reopens without losing warning defaults or full log" {
  ANSWERS=('Inspect diagnostic' 'View full log' 'Return to shell')
  run flow_failure_menu
  [ "$status" -eq 0 ]
  [ "$(< "$PAGER_COUNT")" -eq 3 ]
  cmp "${BATS_TEST_TMPDIR}/pager-1.txt" "${BATS_TEST_TMPDIR}/pager-2.txt"
  cmp "$LOG" "${BATS_TEST_TMPDIR}/pager-3.txt"
  grep -qF -- '--height 5 --selected Return to shell Inspect diagnostic View full log Return to shell Restart Power off' "$CALLS"
  [[ "$output" == *'The disk was partially modified and installation did not complete.'* ]]
  [[ "$output" != *'[synthetic 01]'* ]]
  [ ! -s "$POWER" ]
  local line
  while IFS= read -r line; do [ "${#line}" -le 73 ]; done < "${BATS_TEST_TMPDIR}/pager-1.txt"
}

@test "error-adaptive verification preserves every failed check and the unmodified engine variant stays truthful" {
  FLOW_ENGINE_UNVERIFIED=true
  run flow_failure_menu
  [ "$status" -eq 0 ]
  local content
  content=$(compact < "${BATS_TEST_TMPDIR}/pager-1.txt")
  [[ "$content" == *'Failedcheck:boot_resume_parameters'* && "$content" == *'Failedcheck:network_manager_enabled'* ]]
  [[ "$content" != *kernel_installed* ]]
  [[ "${output//[[:space:]]/}" == *'Donotrelyonit.'* ]]
  FLOW_ENGINE_UNVERIFIED=false FLOW_ENGINE_DESTRUCTIVE=false
  printf '0\n' > "$CHOOSE_COUNT"
  run flow_failure_menu
  [ "$status" -eq 0 ]
  [[ "$output" == *'The disk was not modified.'* ]]
  [[ "$output" != *'The disk was partially modified'* ]]
  [ ! -s "$POWER" ]
}

@test "error-adaptive configure retains recovery known and unknown steps and configure-only log inspection" {
  printf '%s\n' '[synthetic] Base log excluded.' '== configure ==' '[synthetic] Configure-only diagnostic.' > "$LOG"
  ANSWERS=('View configure log' 'Return to shell')
  local step content
  for step in desktop/compositor/providers/hyprland unknown; do
    CONFIGURE_STEP=$step
    printf '0\n' > "$CHOOSE_COUNT"
    printf '0\n' > "$PAGER_COUNT"
    run flow_configure_menu
    [ "$status" -eq 0 ]
    [ "$(< "$PAGER_COUNT")" -eq 2 ]
    content=$(compact < "${BATS_TEST_TMPDIR}/pager-1.txt")
    [[ "$content" == *"failedatstep${step}."* ]]
    [[ "${output//[[:space:]]/}" == *'Boottheinstalledsystem,loginattheconsole,andrunsudomirroros-configure.'* ]]
    [ "$(< "${BATS_TEST_TMPDIR}/pager-2.txt")" = $'== configure ==\n[synthetic] Configure-only diagnostic.' ]
  done
  grep -qF -- '--height 5 --selected Return to shell Inspect diagnostic View configure log Restart Return to shell Power off' "$CALLS"
  [ ! -s "$POWER" ]
}

@test "error-adaptive recoverable discovery inspection neither retries discovery nor changes Retry default" {
  ANSWERS=('Inspect diagnostic' Back)
  run flow_discover_initial
  [ "$status" -eq 1 ]
  [ "$(grep -c '^discover$' "$CALLS")" -eq 1 ]
  [ "$(< "$PAGER_COUNT")" -eq 2 ]
  cmp "${BATS_TEST_TMPDIR}/pager-1.txt" "${BATS_TEST_TMPDIR}/pager-2.txt"
  grep -qF -- '--height 4 --selected Retry Inspect diagnostic Retry Back Cancel' "$CALLS"
  [ ! -s "$POWER" ]
}

@test "error-adaptive rejected plan inspection keeps the last valid plan without regeneration" {
  FLOW_PLAN_FILE="${FLOW_TMP}/last-valid-plan.json"
  printf 'synthetic last valid plan\n' > "$FLOW_PLAN_FILE"
  printf 'different choices\n' > "$FLOW_PLAN_CHOICES"
  ANSWERS=('Inspect diagnostic' Back)
  run flow_ensure_plan
  [ "$status" -eq 1 ]
  [ "$(grep -c '^plan$' "$CALLS")" -eq 1 ]
  [ "$(< "$PAGER_COUNT")" -eq 2 ]
  [ "$(< "$FLOW_PLAN_FILE")" = 'synthetic last valid plan' ]
  [ ! -d "${FLOW_RUN_DIR}/plans/01" ]
  grep -qF -- '--height 3 --selected Back Inspect diagnostic Back Cancel' "$CALLS"
  [ ! -s "$POWER" ]
}

@test "error-adaptive terminal diagnostics retain full cause and evidence without adding menus or replacing error outcomes" {
  local code content
  for code in 0 1 130 5; do
    PAGER_STATUS=$code
    printf '0\n' > "$PAGER_COUNT"
    run bash_terminal_failure
    [ "$status" -eq 2 ]
    content=$(compact < "${BATS_TEST_TMPDIR}/pager-1.txt")
    [[ "$content" == *"${CAUSE//[[:space:]]/}"* && "$content" == *"Evidence:$FLOW_RUN_DIR"* ]]
    [[ "${output//[[:space:]]/}" == *"Next:${NEXT_STEP//[[:space:]]/}"* ]]
  done
  run grep -q 'gum choose' "$CALLS"
  [ "$status" -eq 1 ]
  [ ! -s "$POWER" ]
}

bash_terminal_failure() {
  flow_failure_presentation 0 'Machine memory' "$CAUSE" "$NEXT_STEP"
  flow_finish 2 blocked memory_check
}

@test "error-adaptive interactive pager cancellation cancels while final inspector failures retain recorded outcomes" {
  PAGER_STATUS=130
  run flow_discover_initial
  [ "$status" -eq 3 ]
  grep -qxF 'cancel discovery_initial' "$CALLS"
  local code
  for code in 130 5; do
    PAGER_STATUS=$code FLOW_EXIT_MENU=flow_failure_menu
    : > "$CALLS"
    run flow_finish 4 not_verified engine
    [ "$status" -eq 4 ]
    grep -qxF 'record 4 not_verified' "$CALLS"
    run grep -q 'gum choose' "$CALLS"
    [ "$status" -eq 1 ]
  done
  [ ! -s "$POWER" ]
}

@test "error-adaptive final power actions still require explicit selection and layout recalculates" {
  local choice
  for choice in Restart 'Power off'; do
    ANSWERS=("$choice")
    printf '0\n' > "$CHOOSE_COUNT"
    : > "$POWER"
    run flow_failure_menu
    [ "$status" -eq 0 ]
    if [[ $choice == Restart ]]; then [ "$(< "$POWER")" = reboot ]; else [ "$(< "$POWER")" = poweroff ]; fi
  done
  ui_diagnostic_select_layout 0 "$FLOW_RUN_DIR" ui_failure 'Machine memory' "$CAUSE" "$NEXT_STEP"
  [ "$UI_DIAGNOSTIC_PAGED" = true ]
  ROWS=100 COLS=149
  ui_diagnostic_select_layout 0 "$FLOW_RUN_DIR" ui_failure 'Machine memory' "$CAUSE" "$NEXT_STEP"
  [ "$UI_DIAGNOSTIC_PAGED" = false ]
}

@test "error-adaptive logo requires complete fit and summary gets an independent symbol budget" {
  COLS=149 ROWS=300
  ui_diagnostic_select_layout 4 "$FLOW_RUN_DIR" ui_failure 'Machine memory' "$CAUSE" "$NEXT_STEP"
  [ "$UI_DIAGNOSTIC_LOGO" = true ]
  ROWS=$((UI_DIAGNOSTIC_REQUIRED_ROWS + 5))
  [ "$ROWS" -ge 32 ]
  ui_diagnostic_select_layout 4 "$FLOW_RUN_DIR" ui_failure 'Machine memory' "$CAUSE" "$NEXT_STEP"
  [ "$UI_DIAGNOSTIC_LOGO" = true ]
  ROWS=$((ROWS - 1))
  ui_diagnostic_select_layout 4 "$FLOW_RUN_DIR" ui_failure 'Machine memory' "$CAUSE" "$NEXT_STEP"
  [ "$UI_DIAGNOSTIC_PAGED" = false ]
  [ "$UI_DIAGNOSTIC_LOGO" = false ]
  ROWS=40
  ui_diagnostic_select_layout 4 "$FLOW_RUN_DIR" ui_engine_failure install_packages 5 false "$LOG" "$FLOW_RUN_DIR"
  [ "$UI_DIAGNOSTIC_PAGED" = true ]
  [ "$UI_DIAGNOSTIC_LOGO" = false ]
  ui_diagnostic_select_summary 5 "$FLOW_RUN_DIR" ui_engine_failure_summary install_packages 5 false
  [ "$UI_DIAGNOSTIC_PAGED" = true ]
  [ "$UI_DIAGNOSTIC_LOGO" = true ]
  run ui_engine_failure_summary install_packages 5 false
  [ "$status" -eq 0 ]
  [[ "$output" == *'synthetic-symbol'* && "$output" == *'The disk was not modified.'* ]]
  ROWS=31
  ui_diagnostic_select_summary 5 "$FLOW_RUN_DIR" ui_engine_failure_summary install_packages 5 false
  [ "$UI_DIAGNOSTIC_LOGO" = false ]
  run ui_engine_failure_summary install_packages 5 false
  [ "$status" -eq 0 ]
  [[ "$output" != *'synthetic-symbol'* ]]
}

@test "error-adaptive private rendering failure never opens an inspector or power menu" {
  FLOW_TMP="${BATS_TEST_TMPDIR}/missing-directory"
  run ui_diagnostic_select_layout 4 "$FLOW_RUN_DIR" ui_engine_failure install_packages 5 true "$LOG" "$FLOW_RUN_DIR"
  [ "$status" -eq 6 ]
  run flow_failure_menu
  [ "$status" -eq 0 ]
  run grep -qE 'gum (choose|pager)' "$CALLS"
  [ "$status" -eq 1 ]
  [ ! -s "$POWER" ]
}
