#!/usr/bin/bash

BUILD_STARTED_AT=''
BUILD_STARTED_EPOCH=''
# shellcheck disable=SC2034 # Consumed by container.sh for mkarchiso.
BUILD_SOURCE_DATE_EPOCH=''
BUILD_PRIMARY_STATUS=0
BUILD_FAILED_STAGE=''
BUILD_ORIGINAL_STATUS=''
BUILD_CLEANUP_OUTCOME='pending'
BUILD_CLEANUP_GUIDANCE=''
BUILD_PUBLISHED=false
BUILD_VALIDATION_PRECONDITIONS='passed'
BUILD_VALIDATION_PROFILE_SCAN='not_run'
BUILD_VALIDATION_SIGNATURE='not_run'
BUILD_VALIDATION_ARCHISO='not_run'
BUILD_VALIDATION_EVIDENCE_SCAN='not_run'
BUILD_VALIDATION_BUNDLE='not_run'
declare -Ag BUILD_TOOL_STATUSES=()
BUILD_DIAGNOSTICS=()
BUILD_LEFTOVER_RESOURCES=()

build_outcome_initialize() {
  BUILD_STARTED_EPOCH="$(date -u +%s)" || return 2
  BUILD_STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)" || return 2
  # shellcheck disable=SC2034 # Consumed by container.sh for mkarchiso.
  BUILD_SOURCE_DATE_EPOCH="$BUILD_STARTED_EPOCH"
}

build_outcome_record_tool_status() {
  local stage="$1"
  local status="$2"

  BUILD_TOOL_STATUSES["$stage"]="$status"
}

build_outcome_set_validation() {
  local validation="$1"
  local state="$2"

  case "$validation" in
    profile_secret_scan) BUILD_VALIDATION_PROFILE_SCAN="$state" ;;
    signature_verification) BUILD_VALIDATION_SIGNATURE="$state" ;;
    archiso_version) BUILD_VALIDATION_ARCHISO="$state" ;;
    evidence_secret_scan) BUILD_VALIDATION_EVIDENCE_SCAN="$state" ;;
    bundle_validation) BUILD_VALIDATION_BUNDLE="$state" ;;
    *) return 2 ;;
  esac
}

build_outcome_mark_failure() {
  local normalized_status="$1"
  local stage="$2"
  local original_status="${3:-}"

  if [[ "$BUILD_PRIMARY_STATUS" -eq 0 ]]; then
    BUILD_PRIMARY_STATUS="$normalized_status"
    BUILD_FAILED_STAGE="$stage"
    BUILD_ORIGINAL_STATUS="$original_status"
  fi
}

build_outcome_mark_interrupted() {
  local status="$1"
  local signal_name="$2"

  if [[ "$BUILD_PRIMARY_STATUS" -eq 0 ]]; then
    BUILD_PRIMARY_STATUS="$status"
    BUILD_FAILED_STAGE="signal-${signal_name}"
    BUILD_ORIGINAL_STATUS=''
  fi
}

build_outcome_add_diagnostic() {
  local reference="$1"
  local existing

  for existing in "${BUILD_DIAGNOSTICS[@]}"; do
    [[ "$existing" == "$reference" ]] && return 0
  done
  BUILD_DIAGNOSTICS+=("$reference")
}

build_outcome_add_leftover() {
  local resource="$1"
  local existing

  for existing in "${BUILD_LEFTOVER_RESOURCES[@]}"; do
    [[ "$existing" == "$resource" ]] && return 0
  done
  BUILD_LEFTOVER_RESOURCES+=("$resource")
}

build_outcome_note_cleanup_failure() {
  local guidance="$1"

  BUILD_CLEANUP_OUTCOME='failure'
  BUILD_CLEANUP_GUIDANCE="$guidance"
  if [[ "$BUILD_PRIMARY_STATUS" -eq 0 ]]; then
    build_outcome_mark_failure 5 cleanup ''
  fi
}

build_outcome_mark_cleanup_success() {
  if [[ "$BUILD_CLEANUP_OUTCOME" != 'failure' ]]; then
    BUILD_CLEANUP_OUTCOME='success'
    BUILD_CLEANUP_GUIDANCE=''
  fi
}

build_outcome_write_result() {
  local result_status="$BUILD_PRIMARY_STATUS"
  local result_outcome='failure'
  local end_time
  local end_epoch
  local duration
  local published_text="$BUILD_PUBLISHED"
  local diagnostics_count="${#BUILD_DIAGNOSTICS[@]}"
  local leftovers_count="${#BUILD_LEFTOVER_RESOURCES[@]}"
  local result_input="${EVIDENCE_RUN_DIR}/.execution-result-input.$$.json"
  local generator_status
  local writer_status
  local reference
  local resource
  local -a tool_status_arguments=()
  local -a validation_arguments=()
  local -a diagnostic_arguments=()
  local -a leftover_arguments=()
  local stage

  if [[ "$BUILD_PRIMARY_STATUS" -eq 130 || "$BUILD_PRIMARY_STATUS" -eq 143 ]]; then
    result_outcome='interrupted'
  elif [[ "$BUILD_PRIMARY_STATUS" -eq 0 && "$BUILD_PUBLISHED" == 'true' && "$BUILD_CLEANUP_OUTCOME" == 'success' ]]; then
    result_outcome='success'
  elif [[ "$BUILD_PRIMARY_STATUS" -eq 0 ]]; then
    result_outcome='unknown'
    result_status='null'
  fi

  end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)" || return 5
  end_epoch="$(date -u +%s)" || return 5
  duration=$((end_epoch - BUILD_STARTED_EPOCH))
  (( duration < 0 )) && duration=0

  for stage in "${!BUILD_TOOL_STATUSES[@]}"; do
    tool_status_arguments+=("${stage}=${BUILD_TOOL_STATUSES[$stage]}")
  done
  validation_arguments=(
    "preconditions=${BUILD_VALIDATION_PRECONDITIONS}"
    "profile_secret_scan=${BUILD_VALIDATION_PROFILE_SCAN}"
    "signature_verification=${BUILD_VALIDATION_SIGNATURE}"
    "archiso_version=${BUILD_VALIDATION_ARCHISO}"
    "evidence_secret_scan=${BUILD_VALIDATION_EVIDENCE_SCAN}"
    "bundle_validation=${BUILD_VALIDATION_BUNDLE}"
  )
  for reference in "${BUILD_DIAGNOSTICS[@]}"; do
    diagnostic_arguments+=("$reference")
  done
  for resource in "${BUILD_LEFTOVER_RESOURCES[@]}"; do
    leftover_arguments+=("$resource")
  done

  if [[ "$BUILD_FAILED_STAGE" == 'signal-'* ]]; then
    result_outcome='interrupted'
  fi

  if node --input-type=module - \
    "$result_input" "$RUN_ID" "$result_status" "$result_outcome" \
    "$BUILD_FAILED_STAGE" "$BUILD_ORIGINAL_STATUS" "$BUILD_STARTED_AT" \
    "$end_time" "$duration" "$published_text" "$BUILD_CLEANUP_OUTCOME" \
    "$BUILD_CLEANUP_GUIDANCE" "$diagnostics_count" "${diagnostic_arguments[@]}" \
    "$leftovers_count" "${leftover_arguments[@]}" \
    "${#tool_status_arguments[@]}" "${tool_status_arguments[@]}" \
    "${#validation_arguments[@]}" "${validation_arguments[@]}" <<'NODE'
import { writeFileSync } from 'node:fs';

const args = process.argv.slice(2);
const [
  outputPath,
  runId,
  statusText,
  outcome,
  failedStage,
  originalStatusText,
  startedAt,
  endedAt,
  durationText,
  publishedText,
  cleanupOutcome,
  recoveryGuidance,
  diagnosticCountText,
] = args;
let cursor = 13;
const diagnosticCount = Number(diagnosticCountText);
const diagnosticReferences = args.slice(cursor, cursor + diagnosticCount);
cursor += diagnosticCount;
const leftoverCount = Number(args[cursor++]);
const leftoverResources = args.slice(cursor, cursor + leftoverCount);
cursor += leftoverCount;
const toolStatusCount = Number(args[cursor++]);
const originalToolStatuses = {};
for (const entry of args.slice(cursor, cursor + toolStatusCount)) {
  const separator = entry.lastIndexOf('=');
  originalToolStatuses[entry.slice(0, separator)] = Number(entry.slice(separator + 1));
}
cursor += toolStatusCount;
const validationCount = Number(args[cursor++]);
const validations = {};
for (const entry of args.slice(cursor, cursor + validationCount)) {
  const separator = entry.indexOf('=');
  validations[entry.slice(0, separator)] = entry.slice(separator + 1);
}
const document = {
  schema_version: 1,
  run_id: runId,
  references: {
    sources: ['image/archiso'],
    artifacts: publishedText === 'true' ? [`dist/${runId}`] : [],
  },
  started_at: startedAt,
  ended_at: endedAt,
  duration_seconds: Number(durationText),
  outcome,
  exit_status: statusText === 'null' ? null : Number(statusText),
  failed_stage: failedStage || null,
  original_tool_statuses: originalToolStatuses,
  validations,
  diagnostic_references: diagnosticReferences,
  published: publishedText === 'true',
  cleanup: {
    outcome: cleanupOutcome,
    leftover_resources: leftoverResources,
    recovery_guidance: recoveryGuidance || null,
  },
};
if (originalStatusText !== '') {
  document.original_tool_statuses[failedStage || 'interruption'] = Number(originalStatusText);
}
writeFileSync(outputPath, `${JSON.stringify(document, null, 2)}\n`, { mode: 0o600 });
NODE
  then
    generator_status=0
  else
    generator_status=$?
  fi
  if [[ "$generator_status" -ne 0 ]]; then
    rm -f -- "$result_input"
    return 5
  fi
  chmod 600 -- "$result_input" || {
    rm -f -- "$result_input"
    return 5
  }

  if node "${BUILDER_DIR}/build-documents.mjs" write-result \
    --input "$result_input" --output "${EVIDENCE_RUN_DIR}/execution-result.json"; then
    writer_status=0
  else
    writer_status=$?
  fi
  rm -f -- "$result_input"
  if [[ "$writer_status" -ne 0 ]]; then
    printf 'MirrorOS build: could not write a valid execution result (status %s).\n' "$writer_status" >&2
    return 5
  fi
  chmod 600 -- "${EVIDENCE_RUN_DIR}/execution-result.json" || return 5
}
