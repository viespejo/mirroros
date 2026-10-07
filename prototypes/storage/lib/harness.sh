#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared across the harness libraries sourced here.
# Storage prototype harness: the multi-boot orchestrator of Story 2.1, Track 2. Sourced by each
# variant's `run` entry point, which sets PROTO_ENGINE_NAME (the variant), STORAGE_VARIANT_DIR, and
# STORAGE_RECOVERY_KIND (rescue or menu) before calling storage_main.
#
# It sources the generic modules of prototypes/installation/lib/ through that harness, as they are,
# and defines only what differs: the track paths (config.sh), the damage packages, the boots after
# the installation, and the stage record. Exit statuses are those of the 02-01 harness:
# 0 passed; 2 refusal, precondition, or scan finding; 3 the engine (installer or recovery script)
# failed; 4 a postcondition or recovery check failed; 5 infrastructure failure (deadline, missing
# report, medium or disk); 6 internal error or damaged checkout; 130/143 interrupted.
#
# Scenarios (--scenario):
#   install     install, then verify and write the /home marker (development)
#   d1, d2      install, prepare, inject the damage, confirm the failure, recover, verify
#   hibernate   install, prepare, one real hibernation cycle
#   pending     install, prepare, hibernate, an attended rescue session, then resume (observed only)

STORAGE_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
STORAGE_ROOT="$(cd -- "${STORAGE_LIB_DIR}/.." && pwd -P)"
STORAGE_VARIANT_DIR="${STORAGE_VARIANT_DIR:-}"
STORAGE_RECOVERY_KIND="${STORAGE_RECOVERY_KIND:-rescue}"
STORAGE_SCENARIO=''
STORAGE_DAMAGE='none'
STORAGE_MARKER_VALUE=''
STORAGE_ENGINE_STAGE=''
STORAGE_HIBERNATE_SEED=''
STORAGE_LAST_REPORT_SECONDS=''
STORAGE_STAGES_JSON='[]'
STORAGE_FACTS_JSON='{}'

for STORAGE_LIBRARY in config.sh damage-packages.sh; do
  STORAGE_LIBRARY_PATH="${STORAGE_LIB_DIR}/${STORAGE_LIBRARY}"
  if [[ ! -f "$STORAGE_LIBRARY_PATH" || ! -r "$STORAGE_LIBRARY_PATH" ]]; then
    printf 'MirrorOS prototype: incomplete or damaged checkout; a storage library is missing: %s\n' \
      "$STORAGE_LIBRARY_PATH" >&2
    exit 6
  fi
  # shellcheck disable=SC1090 # Resolved relative to this file.
  source "$STORAGE_LIBRARY_PATH" || exit 6
done

# The generic 02-01 modules (PROTO_TRACK is already set by config.sh).
STORAGE_BASE_HARNESS="${STORAGE_ROOT}/../installation/lib/harness.sh"
if [[ ! -f "$STORAGE_BASE_HARNESS" || ! -r "$STORAGE_BASE_HARNESS" ]]; then
  printf 'MirrorOS prototype: incomplete or damaged checkout; the base harness is missing: %s\n' \
    "$STORAGE_BASE_HARNESS" >&2
  exit 6
fi
# shellcheck disable=SC1090 # Resolved relative to this file.
source "$STORAGE_BASE_HARNESS" || exit 6

storage_usage() {
  printf '%s\n' \
    "Usage: ${PROTO_ENGINE_NAME}/run --scenario install|d1|d2|hibernate|pending BUNDLE_DIRECTORY" \
    '' \
    'Runs one storage scenario for this variant against the unmodified qualified bundle in the reference VM.' \
    '  d1, d2      damage injection and recovery (D1 userspace inside @, D2 boot path on the ESP)' \
    '  hibernate   one real hibernate-and-resume cycle' \
    '  pending     hibernation, an attended rescue session with the image pending, then resume (observed)' \
    '  install     installation and verification only (development)' \
    'Raw results: evidence/prototypes/storage/<variant>/<run-id>/ (ignored).'
}

storage_parse_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help | -h) storage_usage; return 100 ;;
      --scenario)
        [[ "$#" -ge 2 && "$2" =~ ^(install|d1|d2|hibernate|pending)$ ]] || {
          printf '%s\n' 'MirrorOS prototype: --scenario accepts install, d1, d2, hibernate, or pending.' >&2
          return 2
        }
        STORAGE_SCENARIO="$2"
        shift 2
        ;;
      -*)
        printf 'MirrorOS prototype: unsupported option: %s\n' "$1" >&2
        return 2
        ;;
      *)
        [[ -z "$BUNDLE_DIR" ]] || { printf '%s\n' 'MirrorOS prototype: only one bundle directory is accepted.' >&2; return 2; }
        BUNDLE_DIR="$1"
        shift
        ;;
    esac
  done
  if [[ -z "$STORAGE_SCENARIO" ]]; then
    printf '%s\n' 'MirrorOS prototype: the --scenario option is missing.' >&2
    return 2
  fi
  if [[ -z "$BUNDLE_DIR" ]]; then
    printf '%s\n' 'MirrorOS prototype: the bundle directory argument is missing.' >&2
    return 2
  fi
  if [[ ! -d "$BUNDLE_DIR" ]] || ! BUNDLE_DIR="$(cd -- "$BUNDLE_DIR" && pwd -P)"; then
    printf '%s\n' 'MirrorOS prototype: the bundle directory is not an accessible directory.' >&2
    return 2
  fi
  case "$STORAGE_SCENARIO" in
    d1 | d2) STORAGE_DAMAGE="$STORAGE_SCENARIO" ;;
    *) STORAGE_DAMAGE='none' ;;
  esac
}

storage_check_preconditions() {
  local tool

  proto_check_preconditions || return $?
  for tool in tar zstd du; do
    if ! command -v "$tool" > /dev/null 2>&1; then
      printf 'MirrorOS prototype: required tool is missing: %s. No host remediation is attempted.\n' "$tool" >&2
      return 2
    fi
  done
  if [[ ! -d "$STORAGE_VARIANT_DIR" || ! -f "${STORAGE_VARIANT_DIR}/stage.sh" ]]; then
    printf 'MirrorOS prototype: the variant stage file is missing: %s/stage.sh\n' "$STORAGE_VARIANT_DIR" >&2
    return 6
  fi
  if [[ ! -f "${STORAGE_ROOT}/guest/install" ]]; then
    printf 'MirrorOS prototype: the derived installer is missing: %s/guest/install\n' "$STORAGE_ROOT" >&2
    return 6
  fi
}

# ---- stage record -----------------------------------------------------------------------------

storage_publish_result() {
  PROTO_RESULT_EXTRA_JSON="$(jq -cn --arg scenario "$STORAGE_SCENARIO" --arg kind "$STORAGE_RECOVERY_KIND" \
    --argjson stages "$STORAGE_STAGES_JSON" --argjson facts "$STORAGE_FACTS_JSON" \
    '{track: "storage", scenario: $scenario, recovery_kind: $kind, stages: $stages} + $facts')" || true
}

# Arguments: stage name, outcome, QEMU exit status, duration in seconds.
storage_record_stage() {
  local updated

  if updated="$(jq -c --arg name "$1" --arg outcome "$2" --argjson qemu "$(evidence_json_number "${3:-}")" \
    --argjson seconds "$(evidence_json_number "${4:-}")" \
    '. + [{name: $name, outcome: $outcome, qemu_status: $qemu, duration_seconds: $seconds}]' <<< "$STORAGE_STAGES_JSON")"; then
    STORAGE_STAGES_JSON="$updated"
  fi
  storage_publish_result
}

# Arguments: key, JSON value.
storage_fact() {
  local updated

  if updated="$(jq -c --arg key "$1" --argjson value "$2" '. + {($key): $value}' <<< "$STORAGE_FACTS_JSON")"; then
    STORAGE_FACTS_JSON="$updated"
  fi
  storage_publish_result
}

# ---- run material -----------------------------------------------------------------------------

# Builds the engine staging directory that every NoCloud medium of the run carries.
storage_stage_engine() {
  local file
  local recover="${STORAGE_VARIANT_DIR}/recover"

  STORAGE_ENGINE_STAGE="${BUILD_RUN_DIR}/engine"
  mkdir -m 700 -- "$STORAGE_ENGINE_STAGE" "${STORAGE_ENGINE_STAGE}/variant" "${STORAGE_ENGINE_STAGE}/support" \
    "${STORAGE_ENGINE_STAGE}/packages" || return 1
  install -m 0755 -- "${STORAGE_ROOT}/guest/install" "${STORAGE_ENGINE_STAGE}/install" || return 1
  while IFS= read -r file; do
    install -m 0755 -- "$file" "${STORAGE_ENGINE_STAGE}/variant/${file##*/}" || return 1
  done < <(find "$STORAGE_VARIANT_DIR" -maxdepth 1 -type f ! -name README.md ! -name run)
  for file in storage-action.sh storage-checks.sh storage-common.sh btrfs-stage.sh mirroros-storage-action.service; do
    install -m 0644 -- "${STORAGE_LIB_DIR}/guest/${file}" "${STORAGE_ENGINE_STAGE}/support/${file}" || return 1
  done
  chmod 0755 -- "${STORAGE_ENGINE_STAGE}/support/storage-action.sh"
  if [[ -f "$recover" ]]; then
    install -m 0755 -- "$recover" "${STORAGE_ENGINE_STAGE}/recover" || return 1
  else
    # Variants without a rescue script (recovery through the boot menu) still get a rescue session.
    printf '#!/usr/bin/bash\nprintf "This variant has no rescue recovery script.\\n"\n' > "${STORAGE_ENGINE_STAGE}/recover" || return 1
    chmod 0755 -- "${STORAGE_ENGINE_STAGE}/recover"
  fi
  cp -- "${DAMAGE_PACKAGES_DIR}"/*.pkg.tar.zst "${STORAGE_ENGINE_STAGE}/packages/" || return 1
}

# Builds the NoCloud medium of one boot; NOCLOUD_SEED_FILE is set on success.
# Arguments: boot name, engine script (install or recover), action for the installed system.
storage_prepare_seed() {
  local boot="$1"
  local script="$2"
  local action="$3"
  local status=0

  PROTO_NOCLOUD_BASENAME="nocloud-${boot}"
  PROTO_NOCLOUD_ENGINE_SCRIPT="$script"
  PROTO_NOCLOUD_EXTRA_SEED_ENV="$(printf '%s\n' \
    "MIRROROS_STORAGE_VARIANT='${PROTO_ENGINE_NAME}'" \
    "MIRROROS_STORAGE_SCENARIO='${STORAGE_SCENARIO}'" \
    "MIRROROS_SEED_LABEL='${REFERENCE_VM_NOCLOUD_LABEL}'" \
    "MIRROROS_DAMAGE='${STORAGE_DAMAGE}'" \
    "MIRROROS_ACTION='${action}'" \
    "MIRROROS_MARKER_VALUE='${STORAGE_MARKER_VALUE}'")"
  proto_nocloud_prepare "$RUN_ID" "$BUILD_RUN_DIR" "$EVIDENCE_RUN_DIR" "$STORAGE_ENGINE_STAGE" \
    "$REFERENCE_VM_NOCLOUD_LABEL" "$REFERENCE_VM_GUEST_HTTPS_URL" "$REFERENCE_VM_GUEST_HTTPS_TIMEOUT_SECONDS" \
    "$PROTO_VARIANT" "$PROTO_MODE" || status=$?
  case "$status" in
    0) PROTO_NOCLOUD_SCAN='passed'; return 0 ;;
    2) PROTO_NOCLOUD_SCAN='findings'; proto_mark_failure 2 "nocloud-scan-${boot}" ;;
    5) PROTO_NOCLOUD_SCAN='failed'; proto_mark_failure 5 "nocloud-${boot}" ;;
    *) proto_mark_failure 6 "nocloud-${boot}" ;;
  esac
  return 1
}

# ---- QEMU command lines for the boots added by this track -------------------------------------

# The seed option shared by the disk boots that carry the NoCloud medium. Argument: seed path.
storage_seed_options() {
  LAUNCH_QEMU_COMMAND+=(
    -drive "if=none,id=seed,media=cdrom,format=raw,readonly=on,file=$(launch_escape_option_value "$1")"
    -device "ide-cd,drive=seed,bus=ide.1"
  )
}

# A disk boot with the serial console in a log file. Arguments: serial log path, optional seed path.
storage_build_disk_command() {
  LAUNCH_SERIAL_PATH="$1"
  launch_common_options 1
  LAUNCH_QEMU_COMMAND+=(-serial "file:${LAUNCH_SERIAL_PATH}")
  [[ -z "${2:-}" ]] || storage_seed_options "$2"
}

# An attended disk boot: the serial console is the terminal (and is logged). Ctrl-A x quits QEMU.
storage_build_attended_disk_command() {
  LAUNCH_SERIAL_PATH="$1"
  launch_common_options 1
  LAUNCH_QEMU_COMMAND+=(
    -chardev "stdio,id=ser0,mux=on,signal=off,logfile=$(launch_escape_option_value "$LAUNCH_SERIAL_PATH")"
    -serial chardev:ser0
  )
  [[ -z "${2:-}" ]] || storage_seed_options "$2"
}

# ---- boot helpers -----------------------------------------------------------------------------

# Starts the prepared command. Argument: boot name.
storage_boot_start() {
  local status=0

  launch_start "${EVIDENCE_RUN_DIR}/qemu-${1}-diagnostics.log" || status=$?
  if [[ "$status" -ne 0 ]]; then
    proto_mark_failure 5 "${1}-qemu-launch"
    return 1
  fi
}

# Waits for the guest to power itself off. Arguments: boot name, deadline seconds.
storage_boot_wait_exit() {
  local name="$1"
  local deadline="$2"

  storage_boot_start "$name" || return 1
  printf 'MirrorOS prototype: boot %s (deadline %s s).\n' "$name" "$deadline" >&2
  launch_wait_exit "$deadline"
  storage_record_stage "$name" "$LAUNCH_OUTCOME" "$LAUNCH_QEMU_STATUS" "$LAUNCH_DURATION_SECONDS"
  if [[ "$LAUNCH_OUTCOME" == 'deadline' ]]; then
    proto_mark_failure 5 "${name}-deadline"
    return 1
  fi
}

# Waits for the 02-01 verification report, then for the guest to power itself off. The report is
# kept as verify-report-<name>.json. Arguments: boot name.
storage_boot_wait_verify() {
  local name="$1"
  local report="${EVIDENCE_RUN_DIR}/verify-report-${name}.json"
  local report_seconds

  storage_boot_start "$name" || return 1
  printf 'MirrorOS prototype: boot %s: waiting for the verification report (deadline %s s).\n' "$name" "$PROTO_VERIFY_DEADLINE_SECONDS" >&2
  launch_wait_report "$RUN_ID" "$report" "$PROTO_VERIFY_DEADLINE_SECONDS"
  report_seconds="$LAUNCH_DURATION_SECONDS"
  STORAGE_LAST_REPORT_SECONDS="$report_seconds"
  if [[ "$LAUNCH_OUTCOME" != 'report' ]]; then
    storage_record_stage "$name" "$LAUNCH_OUTCOME" "$LAUNCH_QEMU_STATUS" "$report_seconds"
    proto_mark_failure 5 "${name}-verify-${LAUNCH_OUTCOME}"
    return 1
  fi
  if ! jq -e --arg id "$RUN_ID" '.run_id == $id and .kind == "postconditions" and (.checks | type == "object") and (.result == "passed" or .result == "failed")' \
    "$report" > /dev/null 2>&1; then
    storage_record_stage "$name" 'invalid_report' "$LAUNCH_QEMU_STATUS" "$report_seconds"
    proto_mark_failure 5 "${name}-verify-report"
    return 1
  fi
  launch_wait_exit "$STORAGE_POWEROFF_DEADLINE_SECONDS"
  storage_record_stage "$name" "report_$(jq -r '.result' "$report")" "$LAUNCH_QEMU_STATUS" "$report_seconds"
  if [[ "$LAUNCH_OUTCOME" == 'deadline' ]]; then
    proto_mark_failure 5 "${name}-poweroff-deadline"
    return 1
  fi
  if [[ "$(jq -r '.result' "$report")" != 'passed' ]]; then
    proto_mark_failure 4 "${name}-postconditions"
    return 1
  fi
}

# Keeps the action report of a boot as action-report-<name>.json (the last complete block).
# Arguments: boot name. Marks a missing or foreign report as an infrastructure failure.
storage_collect_action_report() {
  local name="$1"
  local report="${EVIDENCE_RUN_DIR}/action-report-${name}.json"

  if launch_extract_report "${EVIDENCE_RUN_DIR}/serial-${name}.log" MIRROROS-ACTION "$RUN_ID" "$report" && \
    jq -e --arg id "$RUN_ID" '.run_id == $id and .kind == "action"' "$report" > /dev/null 2>&1; then
    return 0
  fi
  rm -f -- "$report"
  proto_mark_failure 5 "${name}-action-report"
  return 1
}

# Keeps the recovery script's report (the runner prints it as the install report) as
# action-report-recover.json. Argument: boot name.
storage_collect_runner_report() {
  local name="$1"
  local report="${EVIDENCE_RUN_DIR}/action-report-${name}.json"

  if launch_extract_report "${EVIDENCE_RUN_DIR}/serial-${name}.log" MIRROROS-INSTALL "$RUN_ID" "$report" && \
    jq -e --arg id "$RUN_ID" '.run_id == $id and (.engine_exit_status | type == "number")' "$report" > /dev/null 2>&1; then
    return 0
  fi
  rm -f -- "$report"
  proto_mark_failure 5 "${name}-runner-report"
  return 1
}

# ---- stages -----------------------------------------------------------------------------------

storage_stage_install() {
  storage_prepare_seed install install none || return 0
  proto_stage_install
  storage_record_stage install "$PROTO_INSTALL_OUTCOME" "$PROTO_INSTALL_QEMU_STATUS" "$PROTO_INSTALL_SECONDS"
}

# Verification boot of the freshly installed system, plus the /home marker (the baseline).
storage_stage_prepare() {
  storage_prepare_seed prepare install prepare || return 0
  storage_build_disk_command "${EVIDENCE_RUN_DIR}/serial-prepare.log" "$NOCLOUD_SEED_FILE"
  storage_boot_wait_verify prepare || return 0
  storage_collect_action_report prepare || return 0
  if ! jq -e '.marker_written == true' "${EVIDENCE_RUN_DIR}/action-report-prepare.json" > /dev/null 2>&1; then
    proto_mark_failure 5 prepare-marker
    return 0
  fi
  storage_fact baseline "$(jq -cs '.[0] as $verify | .[1] as $action
    | {excluded_groups: ($verify.excluded_groups // {}), snapshots: $action.snapshots, marker_written: $action.marker_written}' \
    "${EVIDENCE_RUN_DIR}/verify-report-prepare.json" "${EVIDENCE_RUN_DIR}/action-report-prepare.json")"
}

# Installs the synthetic damage package with pacman -U inside the installed system.
storage_stage_damage() {
  storage_prepare_seed damage install damage || return 0
  storage_build_disk_command "${EVIDENCE_RUN_DIR}/serial-damage.log" "$NOCLOUD_SEED_FILE"
  storage_boot_wait_exit damage "$STORAGE_ACTION_DEADLINE_SECONDS" || return 0
  storage_collect_action_report damage || return 0
  storage_fact damage "$(jq -c 'del(.schema_version, .kind, .run_id)' "${EVIDENCE_RUN_DIR}/action-report-damage.json")"
  if ! jq -e '.pacman_exit == 0' "${EVIDENCE_RUN_DIR}/action-report-damage.json" > /dev/null 2>&1; then
    proto_mark_failure 5 damage-install
  fi
}

# Boots the damaged system without the seed: no verification report may arrive.
storage_stage_confirm() {
  local report="${EVIDENCE_RUN_DIR}/verify-report-confirm.json"
  local outcome
  local seconds
  local serial_bytes

  storage_build_disk_command "${EVIDENCE_RUN_DIR}/serial-confirm.log"
  storage_boot_start confirm || return 0
  printf 'MirrorOS prototype: boot confirm: the damaged system must not come up (%s s).\n' "$STORAGE_CONFIRM_DEADLINE_SECONDS" >&2
  launch_wait_report "$RUN_ID" "$report" "$STORAGE_CONFIRM_DEADLINE_SECONDS"
  outcome="$LAUNCH_OUTCOME"
  seconds="$LAUNCH_DURATION_SECONDS"
  storage_record_stage confirm "$outcome" "$LAUNCH_QEMU_STATUS" "$seconds"
  stop_cleanup_stop_qemu || { proto_mark_failure 5 confirm-qemu-stop; return 0; }
  serial_bytes="$(stat -c %s "${EVIDENCE_RUN_DIR}/serial-confirm.log" 2> /dev/null || printf 0)"
  storage_fact confirm "$(jq -cn --arg outcome "$outcome" --argjson seconds "$(evidence_json_number "$seconds")" \
    --argjson serial_bytes "$serial_bytes" '{outcome: $outcome, seconds: $seconds, serial_log_bytes: $serial_bytes, failed: ($outcome != "report")}')"
  if [[ "$outcome" == 'report' ]]; then
    proto_mark_failure 6 damage-not-effective
  fi
}

# Rescue-based recovery from the qualified ISO, with the variant's recovery script over NoCloud.
storage_stage_recover() {
  local steps
  local engine_exit

  storage_prepare_seed recover recover none || return 0
  LAUNCH_SERIAL_PATH="${EVIDENCE_RUN_DIR}/serial-recover.log"
  launch_build_install_command "$BUNDLE_ISO" "$NOCLOUD_SEED_FILE" "$LAUNCH_SERIAL_PATH"
  storage_boot_wait_exit recover "$STORAGE_RECOVER_DEADLINE_SECONDS" || return 0
  storage_collect_runner_report recover || return 0
  steps="$(grep -c 'recovery step [0-9]*:' "$LAUNCH_SERIAL_PATH" || true)"
  engine_exit="$(jq -r '.engine_exit_status' "${EVIDENCE_RUN_DIR}/action-report-recover.json")"
  storage_fact recovery "$(jq -cn --arg kind rescue --argjson steps "$steps" --argjson script_exit "$engine_exit" \
    --argjson script_seconds "$(jq '.duration_seconds' "${EVIDENCE_RUN_DIR}/action-report-recover.json")" \
    --argjson boot_seconds "$(evidence_json_number "$LAUNCH_DURATION_SECONDS")" \
    '{kind: $kind, rescue_media_needed: true, steps: $steps, script_exit_status: $script_exit,
      script_seconds: $script_seconds, boot_seconds: $boot_seconds, mode: "automated"}')"
  if [[ "$engine_exit" -ne 0 ]]; then
    proto_mark_failure 3 recovery-script-failed
  fi
}

# Evaluates the verifying boot after a recovery: the report, the /home marker, and the journal.
storage_evaluate_final() {
  local verify="${EVIDENCE_RUN_DIR}/verify-report-final.json"
  local action="${EVIDENCE_RUN_DIR}/action-report-final.json"

  if ! jq -e --arg id "$RUN_ID" '.run_id == $id and .kind == "postconditions" and (.checks | type == "object")' "$verify" > /dev/null 2>&1; then
    proto_mark_failure 5 final-verify-report
    return 0
  fi
  PROTO_VERIFY_RESULT="$(jq -r '.result' "$verify")"
  [[ "$PROTO_VERIFY_RESULT" == 'passed' ]] || proto_mark_failure 4 recovery-verification
  storage_collect_action_report final || return 0
  storage_fact verify_excluded_groups "$(jq -c '.excluded_groups // {}' "$verify")"
  storage_fact survival "$(jq -c --arg damage "$STORAGE_DAMAGE" '
    del(.schema_version, .kind, .run_id)
    | . + {expected_boots_with_failed_boot: 4,
           diagnostics_retained: (if $damage == "d1" then (.journal_boots >= 4)
                                  else "not_observable_kernel_never_reached_userspace" end)}' "$action")"
}

# The disk boot after a rescue recovery.
storage_stage_final() {
  storage_prepare_seed final install post-check || return 0
  storage_build_disk_command "${EVIDENCE_RUN_DIR}/serial-final.log" "$NOCLOUD_SEED_FILE"
  PROTO_VERIFY_OUTCOME='started'
  storage_boot_wait_verify final || true
  PROTO_VERIFY_QEMU_STATUS="$LAUNCH_QEMU_STATUS"
  PROTO_VERIFY_SECONDS="$STORAGE_LAST_REPORT_SECONDS"
  # A failed postcondition still leaves a report to evaluate; any other failure leaves nothing to read.
  [[ -f "${EVIDENCE_RUN_DIR}/verify-report-final.json" ]] || return 0
  PROTO_VERIFY_OUTCOME='report'
  storage_evaluate_final
}

# Recovery through the boot menu (btrfs-limine): the maintainer selects a snapshot entry over the
# serial console. The selected entry boots the system and the verifying boot is that same boot.
storage_stage_recover_menu() {
  local started

  storage_prepare_seed final install post-check || return 0
  storage_build_attended_disk_command "${EVIDENCE_RUN_DIR}/serial-final.log" "$NOCLOUD_SEED_FILE"
  printf '%s\n' \
    'MirrorOS prototype: attended recovery. In the Limine menu on this serial console, select the snapshot' \
    'entry that precedes the damage. When the verification and action reports have printed, quit with Ctrl-A x.' \
    'This step is recorded as "observed manually".' >&2
  started="$SECONDS"
  launch_run_attended || proto_mark_failure 5 final-qemu-launch
  storage_record_stage final attended "$LAUNCH_QEMU_STATUS" "$((SECONDS - started))"
  storage_fact recovery "$(jq -cn --argjson seconds "$((SECONDS - started))" \
    '{kind: "menu", rescue_media_needed: false, mode: "attended", session_seconds: $seconds}')"
  PROTO_MODE='unattended+attended-step'
  PROTO_VERIFY_OUTCOME='attended'
  PROTO_VERIFY_QEMU_STATUS="$LAUNCH_QEMU_STATUS"
  if ! launch_extract_report "$LAUNCH_SERIAL_PATH" MIRROROS-REPORT "$RUN_ID" "${EVIDENCE_RUN_DIR}/verify-report-final.json"; then
    rm -f -- "${EVIDENCE_RUN_DIR}/verify-report-final.json"
    proto_mark_failure 5 final-verify-report
    return 0
  fi
  storage_evaluate_final
}

# One hibernation request. The seed medium is kept: the resume boot must see the same hardware.
storage_stage_hibernate() {
  local report="${EVIDENCE_RUN_DIR}/action-report-hibernate.json"

  storage_prepare_seed hibernate install hibernate || return 0
  STORAGE_HIBERNATE_SEED="$NOCLOUD_SEED_FILE"
  storage_build_disk_command "${EVIDENCE_RUN_DIR}/serial-hibernate.log" "$STORAGE_HIBERNATE_SEED"
  storage_boot_wait_exit hibernate "$STORAGE_ACTION_DEADLINE_SECONDS" || return 0
  storage_collect_action_report hibernate || return 0
  storage_fact hibernation "$(jq -c '{request: (del(.schema_version, .kind, .run_id))}' "$report")"
  if ! jq -e '.phase == "requesting"' "$report" > /dev/null 2>&1; then
    storage_fact hibernation "$(jq -c '{request: (del(.schema_version, .kind, .run_id)), cycle: "refused"}' "$report")"
    proto_mark_failure 4 hibernate-refused
  fi
}

# Boots the hibernated disk with the same hardware. Argument: observed (only records the outcome).
storage_stage_resume() {
  local observed="${1:-}"
  local report="${EVIDENCE_RUN_DIR}/action-report-resume.json"
  local request="${EVIDENCE_RUN_DIR}/action-report-hibernate.json"
  local outcome
  local seconds
  local verdict

  storage_build_disk_command "${EVIDENCE_RUN_DIR}/serial-resume.log" "$STORAGE_HIBERNATE_SEED"
  storage_boot_start resume || return 0
  printf 'MirrorOS prototype: boot resume: resuming the hibernated system (deadline %s s).\n' "$STORAGE_RESUME_DEADLINE_SECONDS" >&2
  launch_wait_report "$RUN_ID" "$report" "$STORAGE_RESUME_DEADLINE_SECONDS" MIRROROS-ACTION
  outcome="$LAUNCH_OUTCOME"
  seconds="$LAUNCH_DURATION_SECONDS"
  if [[ "$outcome" == 'report' ]]; then
    launch_wait_exit "$STORAGE_POWEROFF_DEADLINE_SECONDS"
  fi
  storage_record_stage resume "$outcome" "$LAUNCH_QEMU_STATUS" "$seconds"
  verdict='no_report'
  if [[ "$outcome" == 'report' ]]; then
    verdict="$(jq -r --slurpfile request "$request" '
      if .phase == "resumed" and .token == $request[0].token then "resumed"
      elif .phase == "resumed" then "resumed_token_mismatch" else .phase end' "$report")"
  fi
  storage_fact hibernation "$(jq -c --arg verdict "$verdict" --arg observed "$observed" --arg outcome "$outcome" \
    '(.hibernation // {}) + {cycle: $verdict, resume_boot_outcome: $outcome, observed_only: ($observed == "observed")}' <<< "$STORAGE_FACTS_JSON")"
  if [[ "$outcome" == 'report' && "$observed" != 'observed' && "$verdict" != 'resumed' ]]; then
    proto_mark_failure 4 "hibernation-${verdict}"
  elif [[ "$outcome" != 'report' && "$observed" != 'observed' ]]; then
    proto_mark_failure 5 "resume-${outcome}"
  fi
}

# Attended rescue session while a hibernation image is pending (the observed case of DEC-002).
storage_stage_pending_attended() {
  local started

  PROTO_MODE='attended'
  storage_prepare_seed pending recover none || return 0
  LAUNCH_SERIAL_PATH="${EVIDENCE_RUN_DIR}/serial-pending.log"
  launch_build_attended_command "$BUNDLE_ISO" "$NOCLOUD_SEED_FILE" "$LAUNCH_SERIAL_PATH"
  printf '%s\n' \
    'MirrorOS prototype: attended session with a hibernation image pending. Follow the checklist in the' \
    'variant README, then power off the guest. Ctrl-A x quits QEMU. Recorded as "observed manually".' >&2
  started="$SECONDS"
  launch_run_attended || proto_mark_failure 5 pending-qemu-launch
  storage_record_stage pending attended "$LAUNCH_QEMU_STATUS" "$((SECONDS - started))"
}

storage_run_stages() {
  proto_secrets_generate || { proto_mark_failure 5 secrets; return 0; }
  STORAGE_MARKER_VALUE="marker-$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"
  printf 'MirrorOS prototype: run %s (%s, scenario %s): preparing the run material.\n' "$RUN_ID" "$PROTO_ENGINE_NAME" "$STORAGE_SCENARIO" >&2
  if ! damage_build_all "${BUILD_RUN_DIR}/packages"; then
    proto_mark_failure 5 damage-packages
    return 0
  fi
  if ! jq -n --argjson packages "$DAMAGE_PACKAGES_JSON" '{schema_version: 1, packages: $packages}' \
    > "${EVIDENCE_RUN_DIR}/damage-packages.json"; then
    proto_mark_failure 5 damage-packages-record
    return 0
  fi
  chmod 600 -- "${EVIDENCE_RUN_DIR}/damage-packages.json"
  if ! storage_stage_engine; then
    proto_mark_failure 6 engine-staging
    return 0
  fi
  launch_prepare_disk "$BUILD_RUN_DIR" || { proto_mark_failure 5 disk-preparation; return 0; }

  storage_stage_install
  [[ "$PROTO_STATUS" -eq 0 ]] || return 0
  storage_stage_prepare
  [[ "$PROTO_STATUS" -eq 0 ]] || return 0

  case "$STORAGE_SCENARIO" in
    install) ;;
    d1 | d2)
      storage_stage_damage
      [[ "$PROTO_STATUS" -eq 0 ]] || return 0
      storage_stage_confirm
      [[ "$PROTO_STATUS" -eq 0 ]] || return 0
      if [[ "$STORAGE_RECOVERY_KIND" == 'menu' ]]; then
        storage_stage_recover_menu
      else
        storage_stage_recover
        [[ "$PROTO_STATUS" -eq 0 ]] || return 0
        storage_stage_final
      fi
      ;;
    hibernate)
      storage_stage_hibernate
      [[ "$PROTO_STATUS" -eq 0 ]] || return 0
      storage_stage_resume
      ;;
    pending)
      storage_stage_hibernate
      [[ "$PROTO_STATUS" -eq 0 ]] || return 0
      storage_stage_pending_attended
      [[ "$PROTO_STATUS" -eq 0 ]] || return 0
      storage_stage_resume observed
      ;;
  esac
}

storage_main() {
  local status=0
  local boot

  if [[ -z "$PROTO_ENGINE_NAME" || -z "$PROTO_ENGINE_DIR" || -z "$STORAGE_VARIANT_DIR" ]]; then
    printf '%s\n' 'MirrorOS prototype: the variant entry point did not define PROTO_ENGINE_NAME, PROTO_ENGINE_DIR, and STORAGE_VARIANT_DIR.' >&2
    return 6
  fi
  storage_parse_arguments "$@" || { status=$?; [[ "$status" -eq 100 ]] && return 0; return "$status"; }
  storage_check_preconditions || return $?
  proto_admit_bundle || return $?
  proto_config_load "${PROTO_REPOSITORY_ROOT}/vm/reference/reference-vm.conf" || return $?
  launch_collect_versions
  evidence_capture_commit "$PROTO_REPOSITORY_ROOT" || return $?

  for boot in "${STORAGE_BOOT_NAMES[@]}"; do
    EVIDENCE_ALLOWLIST+=("serial-${boot}.log" "qemu-${boot}-diagnostics.log" "verify-report-${boot}.json"
      "action-report-${boot}.json" "gitleaks-nocloud-${boot}.json")
  done
  EVIDENCE_ALLOWLIST+=(damage-packages.json)

  umask 077
  proto_resources_new_id || return $?
  proto_resources_prepare "$PROTO_REPOSITORY_ROOT" "$PROTO_ENGINE_NAME" "$RUN_ID" || return $?
  PROTO_METADATA_EXTRA_JSON="$(jq -cn --arg track "$PROTO_TRACK" --arg scenario "$STORAGE_SCENARIO" \
    --arg kind "$STORAGE_RECOVERY_KIND" --argjson confirm "$STORAGE_CONFIRM_DEADLINE_SECONDS" \
    --argjson action "$STORAGE_ACTION_DEADLINE_SECONDS" --argjson recover "$STORAGE_RECOVER_DEADLINE_SECONDS" \
    --argjson resume "$STORAGE_RESUME_DEADLINE_SECONDS" \
    '{track: $track, scenario: $scenario, recovery_kind: $kind,
      storage_deadlines_seconds: {confirm: $confirm, action: $action, recover: $recover, resume: $resume}}')" || return 6
  storage_publish_result

  trap 'proto_handle_signal 130 INT' INT
  trap 'proto_handle_signal 143 TERM' TERM
  trap proto_handle_exit EXIT

  storage_run_stages
  storage_publish_result
  proto_finalize
  return "$PROTO_STATUS"
}
