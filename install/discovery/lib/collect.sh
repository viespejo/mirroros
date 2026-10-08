#!/usr/bin/bash
# Shared helpers for the discovery collectors. Sourced, never executed.
# The live medium ships no jq, so JSON is assembled with the small helpers below.

# MIRROROS_DISCOVERY_ROOT is small process context for tests; discover offers no option for it.
DISCOVERY_ROOT="${MIRROROS_DISCOVERY_ROOT:-/}"
DISCOVERY_ROOT="${DISCOVERY_ROOT%/}"

discovery_path() {
  printf '%s%s' "$DISCOVERY_ROOT" "$1"
}

discovery_json_string() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  value="${value//[[:cntrl:]]/}"
  printf '"%s"' "$value"
}

discovery_trim() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

discovery_first_line() {
  local line=''

  [[ -r "$1" ]] || return 1
  IFS= read -r line < "$1" || [[ -n "$line" ]] || return 1
  discovery_trim "$line"
}

# An unexpected child failure ends the collector with status 5. The final stderr line carries the
# child's original status so that the orchestrator can retain it as child_exit_status.
discovery_child_fail() {
  local operation="$1"
  local status="$2"

  printf 'child_exit_status=%s operation=%s\n' "$status" "$operation" >&2
  exit 5
}
