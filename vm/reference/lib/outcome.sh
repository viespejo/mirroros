#!/usr/bin/bash

OUTCOME_STARTED_EPOCH=''
OUTCOME_PRIMARY_STATUS=0
OUTCOME_FAILED_STAGE=''
OUTCOME_CLEANUP_OUTCOME='pending'
OUTCOME_CLEANUP_GUIDANCE=''
OUTCOME_TEST_COMMIT=''
OUTCOME_TEST_DIRTY=''
OUTCOME_LEFTOVERS=()
declare -Ag OUTCOME_TOOL_STATUSES=()
declare -Ag OUTCOME_SCANS=([nocloud]='not_run' [evidence]='not_run')

outcome_initialize() {
  OUTCOME_STARTED_EPOCH="$(date -u +%s)" || return 5
}

# Records the identity of the test code: HEAD commit and whether the working tree is dirty.
outcome_capture_test_code() {
  local repository_root="$1"
  local porcelain

  if ! OUTCOME_TEST_COMMIT="$(git -C "$repository_root" rev-parse HEAD 2>/dev/null)" || \
    [[ ! "$OUTCOME_TEST_COMMIT" =~ ^[0-9a-f]{40,64}$ ]] || \
    ! porcelain="$(git -C "$repository_root" status --porcelain 2>/dev/null)"; then
    printf '%s\n' 'MirrorOS test: incomplete or damaged checkout; the test code identity (Git commit) could not be determined.' >&2
    return 6
  fi
  if [[ -z "$porcelain" ]]; then
    OUTCOME_TEST_DIRTY='false'
  else
    # shellcheck disable=SC2034 # Read by outcome_write_result.
    OUTCOME_TEST_DIRTY='true'
  fi
}

outcome_record_tool_status() {
  OUTCOME_TOOL_STATUSES["$1"]="$2"
}

outcome_set_scan() {
  OUTCOME_SCANS["$1"]="$2"
}

# The first non-success is kept; later failures never replace it.
outcome_mark_failure() {
  local normalized_status="$1"
  local stage="$2"

  if [[ "$OUTCOME_PRIMARY_STATUS" -eq 0 ]]; then
    OUTCOME_PRIMARY_STATUS="$normalized_status"
    OUTCOME_FAILED_STAGE="$stage"
  fi
}

outcome_mark_interrupted() {
  outcome_mark_failure "$1" "signal-${2}"
}

# Arguments: outcome (success, preserved, failure), recovery guidance, leftover resources.
# A cleanup problem after success yields 5 and never replaces an earlier non-success.
outcome_note_cleanup() {
  local cleanup_outcome="$1"
  local guidance="$2"
  shift 2

  OUTCOME_CLEANUP_OUTCOME="$cleanup_outcome"
  OUTCOME_CLEANUP_GUIDANCE="$guidance"
  OUTCOME_LEFTOVERS=("$@")
  if [[ "$cleanup_outcome" != 'success' ]]; then
    outcome_mark_failure 5 cleanup
  fi
}

outcome_next_action() {
  case "$OUTCOME_PRIMARY_STATUS" in
    0) ;;
    2) printf '%s' 'Resolve the reported input, prerequisite, or secret-scan finding, then rerun; findings stay private under the run evidence directory.' ;;
    4) printf '%s' 'Inspect the failed checks in result.json and the private guest-serial.log, fix the cause, then rerun.' ;;
    5) printf '%s' 'Review qemu-diagnostics.log and the cleanup outcome; see docs/procedures/test.md before rerunning.' ;;
    6) printf '%s' 'Restore the checkout from Git or report the internal contract violation.' ;;
    130 | 143) printf '%s' 'The run was interrupted; rerun when ready.' ;;
    *) printf '%s' 'Review the run evidence and docs/procedures/test.md.' ;;
  esac
}

# Writes evidence/reference-vm/<run-id>/result.json through the validating Node module.
# Uses RUN_ID, EVIDENCE_RUN_DIR, DOCUMENTS_CLI, QUALIFY_BUNDLE_ADMISSION, and the LAUNCH_* records.
outcome_write_result() {
  local result_input="${EVIDENCE_RUN_DIR}/.result-input.$$.json"
  local documents_library="${DOCUMENTS_CLI%/*}/lib/bootstrap-documents.mjs"
  local end_epoch
  local duration
  local stage
  local scan
  local generator_status=0
  local writer_status=0
  local -a tool_arguments=()
  local -a scan_arguments=()

  end_epoch="$(date -u +%s)" || return 5
  duration=$((end_epoch - OUTCOME_STARTED_EPOCH))
  if [[ "$duration" -lt 0 ]]; then duration=0; fi
  for stage in "${!OUTCOME_TOOL_STATUSES[@]}"; do
    tool_arguments+=("${stage}=${OUTCOME_TOOL_STATUSES[$stage]}")
  done
  for scan in "${!OUTCOME_SCANS[@]}"; do
    scan_arguments+=("${scan}=${OUTCOME_SCANS[$scan]}")
  done

  node --input-type=module - \
    "$result_input" "$documents_library" "$RUN_ID" "$OUTCOME_PRIMARY_STATUS" \
    "$OUTCOME_FAILED_STAGE" "$(outcome_next_action)" "$duration" \
    "$OUTCOME_TEST_COMMIT" "$OUTCOME_TEST_DIRTY" "$QUALIFY_BUNDLE_ADMISSION" \
    "$LAUNCH_VM_CONFIGURATION_JSON" "$LAUNCH_QEMU_VERSION" "$LAUNCH_OVMF_VERSION" \
    "$LAUNCH_VERDICT" "$OUTCOME_CLEANUP_OUTCOME" "$OUTCOME_CLEANUP_GUIDANCE" \
    "${#tool_arguments[@]}" "${tool_arguments[@]}" \
    "${#scan_arguments[@]}" "${scan_arguments[@]}" \
    "${#OUTCOME_LEFTOVERS[@]}" "${OUTCOME_LEFTOVERS[@]}" <<'NODE' || generator_status=$?
import { writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const args = process.argv.slice(2);
const [
  outputPath, libraryPath, runId, statusText, failedStage, nextAction, durationText,
  commit, dirtyText, admissionText, vmText, qemuVersion, ovmfVersion, verdictText,
  cleanupOutcome, guidance,
] = args;
let cursor = 16;
const take = () => {
  const count = Number(args[cursor++]);
  const items = args.slice(cursor, cursor + count);
  cursor += count;
  return items;
};
const toolEntries = take();
const scanEntries = take();
const leftovers = take();
const pairs = entries => Object.fromEntries(entries.map(entry => {
  const separator = entry.indexOf('=');
  return [entry.slice(0, separator), entry.slice(separator + 1)];
}));

const { CHECK_IDS } = await import(pathToFileURL(libraryPath).href);
const admission = JSON.parse(admissionText);
let verdict = null;
try {
  verdict = verdictText === '' ? null : JSON.parse(verdictText);
} catch {
  verdict = null;
}
// Per-check results are reported only when the guest report was accepted as complete and consistent.
const accepted = verdict !== null && Array.isArray(verdict.errors) && verdict.errors.length === 0
  && Array.isArray(verdict.failed_checks);
const checks = Object.fromEntries(CHECK_IDS.map(id => [
  id,
  accepted ? (verdict.failed_checks.includes(id) ? 'failed' : 'passed') : 'not_run',
]));
const document = {
  run_id: runId,
  artifact: {
    iso_name: admission.iso_name,
    iso_sha256: admission.iso_sha256,
    build_commit: admission.build_commit,
    build_run_id: admission.build_run_id,
  },
  test_code: { commit, dirty: dirtyText === 'true' },
  vm_configuration: JSON.parse(vmText),
  versions: { qemu: qemuVersion, ovmf: ovmfVersion },
  checks,
  duration_seconds: Number(durationText),
  failed_stage: failedStage || null,
  next_action: nextAction || null,
  status: Number(statusText),
  original_tool_statuses: Object.fromEntries(Object.entries(pairs(toolEntries)).map(([key, value]) => [key, Number(value)])),
  scans: pairs(scanEntries),
  cleanup: {
    outcome: cleanupOutcome,
    leftover_resources: leftovers,
    recovery_guidance: guidance || null,
  },
};
writeFileSync(outputPath, `${JSON.stringify(document, null, 2)}\n`, { mode: 0o600 });
NODE
  if [[ "$generator_status" -ne 0 ]]; then
    rm -f -- "$result_input"
    printf 'MirrorOS test: could not assemble the result input (status %s).\n' "$generator_status" >&2
    return 5
  fi

  node "$DOCUMENTS_CLI" write-result --input "$result_input" --output "${EVIDENCE_RUN_DIR}/result.json" || writer_status=$?
  rm -f -- "$result_input"
  if [[ "$writer_status" -ne 0 ]]; then
    printf 'MirrorOS test: could not write a valid result document (status %s).\n' "$writer_status" >&2
    return 5
  fi
  chmod 600 -- "${EVIDENCE_RUN_DIR}/result.json" || return 5
}
