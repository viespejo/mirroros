#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared across the frontend libraries sourced by run.
# Frontend contract check: per-point records, run-metadata.json, and result.json. Non-production.
# The VM-specific evidence_write_metadata and evidence_write_result of the installation harness are
# not used; this writer has its own schema.

FE_SURFACE=''
FE_TERM=''
FE_TTY_KIND=''
FE_GUM_VERSION=''
FE_POINTS_JSON='{}'
FE_POINT_COUNT=10

# Arguments: point, class (pass, pass-with-wrapper, fail), wrappers (comma-separated, may be empty),
# observed exit status (JSON), detail, optional extra object (JSON) merged into the record.
fe_record() {
  local point="$1"
  local class="$2"
  local wrappers="$3"
  local observed="$4"
  local detail="$5"
  local extra="${6:-}"

  [[ -n "$extra" ]] || extra='{}'
  if ! FE_POINTS_JSON="$(jq -c --arg point "$point" --arg class "$class" --arg wrappers "$wrappers" \
    --argjson observed "$observed" --arg detail "$detail" --argjson extra "$extra" \
    '. + {($point): ({class: $class, wrappers: (if $wrappers == "" then [] else ($wrappers | split(",")) end),
                      observed_exit_status: $observed, detail: $detail} + $extra)}' <<< "$FE_POINTS_JSON")"; then
    printf '%s\n' 'MirrorOS prototype: could not record a contract point.' >&2
    return 6
  fi
  printf '  %-4s %-17s %s\n' "$point" "$class" "$detail"
}

# Arguments: ok (yes|no), wrapper needed (yes|no). Prints the class.
fe_class() {
  if [[ "$1" != yes ]]; then
    printf 'fail'
  elif [[ "$2" == yes ]]; then
    printf 'pass-with-wrapper'
  else
    printf 'pass'
  fi
}

# Arguments: evidence run dir.
fe_write_metadata() {
  local dir="$1"
  local no_color=false

  [[ -z "${NO_COLOR:-}" ]] || no_color=true
  jq -n \
    --arg run_id "$RUN_ID" --arg surface "$FE_SURFACE" --arg term "$FE_TERM" --arg tty_kind "$FE_TTY_KIND" \
    --arg gum_version "$FE_GUM_VERSION" --arg commit "$EVIDENCE_COMMIT" --argjson dirty "$EVIDENCE_DIRTY" \
    --argjson dirty_paths "$EVIDENCE_DIRTY_PATHS_JSON" --argjson ambient_no_color "$no_color" \
    '{schema_version: 1, run_id: $run_id, track: "frontend", candidate: "gum", surface: $surface,
      term: $term, tty_kind: $tty_kind, gum_version: $gum_version, commit: $commit, dirty: $dirty,
      dirty_paths: $dirty_paths, ambient_no_color: $ambient_no_color, data: "mock"}' \
    > "${dir}/run-metadata.json" && chmod 600 -- "${dir}/run-metadata.json"
}

# Arguments: evidence run dir, exit status.
fe_write_result() {
  local dir="$1"
  local status="$2"

  jq -n \
    --arg run_id "$RUN_ID" --arg surface "$FE_SURFACE" --arg term "$FE_TERM" \
    --arg gum_version "$FE_GUM_VERSION" --arg commit "$EVIDENCE_COMMIT" --argjson dirty "$EVIDENCE_DIRTY" \
    --argjson points "$FE_POINTS_JSON" --argjson expected "$FE_POINT_COUNT" \
    --arg canary "$EVIDENCE_CANARY_STATUS" --arg scan "$EVIDENCE_SCAN_STATUS" --argjson status "$status" \
    '{schema_version: 1, run_id: $run_id, track: "frontend", candidate: "gum", surface: $surface,
      term: $term, gum_version: $gum_version, commit: $commit, dirty: $dirty,
      points: $points,
      summary: {pass: ([$points[] | select(.class == "pass")] | length),
                pass_with_wrapper: ([$points[] | select(.class == "pass-with-wrapper")] | length),
                fail: ([$points[] | select(.class == "fail")] | length)},
      wrappers: ([$points[].wrappers[]] | unique),
      verdict: (if ($points | length) != $expected then "incomplete"
                elif ([$points[] | select(.class == "fail")] | length) > 0 then "has_failures"
                else "all_points_passed" end),
      scans: {canary_search: $canary, evidence: $scan},
      exit_status: $status}' \
    > "${dir}/result.json" && chmod 600 -- "${dir}/result.json"
}
