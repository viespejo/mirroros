#!/usr/bin/bash

# Scans the retained evidence (result, serial output, QEMU diagnostics, earlier reports) with
# redacted Gitleaks. Findings keep the run private and yield 2; a scanner failure yields 5.
evidence_scan() {
  local evidence_dir="$1"
  local report_path="${evidence_dir}/gitleaks-evidence.json"
  local scanner_status=0

  gitleaks dir --redact --no-banner --report-format json --report-path "$report_path" \
    "$evidence_dir" >/dev/null 2>&1 || scanner_status=$?
  if [[ -e "$report_path" ]]; then chmod 600 -- "$report_path"; fi
  outcome_record_tool_status evidence_scan "$scanner_status"

  case "$scanner_status" in
    0)
      outcome_set_scan evidence passed
      ;;
    1)
      outcome_set_scan evidence findings
      outcome_mark_failure 2 evidence-scan
      printf 'MirrorOS test: Gitleaks detected a secret in the run evidence; it stays private at %s (report: %s).\n' \
        "$evidence_dir" "$report_path" >&2
      return 2
      ;;
    *)
      outcome_set_scan evidence failed
      outcome_mark_failure 5 evidence-scan
      printf 'MirrorOS test: the evidence Gitleaks scan failed with original status %s.\n' "$scanner_status" >&2
      return 5
      ;;
  esac
}

# The terminal summary is derived only from result.json, never from raw guest logs.
evidence_render_summary() {
  local render_status=0

  node "$DOCUMENTS_CLI" render-summary --result "${EVIDENCE_RUN_DIR}/result.json" || render_status=$?
  if [[ "$render_status" -ne 0 ]]; then
    printf 'MirrorOS test: could not render the summary from the result document (status %s).\n' "$render_status" >&2
    outcome_mark_failure 5 summary-render
    return 5
  fi
  printf 'Evidence: %s\n' "$EVIDENCE_RUN_DIR"
}

# Writes the result, scans the evidence including that result, rewrites the result when the scan
# does not pass, and renders the summary. The evidence scan state is provisional until the scan runs.
evidence_finalize() {
  outcome_set_scan evidence passed
  outcome_record_tool_status evidence_scan 0
  if ! outcome_write_result; then
    outcome_mark_failure 5 result-write
    return 5
  fi
  if ! evidence_scan "$EVIDENCE_RUN_DIR"; then
    if ! outcome_write_result; then
      outcome_mark_failure 5 result-write
      return 5
    fi
  fi
  evidence_render_summary
}
