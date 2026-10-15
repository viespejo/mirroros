#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared with the orchestrator and the screen library.
# The guided live installer behind operations/install (contracts/installation-confirmation.md).
#
# The flow invokes install/discovery/discover and install/plan/plan as processes and uses the Node helpers
# of install/confirmation/cli.mjs and assistant.mjs for every decision about plans, records, and safety.
# Gum only presents and collects input. Confirmation is ephemeral: nothing persisted authorizes anything,
# and every path ends in a record. The flow invokes install/engine/apply (contracts/installation-engine.md) only
# after the bound confirmation, the protected password entry, and the final revalidation; it is the only caller.
#
# The orchestrator sets FLOW_CODE_ROOT, FLOW_PLAN_ARG, and FLOW_OUTPUT_ARG before calling flow_main.

FLOW_RUN_ID=''
FLOW_RUN_DIR=''
FLOW_LOG_PATH=''
FLOW_TMP=''
FLOW_ENTRY=guided
FLOW_GUM_VERSION=''
FLOW_FACTS_INITIAL=''
FLOW_FACTS_FINAL=''
FLOW_CHOICES=''
FLOW_PLAN_CHOICES=''
FLOW_PREVIEW=''
FLOW_INVALID_TEXT=''
FLOW_STDERR=''
FLOW_PLAN_SEQ=0
FLOW_PLAN_DIR=''
FLOW_PLAN_FILE=''
FLOW_FIELD=''
FLOW_DEVICE_NAME=''
FLOW_PROFILE_STATUS=''
FLOW_DISCOVERED=false
FLOW_CONFIRMED=false
FLOW_PLAN_JUMPED=false
# The single account password. A global that is never exported, logged, or recorded; it lives from the password
# screen until the engine invocation consumes it (or the run ends).
FLOW_PASSWORD=''
FLOW_EXIT_MENU=''
FLOW_ENGINE_UNVERIFIED=false
FLOW_ENGINE_PID=''
FLOW_ENGINE_SHOWN=''
FLOW_ENGINE_FAILED_OPERATION=''
FLOW_ENGINE_FAILED_STATUS=''
FLOW_ENGINE_DESTRUCTIVE=true
FLOW_ENGINE_ROOT="${FLOW_ENGINE_ROOT:-${MIRROROS_ENGINE_RUN_ROOT:-/run/mirroros}}"
NEXT_SCREEN=''
FLOW_STAGES=()
declare -gA FLOW_REVIEW=()

flow_timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# Appends one plain-text line to install.log. Styled output and secrets are never written here.
flow_log() {
  [[ -n "$FLOW_LOG_PATH" ]] || return 0
  printf '%s %s\n' "$(flow_timestamp)" "$*" >> "$FLOW_LOG_PATH"
}

# Appends the diagnostics of the last child process, without control characters, to install.log.
flow_log_diagnostics() {
  local line
  [[ -n "$FLOW_STDERR" && -s "$FLOW_STDERR" ]] || return 0
  flow_log 'diagnostics:'
  while IFS= read -r line || [[ -n "$line" ]]; do
    flow_log "  ${line}"
  done < <(LC_ALL=C sed -e 's/\x1b\[[0-9;?]*[ -\/]*[@-~]//g' "$FLOW_STDERR" | tr -cd '[:print:]\n')
}

flow_cli() {
  node "${FLOW_CODE_ROOT}/install/confirmation/cli.mjs" "$@"
}

flow_assistant() {
  node "${FLOW_CODE_ROOT}/install/confirmation/assistant.mjs" "$@"
}

flow_plan() {
  "${FLOW_CODE_ROOT}/install/plan/plan" "$@"
}

flow_cleanup() {
  [[ -z "$FLOW_TMP" ]] || rm -rf -- "$FLOW_TMP"
}

# Records that a stage was reached; each stage is listed once, in flow order.
flow_reached() {
  local stage
  for stage in "${FLOW_STAGES[@]}"; do
    if [[ "$stage" == "$1" ]]; then return 0; fi
  done
  FLOW_STAGES+=("$1")
  flow_log "stage: $1"
}

# Writes both records, reports the evidence location, and ends the run. Arguments: exit status, outcome,
# the flow step, and an optional file with a JSON list of reasons.
flow_finish() {
  local status="$1"
  local outcome="$2"
  local operation="$3"
  local reasons="${4:-}"
  local stages=''

  trap - INT TERM HUP
  FLOW_PASSWORD=''
  if ((${#FLOW_STAGES[@]} > 0)); then stages="$(IFS=,; printf '%s' "${FLOW_STAGES[*]}")"; fi
  if ! flow_cli record "$FLOW_RUN_DIR" "$FLOW_RUN_ID" "$(flow_timestamp)" "$FLOW_ENTRY" \
    "$FLOW_GUM_VERSION" "$status" "$outcome" "$operation" "$reasons" "$stages"; then
    flow_log 'records could not be written'
    printf '%s\n' 'MirrorOS install: the run records could not be written.' \
      'Next step: check the output location and rerun mirroros-install.' >&2
    exit 6
  fi
  flow_log "outcome=${outcome} exit_status=${status} step=${operation}"
  # An ending menu (success or failure screen) runs after the records are written, so a killed menu loses nothing.
  if [[ -n "$FLOW_EXIT_MENU" ]]; then "$FLOW_EXIT_MENU" || true; fi
  printf 'Evidence: %s\n' "$FLOW_RUN_DIR"
  exit "$status"
}

# Ends the run with one of the fixed reasons of the contract and shows its message and next step. A fifth
# argument "quiet" skips the message when the caller already showed its own ending.
flow_finish_standard() {
  local reasons="${FLOW_TMP}/reasons.json"

  flow_assistant reason "$4" > "$reasons"
  if [[ "${5:-}" != quiet ]]; then flow_cli reasons text "$reasons"; fi
  flow_finish "$1" "$2" "$3" "$reasons"
}

# Ends the run with the reasons a helper already printed as JSON into the given file.
flow_finish_reasons() {
  flow_finish "$1" "$2" "$3" "$4"
}

flow_finish_failed() {
  local status=5

  [[ "$1" != 6 ]] || status=6
  flow_finish "$status" failed "$2" "${3:-}"
}

# Shows the first reason of a reasons file as a failed phase: phase, cause, and next action.
flow_report_reasons() {
  local cause='' next_step=''

  if [[ -s "$2" ]] && flow_assistant reasons-text "$2" > "${FLOW_TMP}/report.tsv" 2> /dev/null; then
    IFS=$'\t' read -r cause next_step < "${FLOW_TMP}/report.tsv" || true
  fi
  ui_failure "$1" "${cause:-No cause was reported.}" "${next_step:-Check install.log in the run directory.}"
}

# An unexpected failure of a phase: reported with phase, cause, and next action, with the original status
# kept as child_exit_status and the diagnostics retained in install.log. Arguments: flow step, original
# status, phase label.
flow_unexpected() {
  local operation="$1"
  local original="$2"
  local phase="${3:-$1}"
  local status=5
  local reasons="${FLOW_TMP}/reasons.json"

  [[ "$original" != 6 ]] || status=6
  trap - INT
  flow_log "unexpected failure in ${operation}: status ${original}"
  flow_log_diagnostics
  flow_assistant reason stage_failed "$original" > "$reasons"
  ui_failure "$phase" "The phase exited with status ${original}; it is reported as ${status}." 'Check install.log in the run directory, then rerun mirroros-install.'
  flow_finish "$status" failed "$operation" "$reasons"
}

# The reasons of a stage that exited 2 with an invalid result, or of one that failed outright, are read from
# the evidence the stage left behind. Arguments: status, outcome for status 2, the flow step, the reasons
# kind, and the source file.
flow_finish_stage() {
  local status="$1"
  local blocked_outcome="$2"
  local operation="$3"
  local kind="$4"
  local source="$5"
  local reasons="${FLOW_TMP}/reasons.json"

  if [[ "$status" -ne 2 && "$kind" == facts ]]; then
    kind=error
    source="$(dirname -- "$source")/error.json"
  fi
  if [[ ! -f "$source" ]] || ! flow_cli reasons "$kind" "$source" > "$reasons" 2> /dev/null; then
    printf '[]\n' > "$reasons"
  fi
  # An unexpected failure that left no structured reason is recorded with the original child status.
  if [[ "$status" -ne 2 && "$(< "$reasons")" == '[]' ]]; then
    flow_assistant reason stage_failed "$status" > "$reasons"
  fi
  flow_log_diagnostics
  flow_report_reasons "$operation" "$reasons"
  if [[ "$status" -eq 2 ]]; then
    flow_finish 2 "$blocked_outcome" "$operation" "$reasons"
  fi
  flow_finish_failed "$status" "$operation" "$reasons"
}

flow_cancel() {
  trap - INT
  printf '\n'
  gum style 'Guide cancelled. No installation or disk operation was executed.'
  flow_finish 3 cancelled "$1"
}

flow_on_interrupt() {
  flow_cancel interrupt
}

# SIGINT maps to cancellation only while the interactive phase is active: every screen, the pager, and both
# authorization prompts. Read-only discovery and revalidation keep the shell convention.
flow_enter_interactive() {
  trap flow_on_interrupt INT
}

flow_leave_interactive() {
  trap - INT
}

flow_init() {
  local uuid=''

  if [[ -r /proc/sys/kernel/random/uuid ]]; then
    uuid="$(< /proc/sys/kernel/random/uuid)"
  fi
  if [[ -z "$uuid" ]]; then
    printf '%s\n' 'MirrorOS install: could not generate a run identifier.' >&2
    exit 6
  fi
  FLOW_RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-${uuid}"
  if [[ -n "$FLOW_OUTPUT_ARG" ]]; then
    FLOW_RUN_DIR="$FLOW_OUTPUT_ARG"
  else
    FLOW_RUN_DIR="evidence/install/${FLOW_RUN_ID}"
  fi
  if [[ -e "$FLOW_RUN_DIR" ]]; then
    if [[ ! -d "$FLOW_RUN_DIR" ]]; then
      printf 'MirrorOS install: the output is not a directory: %s\n' "$FLOW_RUN_DIR" >&2
      exit 2
    fi
    if [[ -n "$(find "$FLOW_RUN_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      printf 'MirrorOS install: the output directory must be absent or empty: %s\n' "$FLOW_RUN_DIR" >&2
      exit 2
    fi
  fi
  FLOW_TMP="$(mktemp -d "${TMPDIR:-/tmp}/mirroros-install.XXXXXX")"
  trap flow_cleanup EXIT
  mkdir -p -- "$FLOW_RUN_DIR"
  chmod 700 -- "$FLOW_RUN_DIR"
  mkdir -m 700 -- "${FLOW_RUN_DIR}/plans" "${FLOW_RUN_DIR}/discovery"
  FLOW_LOG_PATH="${FLOW_RUN_DIR}/install.log"
  : > "$FLOW_LOG_PATH"
  chmod 600 -- "$FLOW_LOG_PATH"
  FLOW_FACTS_INITIAL="${FLOW_RUN_DIR}/discovery/initial/target-facts.json"
  FLOW_FACTS_FINAL="${FLOW_RUN_DIR}/discovery/final/target-facts.json"
  FLOW_CHOICES="${FLOW_TMP}/choices.json"
  FLOW_PLAN_CHOICES="${FLOW_TMP}/choices-planned.json"
  FLOW_PREVIEW="${FLOW_TMP}/preview.json"
  FLOW_INVALID_TEXT="${FLOW_TMP}/invalid.tsv"
  FLOW_STDERR="${FLOW_TMP}/stderr.txt"
  : > "$FLOW_INVALID_TEXT"
  : > "$FLOW_STDERR"
  flow_log "run ${FLOW_RUN_ID} started"
  flow_release_target
}

# The start-of-run cleanup: only the engine's own mount point and a swapfile beneath it are released. Nothing else
# is touched, and a failure is logged without stopping the run (discovery then reports the disk as ineligible).
flow_release_target() {
  local root target="${FLOW_ENGINE_ROOT}/target" swaps swapfile released=false

  root="${MIRROROS_DISCOVERY_ROOT:-}"
  swaps="${root%/}/proc/swaps"

  if [[ ! -d "$target" ]]; then
    flow_log 'start-of-run cleanup: the engine mount point does not exist'
    return 0
  fi
  for swapfile in "${target}/swapfile" "${target}/swap/swapfile"; do
    if [[ -e "$swapfile" ]] && grep -qF -- "$swapfile" "$swaps" 2> /dev/null; then
      released=true
      if swapoff -- "$swapfile" > /dev/null 2>&1 < /dev/null; then
        flow_log "start-of-run cleanup: swapfile turned off: ${swapfile}"
      else
        flow_log "start-of-run cleanup: the swapfile could not be turned off: ${swapfile}"
      fi
    fi
  done
  if mountpoint -q "$target" 2> /dev/null; then
    released=true
    if umount -R -- "$target" > /dev/null 2>&1 < /dev/null; then
      flow_log 'start-of-run cleanup: the engine mount point was unmounted'
    else
      flow_log 'start-of-run cleanup: the engine mount point could not be unmounted'
    fi
  fi
  if [[ "$released" == false ]]; then flow_log 'start-of-run cleanup: nothing to release'; fi
}

# Gum must be present and of the qualified major version (ADR 0004); its version is recorded.
flow_check_gum() {
  local version=''
  local major=''

  if command -v gum > /dev/null 2>&1; then
    version="$(gum --version 2> /dev/null | tr -cd '[:print:]')" || version=''
  fi
  FLOW_GUM_VERSION="$version"
  if [[ "$version" =~ version[[:space:]]+([0-9]+)\. ]]; then
    major="${BASH_REMATCH[1]}"
  fi
  flow_log "gum: ${version:-missing}"
  [[ "$major" == 2 ]] || flow_finish_standard 6 failed gum_check gum_not_qualified
}

# The choices the plan component would resolve for the accumulated choices. Written to FLOW_PREVIEW.
flow_preview() {
  local status=0
  local -a choices=()

  if [[ -f "$FLOW_CHOICES" ]]; then choices=(--choices "$FLOW_CHOICES"); fi
  flow_plan preview-choices --facts "$FLOW_FACTS_INITIAL" "${choices[@]}" > "${FLOW_PREVIEW}.next" 2> "$FLOW_STDERR" || status=$?
  if ((status != 0)); then flow_unexpected choice_preview "$status" 'Installation choices'; fi
  mv -f -- "${FLOW_PREVIEW}.next" "$FLOW_PREVIEW"
}

# The resolved value of one choice, as the plan would hold it.
flow_choice() {
  flow_assistant get "$FLOW_PREVIEW" "choices.$1.value"
}

# Validates one value through the plan component and, when it changes a proposal, records it as a user choice.
# A value that leaves a proposal unchanged keeps its provenance and source. Returns 0 when accepted, 1 when the
# value is invalid (the reasons are in FLOW_INVALID_TEXT), or another status for the caller to normalize.
flow_apply_choice() {
  local key="$1"
  local value="$2"
  local result="${FLOW_TMP}/validate.json"
  local next="${FLOW_TMP}/choices-next.json"
  local status=0
  local current
  local explicit

  : > "$FLOW_INVALID_TEXT"
  flow_plan validate-choice --facts "$FLOW_FACTS_INITIAL" --choices "$FLOW_CHOICES" --key "$key" --value "$value" > "$result" 2> "$FLOW_STDERR" || status=$?
  case "$status" in
    0) ;;
    2)
      if [[ -s "$result" ]] && flow_assistant reasons-text "$result" > "$FLOW_INVALID_TEXT" 2> /dev/null; then
        flow_log "choice rejected: ${key}"
        return 1
      fi
      return 5
      ;;
    *) return "$status" ;;
  esac
  current="$(flow_choice "$key")" || return 6
  explicit="$(flow_assistant get "$FLOW_CHOICES" "$key")" || return 6
  if [[ -z "$explicit" && "$current" == "$value" ]]; then
    return 0
  fi
  flow_cli edit set "$FLOW_CHOICES" "$key" "$value" "$next" > /dev/null 2> "$FLOW_STDERR" || return 5
  mv -f -- "$next" "$FLOW_CHOICES"
  flow_log "choice set: ${key}"
  flow_preview
}

# Runs one read-only discovery without --target into discovery/<stage>. Returns the status of discover.
flow_run_discovery() {
  local stage="$1"
  local directory="${FLOW_RUN_DIR}/discovery/${stage}"
  local status=0

  rm -rf -- "$directory"
  "${FLOW_CODE_ROOT}/install/discovery/discover" --output "$directory" > /dev/null 2> "$FLOW_STDERR" || status=$?
  flow_log "discovery ${stage}: exit status ${status}"
  return "$status"
}

# Compares the plan with fresh facts. Arguments: fresh facts, baseline facts or empty, the flow step.
flow_compare() {
  local output="${FLOW_TMP}/compare.json"
  local status=0

  flow_cli compare "$FLOW_CODE_ROOT" "$FLOW_PLAN_FILE" "$1" "$2" > "$output" || status=$?
  case "$status" in
    0) ;;
    2) flow_finish_reasons 2 invalidated "$3" "$output" ;;
    *) flow_finish_failed "$status" "$3" ;;
  esac
}

# Validates the plan file, including its digest, and prints one review field. A failing plan invalidates the run.
flow_plan_field() {
  local output="${FLOW_TMP}/field.json"
  local status=0

  FLOW_FIELD=''
  flow_cli review "$1" "$FLOW_PLAN_FILE" > "$output" || status=$?
  case "$status" in
    0) FLOW_FIELD="$(< "$output")" ;;
    2) flow_finish_reasons 2 invalidated "$2" "$output" ;;
    *) flow_finish_failed "$status" "$2" ;;
  esac
}

# With --plan: the plan is validated, copied to plans/01/, and its explicit choices become the starting
# choices. The comparison with fresh facts follows the first discovery. The original file stays untouched.
flow_load_given_plan() {
  local output="${FLOW_TMP}/validated.json"
  local status=0
  local directory="${FLOW_RUN_DIR}/plans/01"

  FLOW_ENTRY=plan_file
  flow_cli review digest-prefix "$FLOW_PLAN_ARG" > "$output" || status=$?
  case "$status" in
    0) ;;
    2) flow_finish_reasons 2 invalidated plan_validation "$output" ;;
    *) flow_finish_failed "$status" plan_validation ;;
  esac
  # A plan of another code identity never reaches review: no confirmation or password is requested for it.
  status=0
  flow_cli identity "$FLOW_CODE_ROOT" "$FLOW_PLAN_ARG" > "$output" || status=$?
  case "$status" in
    0) ;;
    2) flow_report_reasons 'Plan validation' "$output"; flow_finish_reasons 2 blocked plan_identity "$output" ;;
    *) flow_finish_failed "$status" plan_identity ;;
  esac
  mkdir -m 700 -- "$directory"
  cp -- "$FLOW_PLAN_ARG" "${directory}/installation-plan.json"
  chmod 600 -- "${directory}/installation-plan.json"
  FLOW_PLAN_SEQ=1
  FLOW_PLAN_DIR="$directory"
  FLOW_PLAN_FILE="${directory}/installation-plan.json"
  flow_cli edit start "$FLOW_PLAN_FILE" "${directory}/choices.json" > /dev/null || flow_finish_failed 6 choices_start
  cp -- "${directory}/choices.json" "$FLOW_CHOICES"
  cp -- "${directory}/choices.json" "$FLOW_PLAN_CHOICES"
  flow_log 'plan given with --plan was validated and copied'
}

# Read-only discovery of the machine, once per run. A recoverable result (only network reasons) offers Retry,
# Back, or Cancel; every other failure ends the run. With --plan the plan is then compared with the facts.
# Returns 0 when facts exist, or 1 for Back.
flow_discover_initial() {
  local status choice directory="${FLOW_RUN_DIR}/discovery/initial"
  local reasons="${FLOW_TMP}/discovery-reasons.json"

  if [[ "$FLOW_DISCOVERED" == true ]]; then return 0; fi
  while true; do
    gum style --foreground 8 --padding "$PADDING" 'Inspecting this machine...'
    flow_leave_interactive
    status=0
    flow_run_discovery initial || status=$?
    flow_enter_interactive
    flow_reached discovery_initial
    if ((status == 0)); then break; fi
    if ((status == 2)) && [[ -f "${directory}/target-facts.json" ]] \
      && flow_cli reasons facts "${directory}/target-facts.json" > "$reasons" 2> /dev/null \
      && flow_assistant recoverable "$reasons"; then
      flow_log_diagnostics
      flow_report_reasons 'Machine discovery' "$reasons"
      status=0
      choice=$(gum choose --show-help --height 3 --selected Retry Retry Back Cancel) || status=$?
      case "$status" in
        0) ;;
        1) return 1 ;;
        130) flow_cancel discovery_initial ;;
        *) flow_unexpected discovery_initial "$status" 'Machine discovery' ;;
      esac
      case "$choice" in
        Retry) step 'Machine check'; continue ;;
        Back) return 1 ;;
        *) flow_cancel discovery_initial ;;
      esac
    fi
    flow_finish_stage "$status" blocked discovery_initial facts "${directory}/target-facts.json"
  done
  FLOW_DISCOVERED=true
  if [[ -n "$FLOW_PLAN_ARG" ]]; then
    flow_reached plan
    flow_compare "$FLOW_FACTS_INITIAL" '' safety_check_initial
  fi
  # Detected memory bounds the swapfile; without it no choice can be resolved, so the run is blocked.
  status=0
  flow_assistant memory "$FLOW_FACTS_INITIAL" > "$reasons" 2> "$FLOW_STDERR" || status=$?
  case "$status" in
    0) ;;
    2)
      if [[ ! -s "$reasons" ]]; then flow_unexpected memory_check 2 'Machine memory'; fi
      flow_report_reasons 'Machine memory' "$reasons"
      flow_finish_reasons 2 blocked memory_check "$reasons"
      ;;
    *) flow_unexpected memory_check "$status" 'Machine memory' ;;
  esac
  flow_preview
  if [[ -z "$FLOW_PLAN_ARG" ]]; then
    # The initial choices carry only the format version the plan component publishes.
    printf '{"format_version":%s}\n' "$(flow_assistant get "$FLOW_PREVIEW" format_version)" > "$FLOW_CHOICES"
  fi
}

# Generates the next plans/NN when the accumulated choices differ from those of the last plan. An invalid
# combination is reported with its reason, keeps the last valid plan, and offers Back or Cancel.
# Returns 0 when a valid plan matching the choices exists, or 1 for Back.
flow_ensure_plan() {
  local directory status=0 choice cause='' next_step=''

  if [[ -n "$FLOW_PLAN_FILE" ]] && cmp -s "$FLOW_CHOICES" "$FLOW_PLAN_CHOICES"; then return 0; fi
  directory="${FLOW_RUN_DIR}/plans/$(printf '%02d' $((FLOW_PLAN_SEQ + 1)))"
  mkdir -m 700 -- "$directory"
  cp -- "$FLOW_CHOICES" "${directory}/choices.json"
  chmod 600 -- "${directory}/choices.json"
  flow_plan --facts "$FLOW_FACTS_INITIAL" --choices "${directory}/choices.json" --output "$directory" > /dev/null 2> "$FLOW_STDERR" || status=$?
  case "$status" in
    0)
      FLOW_PLAN_SEQ=$((FLOW_PLAN_SEQ + 1))
      FLOW_PLAN_DIR="$directory"
      FLOW_PLAN_FILE="${directory}/installation-plan.json"
      cp -- "$FLOW_CHOICES" "$FLOW_PLAN_CHOICES"
      flow_reached plan
      flow_log "plan ${FLOW_PLAN_SEQ} generated"
      return 0
      ;;
    2)
      flow_assistant reasons-text "${directory}/plan-run.json" > "$FLOW_INVALID_TEXT" || flow_unexpected plan_generation 2 'Plan generation'
      IFS=$'\t' read -r cause next_step < "$FLOW_INVALID_TEXT" || true
      rm -rf -- "$directory"
      flow_log 'plan generation rejected the combination; the last valid plan is kept'
      ui_failure 'Plan generation' "${cause:-The choices do not form a valid plan.}" "${next_step:-Change a choice and try again.}"
      status=0
      choice=$(gum choose --show-help --height 2 --selected Back Back Cancel) || status=$?
      case "$status" in
        0) ;;
        1) return 1 ;;
        130) flow_cancel plan_generation ;;
        *) flow_unexpected plan_generation "$status" 'Plan generation' ;;
      esac
      if [[ "$choice" == Back ]]; then return 1; fi
      flow_cancel plan_generation
      ;;
    *)
      flow_unexpected plan_generation "$status" 'Plan generation'
      ;;
  esac
}

# Loads what the review, confirmation, and password screens show from the validated plan.
flow_load_review() {
  local key value

  flow_plan_field digest-prefix review_validation
  flow_assistant review-values "$FLOW_PLAN_FILE" > "${FLOW_TMP}/review.tsv" || flow_unexpected review_values 6 'Review'
  FLOW_REVIEW=()
  while IFS=$'\t' read -r key value; do
    FLOW_REVIEW[$key]=$value
  done < "${FLOW_TMP}/review.tsv"
  FLOW_PROFILE_STATUS="$(flow_assistant get "$FLOW_PLAN_FILE" target.profile.status)" || flow_unexpected review_values 6 'Review'
}

# The kernel device name the user types. A disk without a kernel path blocks the run before confirmation.
flow_device_name() {
  local output="${FLOW_TMP}/device.json"
  local status=0

  flow_cli review device-name "$FLOW_PLAN_FILE" > "$output" || status=$?
  case "$status" in
    0) FLOW_DEVICE_NAME="$(< "$output")" ;;
    2) flow_finish_reasons 2 blocked confirmation "$output" ;;
    *) flow_finish_failed "$status" confirmation ;;
  esac
}

flow_confirmed() {
  FLOW_CONFIRMED=true
  flow_log 'confirmed'
}

# A mismatching device name cancels without a second attempt.
flow_mismatch() {
  trap - INT
  printf '\n'
  flow_finish_standard 3 cancelled confirmation confirmation_mismatch
}

# The screens, in the order of the reference. Esc goes back without applying an incomplete answer; going
# back from any screen clears the approval, so renewed review and confirmation are required.
flow_screens() {
  local screen=0
  local going_back=false
  local status
  local -a titles=(
    'Welcome to MirrorOS' 'Connect to the internet' 'Machine check' 'Choose installation disk'
    'Choose storage layout' 'Choose hibernation' 'Select your timezone' 'Choose system language'
    'Choose regional formats' 'Choose installed console keyboard' 'Name your machine'
    "Let's setup your user account..." 'Choose root account policy' 'Review your choices'
    'Confirm installation' 'Password'
  )

  while ((screen < ${#titles[@]})); do
    # Back navigation skips automatic preparation instead of bouncing forward.
    if [[ "$going_back" == true ]] && ((screen == 1)); then screen=0; fi
    going_back=false
    NEXT_SCREEN=''
    # Live preparation draws a screen only when something needs attention.
    if ((screen != 1)); then step "${titles[screen]}"; fi
    status=0
    case "$screen" in
      0) welcome_form || status=$? ;;
      1) flow_reached preparation; live_preparation_form || status=$? ;;
      2) machine_check_form || status=$? ;;
      3) disk_selection_form || status=$? ;;
      4) storage_layout_form || status=$? ;;
      5) hibernation_form || status=$? ;;
      6) timezone_form || status=$? ;;
      7) system_language_form || status=$? ;;
      8) regional_formats_form || status=$? ;;
      9) keyboard_form || status=$? ;;
      10) hostname_form || status=$? ;;
      11) username_form || status=$? ;;
      12) root_account_form || status=$? ;;
      13) review_form || status=$? ;;
      14) confirmation_form || status=$? ;;
      15) password_form || status=$? ;;
    esac
    case "$status" in
      0)
        if [[ -n "$NEXT_SCREEN" ]]; then screen=$NEXT_SCREEN; else screen=$((screen + 1)); fi
        ;;
      1)
        going_back=true
        FLOW_CONFIRMED=false
        if ((screen == 15)); then screen=13; elif ((screen > 0)); then screen=$((screen - 1)); fi
        ;;
      130) flow_cancel "screen_${screen}" ;;
      *) flow_unexpected "screen_${screen}" "$status" "${titles[screen]}" ;;
    esac
  done
}

# After confirmation nothing is trusted: the machine is discovered again, compared with the plan, and the
# plan file is validated again, digest included.
flow_revalidate() {
  local status=0
  local directory="${FLOW_RUN_DIR}/discovery/final"

  if [[ "$FLOW_CONFIRMED" != true ]]; then flow_unexpected approval_state 6 'Confirmation'; fi
  flow_leave_interactive
  gum style --foreground 8 --padding "$PADDING" 'Checking the machine and plan again...'
  flow_run_discovery final || status=$?
  flow_reached discovery_final
  if ((status != 0)); then
    flow_finish_stage "$status" invalidated discovery_final facts "${directory}/target-facts.json"
  fi
  flow_compare "$FLOW_FACTS_FINAL" "$FLOW_FACTS_INITIAL" safety_check_final
  flow_plan_field digest-prefix digest_recheck
}

# The progress screen is redrawn only when the engine's state changed since the last drawing.
flow_engine_progress() {
  local line completed total position description packages
  local state="${FLOW_RUN_DIR}/engine/state.json"

  [[ -f "$state" ]] || return 0
  line="$(flow_assistant engine-progress "$state" 2> /dev/null)" || return 0
  [[ -n "$line" && "$line" != "$FLOW_ENGINE_SHOWN" ]] || return 0
  FLOW_ENGINE_SHOWN="$line"
  IFS=$'\t' read -r completed total position description packages <<< "$line"
  ui_progress "$completed" "$total" "$position" "$description" "${packages:-}"
}

# During the engine phase the signals are forwarded to the engine's process group; the engine cleans up and ends
# itself, and this process waits for it.
flow_engine_signal() {
  flow_log "signal ${1} forwarded to the engine"
  kill -s "$1" -- "-${FLOW_ENGINE_PID}" 2> /dev/null || true
}

# Restarting or powering off happens only when the user chooses it from a menu that ran after the records.
flow_power_action() {
  flow_log "the user chose: systemctl ${1}"
  systemctl "$1" > /dev/null 2>&1 < /dev/null || true
}

flow_success_menu() {
  local choice status=0

  flow_leave_interactive
  choice=$(gum choose --show-help --height 2 --selected 'Restart now' 'Restart now' 'Return to shell') || status=$?
  if ((status == 0)) && [[ "$choice" == 'Restart now' ]]; then flow_power_action reboot; fi
}

flow_failure_menu() {
  local choice status

  flow_leave_interactive
  while true; do
    if [[ $FLOW_ENGINE_UNVERIFIED == true ]]; then
      ui_not_verified "${FLOW_RUN_DIR}/engine/engine-run.json" "$FLOW_RUN_DIR"
    else
      ui_engine_failure "$FLOW_ENGINE_FAILED_OPERATION" "$FLOW_ENGINE_FAILED_STATUS" "$FLOW_ENGINE_DESTRUCTIVE" \
        "${FLOW_RUN_DIR}/engine/engine.log" "$FLOW_RUN_DIR"
    fi
    status=0
    choice=$(gum choose --show-help --height 4 --selected 'Return to shell' 'View full log' 'Return to shell' 'Restart' 'Power off') || status=$?
    ((status == 0)) || return 0
    case "$choice" in
      'View full log')
        gum pager < "${FLOW_RUN_DIR}/engine/engine.log" || true
        ;;
      Restart) flow_power_action reboot; return 0 ;;
      'Power off') flow_power_action poweroff; return 0 ;;
      *) return 0 ;;
    esac
  done
}

flow_configure_menu() {
  local choice status step

  flow_leave_interactive
  step="$(flow_assistant get "${FLOW_RUN_DIR}/engine/engine-run.json" configure_failed_step)" || step=unknown
  while true; do
    ui_not_configured "$step" "$FLOW_RUN_DIR"
    status=0
    choice=$(gum choose --show-help --height 4 --selected 'Return to shell' 'View configure log' 'Restart' 'Return to shell' 'Power off') || status=$?
    ((status == 0)) || return 0
    case "$choice" in
      'View configure log')
        sed -n '/^== configure ==$/,$p' "${FLOW_RUN_DIR}/engine/engine.log" | gum pager || true
        ;;
      Restart) flow_power_action reboot; return 0 ;;
      'Power off') flow_power_action poweroff; return 0 ;;
      *) return 0 ;;
    esac
  done
}

# One invocation of the engine (install/engine/apply). The password reaches it only on fd 3, through process
# substitution with the printf builtin, and this process drops its own copy once the engine has started. The
# installer lock is inherited as fd 4. The engine runs with stdin /dev/null, in its own process group, and the
# console belongs to this process alone: it only reads the engine's state.json.
flow_engine() {
  local digest engine_dir="${FLOW_RUN_DIR}/engine" status=0 started outcome summary
  local reasons="${FLOW_TMP}/engine-reasons.json" operation child destructive

  flow_reached engine
  digest="$(flow_assistant get "$FLOW_PLAN_FILE" digest.value)" || flow_unexpected engine_start 6 'Installation engine'
  flow_log 'engine started'
  started=$SECONDS
  FLOW_ENGINE_SHOWN=''
  trap 'flow_engine_signal INT' INT
  trap 'flow_engine_signal TERM' TERM
  trap 'flow_engine_signal HUP' HUP
  # A background job of a non-interactive shell starts with SIGINT ignored, which the engine could not trap; env
  # restores the default so the forwarded SIGINT reaches the engine's own handler.
  setsid env --default-signal=INT "${FLOW_CODE_ROOT}/install/engine/apply" --plan "$FLOW_PLAN_FILE" --digest "$digest" --output "$engine_dir" \
    3< <(printf '%s\n' "$FLOW_PASSWORD") < /dev/null > /dev/null 2> "$FLOW_STDERR" &
  FLOW_ENGINE_PID=$!
  FLOW_PASSWORD=''
  while kill -0 "$FLOW_ENGINE_PID" 2> /dev/null; do
    flow_engine_progress
    # A terminal SIGINT also ends this sleep; the trap already forwarded it, and the loop waits for the engine.
    sleep 0.5 || true
  done
  wait "$FLOW_ENGINE_PID" || status=$?
  trap - INT TERM HUP
  flow_log "engine ended with exit status ${status}"
  flow_log_diagnostics

  if ! flow_cli engine-result "${engine_dir}/engine-run.json" "$status" > "$reasons" 2> /dev/null; then
    flow_log 'the engine record is missing or invalid'
    flow_assistant reason stage_failed "$status" > "$reasons"
    ui_engine_record_failure "$status" "$FLOW_RUN_DIR"
    flow_finish 5 failed engine "$reasons"
  fi
  outcome="$(flow_assistant get "${engine_dir}/engine-run.json" outcome)" || flow_unexpected engine 6 'Installation engine'
  case "$outcome" in
    installed)
      FLOW_EXIT_MENU=flow_success_menu
      ui_success "$((SECONDS - started))"
      flow_finish 0 installed engine "$reasons"
      ;;
    not_configured)
      FLOW_EXIT_MENU=flow_configure_menu
      flow_finish 4 not_configured engine "$reasons"
      ;;
    not_verified)
      FLOW_ENGINE_UNVERIFIED=true
      FLOW_EXIT_MENU=flow_failure_menu
      flow_finish 4 not_verified engine "$reasons"
      ;;
    blocked | invalidated)
      flow_report_reasons 'Installation engine' "$reasons"
      flow_finish "$status" "$outcome" engine "$reasons"
      ;;
    failed)
      summary="$(flow_assistant engine-summary "${engine_dir}/engine-run.json")" || flow_unexpected engine 6 'Installation engine'
      IFS=$'\t' read -r operation destructive child <<< "$summary"
      FLOW_ENGINE_FAILED_OPERATION="$operation"
      FLOW_ENGINE_FAILED_STATUS="${child:-$status}"
      FLOW_ENGINE_DESTRUCTIVE="${destructive:-true}"
      FLOW_EXIT_MENU=flow_failure_menu
      flow_finish "$status" failed engine "$reasons"
      ;;
    *) flow_unexpected engine 6 'Installation engine' ;;
  esac
}

flow_main() {
  flow_init
  flow_check_gum
  ui_setup "${FLOW_CODE_ROOT}/install/confirmation" || flow_unexpected presentation_setup 6 'Presentation'
  if [[ -n "$FLOW_PLAN_ARG" ]]; then flow_load_given_plan; fi
  flow_enter_interactive
  flow_screens
  flow_revalidate
  flow_engine
}
