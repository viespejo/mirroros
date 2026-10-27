# Remaining error presentation contracts with synthetic providers and no engine or power actions.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced functions consume shared state and doubles.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/flow.sh"
  ROWS=40 COLS=149 LOGO_WIDTH=16
  LOGO_PATH="${BATS_TEST_TMPDIR}/symbol.txt"
  printf 'synthetic-symbol\n' > "$LOGO_PATH"
  FLOW_TMP="${BATS_TEST_TMPDIR}/flow"
  FLOW_RUN_DIR="${BATS_TEST_TMPDIR}/synthetic-run"
  mkdir -p "$FLOW_TMP" "${FLOW_RUN_DIR}/engine" "${FLOW_RUN_DIR}/plans" "${FLOW_RUN_DIR}/discovery/initial"
  printf '{}\n' > "${FLOW_RUN_DIR}/discovery/initial/target-facts.json"
  RECORD="${FLOW_RUN_DIR}/engine/engine-run.json"
  printf '%s\n' '{"postconditions":{"checks":[{"id":"kernel_installed","status":"passed"},{"id":"boot_resume_parameters","status":"failed","detail":"Expected resume_offset=1234; observed resume_offset=5678 in the synthetic boot entry."},{"id":"network_manager_enabled","status":"failed","detail":"Expected NetworkManager.service enabled; observed disabled."}]}}' > "$RECORD"
  LOG="${FLOW_RUN_DIR}/engine/engine.log"
  printf '%s\n' '[synthetic] Base log before configure.' '== configure ==' '[synthetic] Configure step failed.' > "$LOG"
  CALLS="${BATS_TEST_TMPDIR}/calls" POWER="${BATS_TEST_TMPDIR}/power"
  VISITS="${BATS_TEST_TMPDIR}/visits" PAGER_CONTENT="${BATS_TEST_TMPDIR}/pager-content"
  : > "$CALLS"
  : > "$POWER"
  : > "$VISITS"
  MENU_CHOICE='Return to shell' MENU_FIRST='' MENU_STATUS=0 PAGER_STATUS=0
  CONFIGURE_STEP=desktop/compositor/providers/hyprland STEP_STATUS=0
  FLOW_CHOICES="${FLOW_TMP}/choices.json" FLOW_PLAN_CHOICES="${FLOW_TMP}/plan-choices.json"
  FLOW_STDERR="${FLOW_TMP}/stderr" FLOW_INVALID_TEXT="${FLOW_TMP}/invalid.tsv"
  printf '{}\n' > "$FLOW_CHOICES"
  measure_terminal() {
    TERM_WIDTH=$COLS TERM_HEIGHT=$ROWS
    PADDING_LEFT=$(((COLS > 80 ? COLS - 80 : 0) / 2))
    LOGO_PADDING_LEFT=$(((COLS - LOGO_WIDTH) / 2))
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
  flow_power_action() { printf '%s\n' "$1" >> "$POWER"; }
  flow_run_discovery() { return 2; }
  flow_plan() { return 2; }
  flow_cli() {
    case $1 in
      reasons) printf '[]\n' ;;
      record) return 0 ;;
      *) return 6 ;;
    esac
  }
  flow_assistant() {
    case $1 in
      recoverable) return 0 ;;
      reasons-text) printf 'Synthetic provider diagnostic.\tCorrect the synthetic input and retry.\n' ;;
      get)
        [[ $STEP_STATUS == 0 ]] || return "$STEP_STATUS"
        printf '%s\n' "$CONFIGURE_STEP"
        ;;
      *) return 6 ;;
    esac
  }
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    local kind=$1 padding='0 0 0 0' text visit=0 line
    shift
    case $kind in
      style)
        while (($#)); do
          case $1 in
            --foreground) shift 2 ;;
            --padding) padding=$2; shift 2 ;;
            *) break ;;
          esac
        done
        for text in "$@"; do
          while IFS= read -r line; do printf '%*s%s\n' "${padding##* }" '' "$line"; done <<< "$text"
        done
        ;;
      choose)
        if [[ -s $VISITS ]]; then read -r visit < "$VISITS"; fi
        printf '%s\n' "$((visit + 1))" > "$VISITS"
        if [[ $visit == 0 && -n $MENU_FIRST ]]; then
          printf '%s\n' "$MENU_FIRST"
        else
          printf '%s\n' "$MENU_CHOICE"
        fi
        return "$MENU_STATUS"
        ;;
      pager)
        while IFS= read -r line || [[ -n $line ]]; do printf '%s\n' "$line"; done > "$PAGER_CONTENT"
        return "$PAGER_STATUS"
        ;;
      *) return 6 ;;
    esac
  }
  plain() { sed -E $'s/\x1b\[[0-9;?]*[A-Za-z]//g'; }
  measure_terminal
}

@test "error batch verification keeps all failed checks and the separated red warning" {
  local compact line
  run ui_not_verified "$RECORD" /preview/synthetic-run
  [ "$status" -eq 0 ]
  [[ "$output" != *synthetic-symbol* && "$output" != *kernel_installed* ]]
  compact=$(printf '%s\n' "$output" | plain | tr -d '[:space:]')
  [[ "$compact" == *'Installationfinished,buttheinstalledsystemfailedverification.Donotrelyonit.'* ]]
  [[ "$compact" == *'Failedcheck:boot_resume_parametersExpectedresume_offset=1234;observedresume_offset=5678inthesyntheticbootentry.'* ]]
  [[ "$compact" == *'Failedcheck:network_manager_enabledExpectedNetworkManager.serviceenabled;observeddisabled.'* ]]
  [[ "$output" == *$'entry.\n\n'*'Failed check: network_manager_enabled'* ]]
  grep -qF 'gum style --foreground 1 --padding 0 0 0 34 Installation finished,' "$CALLS"
  grep -qF 'gum style --foreground 8 --padding 0 0 0 34 The disk was modified.' "$CALLS"
  while IFS= read -r line; do [ "${#line}" -le 114 ]; done < <(printf '%s\n' "$output" | plain)
}

@test "error batch configuration keeps recovery and known or unknown failed steps" {
  local step compact line
  for step in desktop/compositor/providers/hyprland ''; do
    run ui_not_configured "$step" /preview/synthetic-run
    [ "$status" -eq 0 ]
    [[ "$output" != *synthetic-symbol* ]]
    compact=$(printf '%s\n' "$output" | plain | tr -d '[:space:]')
    [[ "$compact" == *"Basesysteminstalledandverified;environmentconfigurationfailedatstep${step:-unknown}."* ]]
    [[ "$compact" == *'Boottheinstalledsystem,loginattheconsole,andrunsudomirroros-configure.'* ]]
    while IFS= read -r line; do [ "${#line}" -le 114 ]; done < <(printf '%s\n' "$output" | plain)
  done
}

@test "error batch missing record clears progress and separates the unchanged cause and next action" {
  local frame="${BATS_TEST_TMPDIR}/frame" compact
  UI_PROGRESS_LAYOUT=synthetic-progress
  ui_engine_record_failure 5 /preview/synthetic-run > "$frame"
  [ -z "$UI_PROGRESS_LAYOUT" ]
  [[ "$(< "$frame")" == *$'\033[?25h'* && "$(< "$frame")" != *synthetic-symbol* ]]
  compact=$(plain < "$frame" | tr -d '[:space:]')
  [[ "$compact" == *'Phase:InstallationengineCause:Theengineendedwithstatus5andleftnovalidrecord.Next:Checkinstall.logandengine/in/preview/synthetic-run.'* ]]
  [[ "$(< "$frame")" == *$'Phase: Installation engine\n\n'*'Cause:'* ]]
}

@test "error batch phase diagnostics preserve all five scenario shapes at narrow width" {
  local phase compact line
  ROWS=20 COLS=74
  for phase in 'Machine discovery' 'Plan generation' 'Machine memory' safety_check_final 'Unexpected phase'; do
    : > "$CALLS"
    run ui_failure "$phase" \
      'A complete synthetic diagnostic with enough text to wrap beyond the available form width without truncation.' \
      'Regenerate and review the installation plan.'
    [ "$status" -eq 0 ]
    [[ "$output" != *synthetic-symbol* ]]
    compact=$(printf '%s\n' "$output" | plain | tr -d '[:space:]')
    [[ "$compact" == *"Phase:${phase//[[:space:]]/}"* ]]
    [[ "$compact" == *'Cause:Acompletesyntheticdiagnosticwithenoughtexttowrapbeyondtheavailableformwidthwithouttruncation.'* ]]
    [[ "$compact" == *'Next:Regenerateandreviewtheinstallationplan.'* ]]
    [ "$(grep -c '^gum style --foreground 1 ' "$CALLS")" -eq 3 ]
    while IFS= read -r line; do [ "${#line}" -le 73 ]; done < <(printf '%s\n' "$output" | plain)
  done
}

@test "error batch recoverable discovery and rejected plan keep options defaults and Back outcomes" {
  MENU_CHOICE=Back
  run flow_discover_initial
  [ "$status" -eq 1 ]
  grep -qF 'gum choose --header  --cursor › ' "$CALLS"
  grep -qF -- '--show-help --height 3 --selected Retry Retry Back Cancel' "$CALLS"
  : > "$CALLS"
  run flow_ensure_plan
  [ "$status" -eq 1 ]
  grep -qF 'gum choose --header  --cursor › ' "$CALLS"
  grep -qF -- '--show-help --height 2 --selected Back Back Cancel' "$CALLS"
  [ ! -s "$POWER" ]
}

@test "error batch verification menu keeps full log inspection and explicit power semantics" {
  local code choice
  FLOW_ENGINE_UNVERIFIED=true MENU_FIRST='View full log' PAGER_STATUS=1
  run flow_failure_menu
  [ "$status" -eq 0 ]
  grep -qF -- '--show-help --height 4 --selected Return to shell View full log Return to shell Restart Power off' "$CALLS"
  grep -qxF 'gum pager --border-foreground 4' "$CALLS"
  cmp "$LOG" "$PAGER_CONTENT"
  [ "$(< "$VISITS")" -eq 2 ]
  [ ! -s "$POWER" ]
  MENU_FIRST=''
  for code in 0 1 130; do
    for choice in Restart 'Power off' 'Return to shell'; do
      : > "$POWER"
      MENU_STATUS=$code MENU_CHOICE=$choice
      run flow_failure_menu
      [ "$status" -eq 0 ]
      if [[ $code == 0 && $choice == Restart ]]; then
        [ "$(< "$POWER")" = reboot ]
      elif [[ $code == 0 && $choice == 'Power off' ]]; then
        [ "$(< "$POWER")" = poweroff ]
      else
        [ ! -s "$POWER" ]
      fi
    done
  done
}

@test "error batch configure menu shows only configure log and preserves unknown step and shell default" {
  MENU_FIRST='View configure log' STEP_STATUS=6 PAGER_STATUS=1
  run flow_configure_menu
  [ "$status" -eq 0 ]
  grep -qF 'unknown.' "$CALLS"
  grep -qF 'gum choose --header  --cursor › ' "$CALLS"
  grep -qF -- '--show-help --height 4 --selected Return to shell View configure log Restart Return to shell Power off' "$CALLS"
  grep -qxF 'gum pager --border-foreground 4' "$CALLS"
  [ "$(< "$PAGER_CONTENT")" = $'== configure ==\n[synthetic] Configure step failed.' ]
  [ ! -s "$POWER" ]
  MENU_FIRST='' MENU_CHOICE=Restart STEP_STATUS=0
  run flow_configure_menu
  [ "$status" -eq 0 ]
  [ "$(< "$POWER")" = reboot ]
}

@test "error batch evidence aligns error outcomes without changing statuses or success and cancellation output" {
  local outcome code compact
  for outcome in blocked invalidated failed not_verified not_configured; do
    case $outcome in
      blocked | invalidated) code=2 ;;
      failed) code=5 ;;
      *) code=4 ;;
    esac
    : > "$CALLS"
    run flow_finish "$code" "$outcome" synthetic-operation
    [ "$status" -eq "$code" ]
    grep -qF 'gum style --foreground 8 --padding 0 0 0 34 Evidence:' "$CALLS"
    compact=$(printf '%s\n' "$output" | tr -d '[:space:]')
    [[ "$compact" == *"Evidence:$FLOW_RUN_DIR"* ]]
  done
  run flow_finish 0 installed synthetic-operation
  [ "$status" -eq 0 ]
  [ "$output" = "Evidence: $FLOW_RUN_DIR" ]
  run flow_finish 3 cancelled synthetic-operation
  [ "$status" -eq 3 ]
  [ "$output" = "Evidence: $FLOW_RUN_DIR" ]
}
