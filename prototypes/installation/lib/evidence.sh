#!/usr/bin/bash
# Prototype harness: evidence retention, canary search, metadata, and result document.
# Evidence lives under evidence/prototypes/installation/<engine>/<run-id>/ with 0700 directories
# and 0600 files. Only allowlisted files are retained. No scan here has an exclusion.

EVIDENCE_ALLOWLIST=(
  result.json
  run-metadata.json
  serial-install.log
  serial-verify.log
  qemu-install-diagnostics.log
  qemu-verify-diagnostics.log
  install-report.json
  verify-report.json
  mirrorlist.txt
  disk-state.txt
  gitleaks-nocloud.json
  gitleaks-evidence.json
  canary-search.json
)

EVIDENCE_REMOVED=()
EVIDENCE_CANARY_STATUS='not_run'
EVIDENCE_SCAN_STATUS='not_run'
EVIDENCE_COMMIT=''
EVIDENCE_DIRTY='false'
EVIDENCE_DIRTY_PATHS_JSON='[]'

# Records the repository commit and whether the tree (untracked files included) is dirty.
evidence_capture_commit() {
  local repository_root="$1"
  local porcelain

  if ! EVIDENCE_COMMIT="$(git -C "$repository_root" rev-parse HEAD 2>/dev/null)" || \
    [[ ! "$EVIDENCE_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    printf '%s\n' 'MirrorOS prototype: could not determine the repository commit.' >&2
    return 6
  fi
  if ! porcelain="$(git -C "$repository_root" status --porcelain --untracked-files=all 2>/dev/null)"; then
    printf '%s\n' 'MirrorOS prototype: could not determine the repository state.' >&2
    return 6
  fi
  if [[ -n "$porcelain" ]]; then
    EVIDENCE_DIRTY='true'
    EVIDENCE_DIRTY_PATHS_JSON="$(printf '%s\n' "$porcelain" | cut -c4- | jq -R . | jq -s .)" || return 6
  fi
}

# Removes anything that is not allowlisted and enforces 0700/0600.
evidence_enforce_allowlist() {
  local dir="$1"
  local entry
  local name
  local allowed
  local keep

  EVIDENCE_REMOVED=()
  for entry in "$dir"/* "$dir"/.[!.]*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    name="${entry##*/}"
    keep=0
    for allowed in "${EVIDENCE_ALLOWLIST[@]}"; do
      [[ "$name" == "$allowed" ]] && keep=1
    done
    if [[ "$keep" -eq 1 && -f "$entry" && ! -L "$entry" ]]; then
      chmod 600 -- "$entry"
    else
      rm -rf -- "$entry"
      EVIDENCE_REMOVED+=("$name")
    fi
  done
  chmod 700 -- "$dir"
}

# Searches the retained evidence for both canary values and records only the outcome.
evidence_canary_search() {
  local dir="$1"
  local status=0
  local verdict

  proto_secrets_canary_search "$dir" || status=$?
  case "$status" in
    0) EVIDENCE_CANARY_STATUS='passed'; verdict='none_found' ;;
    1) EVIDENCE_CANARY_STATUS='found'; verdict='found' ;;
    *) EVIDENCE_CANARY_STATUS='failed'; verdict='search_failed' ;;
  esac
  jq -n --arg verdict "$verdict" --arg searched "${dir##*/evidence/}" \
    '{schema_version: 1, searched: $searched, values: 2, result: $verdict}' \
    > "${dir}/canary-search.json" && chmod 600 -- "${dir}/canary-search.json"
  case "$status" in
    0) return 0 ;;
    1)
      printf 'MirrorOS prototype: a canary value was found in the run evidence; it stays private at %s.\n' "$dir" >&2
      return 2
      ;;
    *)
      printf '%s\n' 'MirrorOS prototype: the canary search failed.' >&2
      return 5
      ;;
  esac
}

# Redacted Gitleaks scan of the retained evidence, with no exclusions.
evidence_scan() {
  local dir="$1"
  local report_path="${dir}/gitleaks-evidence.json"
  local scanner_status=0

  gitleaks dir --redact --no-banner --report-format json --report-path "$report_path" \
    "$dir" > /dev/null 2>&1 || scanner_status=$?
  [[ ! -e "$report_path" ]] || chmod 600 -- "$report_path"
  case "$scanner_status" in
    0) EVIDENCE_SCAN_STATUS='passed' ;;
    1)
      EVIDENCE_SCAN_STATUS='findings'
      printf 'MirrorOS prototype: Gitleaks detected a secret in the run evidence; it stays private at %s.\n' "$dir" >&2
      return 2
      ;;
    *)
      EVIDENCE_SCAN_STATUS='failed'
      printf 'MirrorOS prototype: the evidence Gitleaks scan failed with original status %s.\n' "$scanner_status" >&2
      return 5
      ;;
  esac
}

# Arguments: evidence run dir.
evidence_write_metadata() {
  local dir="$1"

  jq -n \
    --arg run_id "$RUN_ID" --arg engine "$PROTO_ENGINE_NAME" --arg variant "$PROTO_VARIANT" \
    --arg mode "$PROTO_MODE" --arg commit "$EVIDENCE_COMMIT" --argjson dirty "$EVIDENCE_DIRTY" \
    --argjson dirty_paths "$EVIDENCE_DIRTY_PATHS_JSON" \
    --arg bundle_directory "${BUNDLE_DIR##*/}" --arg iso "${BUNDLE_ISO##*/}" \
    --arg iso_sha256 "$BUNDLE_ISO_SHA256" --arg artifact_commit "$BUNDLE_ARTIFACT_COMMIT" \
    --arg artifact_run_id "$BUNDLE_ARTIFACT_RUN_ID" --arg qemu "$LAUNCH_QEMU_VERSION" \
    --arg machine "$REFERENCE_VM_MACHINE" --arg memory "$REFERENCE_VM_MEMORY_MIB" \
    --arg smp "$REFERENCE_VM_SMP" --arg disk_size "$REFERENCE_VM_DISK_SIZE" \
    --arg config_version "$REFERENCE_VM_CONFIG_VERSION" \
    --argjson install_deadline "$PROTO_INSTALL_DEADLINE_SECONDS" \
    --argjson verify_deadline "$PROTO_VERIFY_DEADLINE_SECONDS" \
    '{schema_version: 1, run_id: $run_id, engine: $engine, variant: $variant, mode: $mode,
      commit: $commit, dirty: $dirty, dirty_paths: $dirty_paths,
      bundle: {directory: $bundle_directory, iso: $iso, iso_sha256: $iso_sha256,
               artifact_commit: $artifact_commit, artifact_run_id: $artifact_run_id},
      vm: {config_version: $config_version, machine: $machine, memory_mib: $memory, smp: $smp,
           disk_size: $disk_size, qemu: $qemu},
      deadlines_seconds: {install: $install_deadline, verify: $verify_deadline}}' \
    > "${dir}/run-metadata.json" && chmod 600 -- "${dir}/run-metadata.json"
}

evidence_json_number() {
  if [[ "${1:-}" =~ ^[0-9]+$ ]]; then printf '%s' "$1"; else printf 'null'; fi
}

# Writes result.json from the harness state variables.
evidence_write_result() {
  local dir="$1"

  jq -n \
    --arg run_id "$RUN_ID" --arg engine "$PROTO_ENGINE_NAME" --arg variant "$PROTO_VARIANT" \
    --arg mode "$PROTO_MODE" --arg commit "$EVIDENCE_COMMIT" --argjson dirty "$EVIDENCE_DIRTY" \
    --argjson status "$PROTO_STATUS" --arg stage "$PROTO_STAGE" \
    --arg install_outcome "$PROTO_INSTALL_OUTCOME" --argjson install_qemu "$(evidence_json_number "$PROTO_INSTALL_QEMU_STATUS")" \
    --argjson install_seconds "$(evidence_json_number "$PROTO_INSTALL_SECONDS")" \
    --argjson engine_exit "$(evidence_json_number "$PROTO_ENGINE_EXIT")" \
    --arg verify_outcome "$PROTO_VERIFY_OUTCOME" --argjson verify_qemu "$(evidence_json_number "$PROTO_VERIFY_QEMU_STATUS")" \
    --argjson verify_seconds "$(evidence_json_number "$PROTO_VERIFY_SECONDS")" \
    --arg verify_result "$PROTO_VERIFY_RESULT" \
    --arg nocloud_scan "$PROTO_NOCLOUD_SCAN" --arg canary "$EVIDENCE_CANARY_STATUS" \
    --arg evidence_scan "$EVIDENCE_SCAN_STATUS" \
    --arg cleanup "$STOP_CLEANUP_OUTCOME" --arg cleanup_guidance "$STOP_CLEANUP_GUIDANCE" \
    --arg qemu_state "$STOP_QEMU_STATE" \
    '{schema_version: 1, run_id: $run_id, engine: $engine, variant: $variant, mode: $mode,
      commit: $commit, dirty: $dirty,
      exit_status: $status, failure_stage: (if $stage == "" then null else $stage end),
      verdict: (if $status == 0 then "passed" else "failed" end),
      install: {outcome: $install_outcome, qemu_status: $install_qemu, duration_seconds: $install_seconds,
                engine_exit_status: $engine_exit},
      verify: {outcome: $verify_outcome, qemu_status: $verify_qemu, duration_seconds: $verify_seconds,
               report_result: (if $verify_result == "" then null else $verify_result end)},
      scans: {nocloud: $nocloud_scan, canary_search: $canary, evidence: $evidence_scan},
      cleanup: {outcome: $cleanup, qemu_stop: $qemu_state,
                guidance: (if $cleanup_guidance == "" then null else $cleanup_guidance end)}}' \
    > "${dir}/result.json" && chmod 600 -- "${dir}/result.json"
}

# Canary search, allowlist, result, then the redacted scan including the result. When the scan does
# not pass, the result is rewritten so that it records the failure.
evidence_finalize() {
  local dir="$EVIDENCE_RUN_DIR"

  if ! evidence_canary_search "$dir"; then
    proto_mark_failure 2 canary-search
  fi
  evidence_enforce_allowlist "$dir"
  if ! evidence_write_result "$dir"; then
    proto_mark_failure 5 result-write
    return 5
  fi
  if ! evidence_scan "$dir"; then
    proto_mark_failure 2 evidence-scan
    evidence_write_result "$dir" || return 5
  fi
  printf 'Evidence: %s\n' "$dir"
  printf 'Result: %s (exit status %s)\n' "$(jq -r .verdict "${dir}/result.json")" "$PROTO_STATUS"
}
