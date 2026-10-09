#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared with the orchestrator that sources this file.
# The interactive installation flow behind operations/install apply (contracts/installation-confirmation.md).
#
# The flow invokes install/discovery/discover and install/plan/plan as processes and uses the Node
# helpers of install/confirmation/cli.mjs for every decision about plans, records, and safety. Gum only
# presents and collects input. Confirmation is ephemeral: nothing persisted authorizes anything, and
# every path ends in a record and an exit status other than 0.
#
# The orchestrator sets FLOW_CODE_ROOT, FLOW_PLAN_ARG, and FLOW_OUTPUT_ARG before calling flow_main.

FLOW_RUN_ID=''
FLOW_RUN_DIR=''
FLOW_LOG_PATH=''
FLOW_TMP=''
FLOW_TARGET_ID=''
FLOW_GUM_VERSION=''
FLOW_FACTS_INITIAL=''
FLOW_FACTS_FINAL=''
FLOW_PLAN_SEQ=0
FLOW_PLAN_DIR=''
FLOW_PLAN_FILE=''
FLOW_REJECTED_DIR=''
FLOW_STAGE_STATUS=0
FLOW_NOTICE=''
readonly FLOW_EDIT_KEYS=(
  target_disk storage_option swapfile_size locales lang console_keymap timezone hostname user_name root_account
)

flow_timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# Appends one plain-text line to apply.log. Styled output and secrets are never written here.
flow_log() {
  [[ -n "$FLOW_LOG_PATH" ]] || return 0
  printf '%s %s\n' "$(flow_timestamp)" "$*" >> "$FLOW_LOG_PATH"
}

flow_cli() {
  node "${FLOW_CODE_ROOT}/install/confirmation/cli.mjs" "$@"
}

flow_cleanup() {
  [[ -z "$FLOW_TMP" ]] || rm -rf -- "$FLOW_TMP"
}

# Writes both records, reports the evidence location, and ends the run. Arguments: exit status, outcome,
# the flow step, and an optional file with a JSON list of reasons.
flow_finish() {
  local status="$1"
  local outcome="$2"
  local operation="$3"
  local reasons="${4:-}"

  trap - INT
  if ! flow_cli record "$FLOW_RUN_DIR" "$FLOW_RUN_ID" "$(flow_timestamp)" "$FLOW_TARGET_ID" \
    "$FLOW_GUM_VERSION" "$status" "$outcome" "$operation" "$reasons"; then
    flow_log 'records could not be written'
    printf '%s\n' 'MirrorOS install apply: the run records could not be written.' \
      'Next step: check the output location and rerun apply.' >&2
    exit 6
  fi
  flow_log "outcome=${outcome} exit_status=${status} step=${operation}"
  printf 'Evidence: %s\n' "$FLOW_RUN_DIR"
  exit "$status"
}

# Ends the run with one of the fixed reasons of the contract and shows its message and next step.
flow_finish_standard() {
  local reasons="${FLOW_TMP}/reasons.json"

  flow_cli reasons standard "$4" > "$reasons"
  flow_cli reasons text "$reasons"
  flow_finish "$1" "$2" "$3" "$reasons"
}

# Ends the run with the reasons the helper already printed as JSON on stdout into the given file.
flow_finish_reasons() {
  flow_finish "$1" "$2" "$3" "$4"
}

flow_finish_failed() {
  local status=5

  [[ "$1" != 6 ]] || status=6
  flow_finish "$status" failed "$2" "${3:-}"
}

# The reasons of a stage that exited 2 with an invalid result, or of one that failed outright, are read
# from the evidence the stage left behind. Arguments: status, outcome for status 2, the flow step, the
# reasons kind, and the source file.
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
  if [[ "$status" -eq 2 ]]; then
    flow_finish 2 "$blocked_outcome" "$operation" "$reasons"
  fi
  flow_finish_failed "$status" "$operation" "$reasons"
}

flow_cancel() {
  trap - INT
  printf '\n%s\n' 'Cancelled. No changes were made.'
  flow_finish 3 cancelled "$1"
}

flow_on_interrupt() {
  flow_cancel interrupt
}

# SIGINT maps to cancellation only while the interactive review and confirmation phase is active.
flow_enter_interactive() {
  trap flow_on_interrupt INT
}

flow_leave_interactive() {
  trap - INT
}

# Acts on the status of a Gum prompt. Cancellation ends the run; UI_ACTION tells the caller whether to
# proceed or go back. Arguments: status, phase, flow step.
flow_handle_status() {
  ui_map_status "$1" "$2"
  case "$UI_ACTION" in
    cancel) flow_cancel "$3" ;;
    fail)
      ui_stage_status_normalization "$3" "$1" 'rerun apply from an interactive terminal.' || true
      flow_finish_failed 5 "$3"
      ;;
  esac
}

# Runs a stage with a spinner and leaves its status in FLOW_STAGE_STATUS. Statuses 0, 2, and 6 are the
# normalized statuses of the stages; any other status is normalized to 5.
flow_stage() {
  local title="$1"
  local status=0

  shift
  flow_log "stage: ${title}"
  if ui_interactive; then
    gum spin --show-error --spinner.foreground 250 --title.foreground 255 --title "$title" -- "$@" > /dev/null || status=$?
  else
    ui_spin_plain_fallback "$title" "$@" || status=$?
  fi
  case "$status" in
    0 | 2 | 6) ;;
    *)
      ui_stage_status_normalization "$title" "$status" 'check the output location and rerun apply.' || true
      flow_log "stage=${title} original_status=${status}"
      status=5
      ;;
  esac
  FLOW_STAGE_STATUS=$status
}

flow_init() {
  local uuid=''

  if [[ -r /proc/sys/kernel/random/uuid ]]; then
    uuid="$(< /proc/sys/kernel/random/uuid)"
  fi
  if [[ -z "$uuid" ]]; then
    printf '%s\n' 'MirrorOS install apply: could not generate a run identifier.' >&2
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
      printf 'MirrorOS install apply: the output is not a directory: %s\n' "$FLOW_RUN_DIR" >&2
      exit 2
    fi
    if [[ -n "$(find "$FLOW_RUN_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      printf 'MirrorOS install apply: the output directory must be absent or empty: %s\n' "$FLOW_RUN_DIR" >&2
      exit 2
    fi
  fi
  FLOW_TMP="$(mktemp -d "${TMPDIR:-/tmp}/mirroros-apply.XXXXXX")"
  trap flow_cleanup EXIT
  mkdir -p -- "$FLOW_RUN_DIR"
  chmod 700 -- "$FLOW_RUN_DIR"
  mkdir -m 700 -- "${FLOW_RUN_DIR}/plans" "${FLOW_RUN_DIR}/discovery"
  FLOW_LOG_PATH="${FLOW_RUN_DIR}/apply.log"
  : > "$FLOW_LOG_PATH"
  chmod 600 -- "$FLOW_LOG_PATH"
  FLOW_FACTS_INITIAL="${FLOW_RUN_DIR}/discovery/initial/target-facts.json"
  FLOW_FACTS_FINAL="${FLOW_RUN_DIR}/discovery/final/target-facts.json"
  flow_log "run ${FLOW_RUN_ID} started"
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

flow_choose_target() {
  local targets
  local status=0
  local -a items

  targets="$(find "${FLOW_CODE_ROOT}/targets" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)"
  if [[ -z "$targets" ]]; then
    printf '%s\n' 'MirrorOS install apply: the embedded MirrorOS code is incomplete or damaged: no target definition exists.' \
      'Next step: rebuild or re-clone the installation medium and rerun apply.' >&2
    flow_finish_failed 6 target_choice
  fi
  mapfile -t items <<< "$targets"
  ui_choose 'Choose the installation target (Esc cancels)' "${items[@]}" || status=$?
  flow_handle_status "$status" menu target_choice
  FLOW_TARGET_ID="$UI_VALUE"
  flow_log "target: ${FLOW_TARGET_ID}"
}

# Read-only discovery of the chosen target into discovery/<stage>. Arguments: stage name, outcome of an
# invalid result (blocked before review, invalidated after confirmation).
flow_discover() {
  local stage="$1"
  local invalid_outcome="$2"
  local directory="${FLOW_RUN_DIR}/discovery/${stage}"

  flow_stage "Discovering the target (${stage})" \
    "${FLOW_CODE_ROOT}/install/discovery/discover" --target "$FLOW_TARGET_ID" --output "$directory"
  if [[ "$FLOW_STAGE_STATUS" -ne 0 ]]; then
    flow_finish_stage "$FLOW_STAGE_STATUS" "$invalid_outcome" "discovery_${stage}" facts "${directory}/target-facts.json"
  fi
}

# Generates plans/NN through install/plan/plan from the initial facts and a choices file. On success it
# sets FLOW_PLAN_DIR and FLOW_PLAN_FILE; otherwise FLOW_STAGE_STATUS is not 0 and FLOW_REJECTED_DIR names
# the directory the attempt used.
flow_generate_plan() {
  local choices="$1"
  local directory

  directory="${FLOW_RUN_DIR}/plans/$(printf '%02d' $((FLOW_PLAN_SEQ + 1)))"
  mkdir -m 700 -- "$directory"
  cp -- "$choices" "${directory}/choices.json"
  chmod 600 -- "${directory}/choices.json"
  FLOW_REJECTED_DIR="$directory"
  flow_stage 'Generating the installation plan' "${FLOW_CODE_ROOT}/install/plan/plan" \
    --facts "$FLOW_FACTS_INITIAL" --choices "${directory}/choices.json" --output "$directory"
  if [[ "$FLOW_STAGE_STATUS" -eq 0 ]]; then
    FLOW_PLAN_SEQ=$((FLOW_PLAN_SEQ + 1))
    FLOW_PLAN_DIR="$directory"
    FLOW_PLAN_FILE="${directory}/installation-plan.json"
    flow_log "plan ${FLOW_PLAN_SEQ} generated"
  fi
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

# Validates the plan file, including its digest, and prints one field. A failing plan invalidates the run.
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

# With --plan: the plan is validated, copied to plans/01/, and compared before it is reviewed.
flow_load_given_plan() {
  local output="${FLOW_TMP}/target.json"
  local status=0
  local directory="${FLOW_RUN_DIR}/plans/01"

  flow_cli review target-id "$FLOW_PLAN_ARG" > "$output" || status=$?
  case "$status" in
    0) FLOW_TARGET_ID="$(< "$output")" ;;
    2) flow_finish_reasons 2 invalidated plan_validation "$output" ;;
    *) flow_finish_failed "$status" plan_validation ;;
  esac
  flow_log "target: ${FLOW_TARGET_ID} (from the plan)"
  flow_discover initial blocked
  mkdir -m 700 -- "$directory"
  cp -- "$FLOW_PLAN_ARG" "${directory}/installation-plan.json"
  chmod 600 -- "${directory}/installation-plan.json"
  FLOW_PLAN_SEQ=1
  FLOW_PLAN_DIR="$directory"
  FLOW_PLAN_FILE="${directory}/installation-plan.json"
  flow_cli edit start "$FLOW_PLAN_FILE" "${directory}/choices.json" > /dev/null || flow_finish_failed 6 choices_start
  flow_compare "$FLOW_FACTS_INITIAL" '' safety_check_initial
}

# Without --plan: choose the target, discover it, and generate the first plan. A target with several
# eligible disks needs a disk choice before a plan exists.
flow_prepare_new_plan() {
  local choices="${FLOW_TMP}/choices-start.json"
  local disks
  local status=0
  local -a items

  flow_enter_interactive
  flow_choose_target
  flow_leave_interactive
  flow_discover initial blocked
  printf '{"format_version":1}\n' > "$choices"
  disks="$(flow_cli options disks "$FLOW_FACTS_INITIAL")"
  mapfile -t items <<< "$disks"
  if [[ "${#items[@]}" -gt 1 ]]; then
    flow_enter_interactive
    ui_choose 'Choose the target disk (Esc cancels)' "${items[@]}" || status=$?
    flow_handle_status "$status" menu disk_choice
    flow_leave_interactive
    flow_cli edit set "$choices" target_disk "${UI_VALUE%% (*}" "${FLOW_TMP}/choices-disk.json" > /dev/null
    choices="${FLOW_TMP}/choices-disk.json"
  fi
  flow_generate_plan "$choices"
  if [[ "$FLOW_STAGE_STATUS" -ne 0 ]]; then
    flow_finish_stage "$FLOW_STAGE_STATUS" blocked plan_generation plan-run "${FLOW_REJECTED_DIR}/plan-run.json"
  fi
}

# Collects the new value of one editable choice with the widget that fits it. Leaves the value in
# UI_VALUE and returns the Gum status.
flow_edit_widget() {
  local key="$1"
  local list=''
  local status=0
  local -a items

  case "$key" in
    target_disk | storage_option | lang)
      case "$key" in
        target_disk) list="$(flow_cli options disks "$FLOW_FACTS_INITIAL")" ;;
        storage_option) list="$(flow_cli options storage "$FLOW_CODE_ROOT")" ;;
        lang) list="$(flow_cli options locales "$FLOW_PLAN_FILE")" ;;
      esac
      mapfile -t items <<< "$list"
      ui_choose "Choose ${key} (Esc goes back)" "${items[@]}" || status=$?
      UI_VALUE="${UI_VALUE%% (*}"
      ;;
    root_account)
      ui_choose 'Choose root_account (Esc goes back)' locked password || status=$?
      ;;
    console_keymap)
      list="$(find /usr/share/kbd/keymaps -type f -name '*.map.gz' -printf '%f\n' 2> /dev/null | sed 's/\.map\.gz$//' | LC_ALL=C sort -u)"
      if [[ -n "$list" ]]; then
        ui_filter 'Choose console_keymap (Esc goes back)' "$list" --height 10 || status=$?
      else
        ui_input 'Console keymap (Esc goes back)' 'us' || status=$?
      fi
      ;;
    timezone)
      list="$(timedatectl list-timezones 2> /dev/null || true)"
      if [[ -n "$list" ]]; then
        ui_filter 'Choose timezone (Esc goes back)' "$list" --height 10 || status=$?
      else
        ui_input 'Time zone (Esc goes back)' 'Europe/Madrid' || status=$?
      fi
      ;;
    locales)
      list="$(awk '$2 == "UTF-8" { print $1 }' /usr/share/i18n/SUPPORTED 2> /dev/null || true)"
      if [[ -n "$list" ]]; then
        ui_filter 'Choose locales: Tab marks, Enter confirms (Esc goes back)' "$list" --no-limit --height 10 || status=$?
      else
        ui_input 'Locale (Esc goes back)' 'en_US.UTF-8' || status=$?
      fi
      ;;
    swapfile_size) ui_input 'Swapfile size in MiB (Esc goes back)' '4096' || status=$? ;;
    hostname) ui_input 'Hostname (Esc goes back)' 'mirroros' || status=$? ;;
    user_name) ui_input 'User name (Esc goes back)' 'mirroros' || status=$? ;;
  esac
  return "$status"
}

# One edit of one choice: the new choices regenerate the plan. An invalid combination is reported and
# discarded, and the previous plan stays. Esc in a widget returns to the dashboard unchanged.
flow_edit() {
  local status=0
  local key
  local value
  local candidate="${FLOW_TMP}/choices-next.json"

  ui_choose 'Choose the choice to edit (Esc goes back)' "${FLOW_EDIT_KEYS[@]}" || status=$?
  flow_handle_status "$status" edit edit_key
  [[ "$UI_ACTION" == proceed ]] || return 0
  key="$UI_VALUE"
  status=0
  flow_edit_widget "$key" || status=$?
  flow_handle_status "$status" edit "edit_${key}"
  [[ "$UI_ACTION" == proceed ]] || return 0
  value="$UI_VALUE"
  flow_log "edit: ${key}"
  if ! flow_cli edit set "${FLOW_PLAN_DIR}/choices.json" "$key" "$value" "$candidate" > /dev/null; then
    FLOW_NOTICE='The edit was discarded; the previous plan stays.'
    return 0
  fi
  flow_generate_plan "$candidate"
  case "$FLOW_STAGE_STATUS" in
    0) FLOW_NOTICE="Plan regenerated: ${key} changed." ;;
    2)
      rm -rf -- "$FLOW_REJECTED_DIR"
      FLOW_NOTICE='The edit was discarded; the previous plan stays.'
      ;;
    *) flow_finish_failed "$FLOW_STAGE_STATUS" plan_regeneration ;;
  esac
}

# The single review dashboard, then Cancel, Edit a choice, or Continue to confirmation.
flow_review() {
  local status

  flow_enter_interactive
  ui_header
  while :; do
    flow_plan_field markdown review_dashboard
    printf '%s\n' "$FLOW_FIELD" | ui_format "${FLOW_CODE_ROOT}/install/confirmation/style.json"
    # The margin above the menu header is tuned on the live console.
    printf '\n\n\n'
    if [[ -n "$FLOW_NOTICE" ]]; then
      ui_note "$FLOW_NOTICE"
      FLOW_NOTICE=''
    fi
    status=0
    ui_choose 'Choose how to proceed (cancelling makes no changes)' \
      'Cancel' 'Edit a choice' 'Continue to confirmation' || status=$?
    flow_handle_status "$status" menu review_menu
    case "$UI_VALUE" in
      'Edit a choice') flow_edit ;;
      'Continue to confirmation') break ;;
      *) flow_cancel review_menu ;;
    esac
  done
}

# The confirmation is bound to the disk and the digest: a No (or Esc) cancels, and the kernel device name
# must be typed exactly. A mismatch cancels without a second attempt.
flow_confirm() {
  local status=0
  local prompt
  local name

  flow_plan_field device-name confirmation
  name="$FLOW_FIELD"
  flow_plan_field prompt confirmation
  prompt="$FLOW_FIELD"
  ui_confirm "$prompt" || status=$?
  # ui_confirm returns the mapped decline (3); the phase handler reads native Gum statuses (1).
  [[ "$status" -ne 3 ]] || status=1
  flow_handle_status "$status" confirm confirm_prompt
  status=0
  ui_input "Type the device name (${name}) to confirm" "$name" || status=$?
  flow_handle_status "$status" name confirm_name
  if [[ "$UI_VALUE" != "$name" ]]; then
    trap - INT
    printf '\n'
    flow_finish_standard 3 cancelled confirm_name confirmation_mismatch
  fi
  flow_leave_interactive
  flow_log 'confirmed'
}

# After confirmation nothing is trusted: the target is discovered again, compared with the plan, and the
# plan file is validated again, digest included.
flow_revalidate() {
  flow_discover final invalidated
  flow_compare "$FLOW_FACTS_FINAL" "$FLOW_FACTS_INITIAL" safety_check_final
  flow_plan_field digest-prefix digest_recheck
}

flow_main() {
  flow_init
  flow_check_gum
  if [[ -n "$FLOW_PLAN_ARG" ]]; then
    flow_load_given_plan
  else
    flow_prepare_new_plan
  fi
  flow_review
  flow_confirm
  flow_revalidate
  # The installation engine is Story 2.5: a valid approval ends here, and nothing is executed.
  flow_finish_standard 2 approved engine_boundary engine_not_available
}
