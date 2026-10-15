#!/usr/bin/bash
# shellcheck disable=SC2034 # Shared state is consumed by the sourced configure libraries and steps.
CONFIGURE_CONTEXT=running
# Test-only process context, not a public target-root interface.
CONFIGURE_ROOT="${MIRROROS_CONFIGURE_ROOT:-/}"
CONFIGURE_ROOT="${CONFIGURE_ROOT%/}"
TARGET_USER="${SUDO_USER:-}"
CFG_REFRESH=0
CFG_OUTPUT=''
CFG_STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf unavailable)"
CFG_CURRENT=validation
CFG_REASON=''
CFG_GUARD=not_needed
CFG_FINISHING=0
CFG_EVIDENCE=0
CFG_ERRORS=()
CFG_STEPS=()
declare -A CFG_STATUS=() CFG_POST=() CFG_RESOLVED=() CFG_INSTALLED=()

cfg_path() { printf '%s%s' "$CONFIGURE_ROOT" "$1"; }

cfg_context() {
  case "$CONFIGURE_CONTEXT" in
    running) ;;
    target) printf '%s\n' 'MirrorOS configure: target context pending plan 02-16.' >&2; exit 6 ;;
    *) printf '%s\n' 'MirrorOS configure: invalid execution context.' >&2; exit 6 ;;
  esac
}

cfg_log() {
  local text
  text="$(cfg_clean "$*")"
  printf '%s\n' "$text"
  if (( CFG_EVIDENCE )) && [[ "${CFG_IN_STEP:-0}" != 1 ]]; then
    printf '%s\n' "$text" >> "$CFG_OUTPUT/configure.log"
  fi
}

cfg_changed() { : > "$CFG_OUTPUT/.changed"; }

cfg_run() {
  cfg_context
  cfg_log "$*"
  # Only commands owned by these helpers are logged; never enable xtrace or dump user files.
  (umask 022; "$@") < /dev/null >> "$CFG_OUTPUT/configure.log" 2>&1
}

cfg_require() {
  if ! "$@"; then
    printf 'Postcondition failed: %s\n' "$*" >&2
    exit 4
  fi
}

cfg_finish() {
  local outcome="$1" reason="${2:-}" step
  (( CFG_FINISHING == 0 )) || exit "$outcome"
  CFG_FINISHING=1
  trap - ERR INT TERM HUP
  if [[ "$outcome" != 0 && -n "$CFG_CURRENT" && "$CFG_CURRENT" != validation ]]; then
    CFG_STATUS["$CFG_CURRENT"]=failed
    CFG_POST["$CFG_CURRENT"]="$reason"
  fi
  for step in "${CFG_STEPS[@]}"; do
    CFG_STATUS["$step"]="${CFG_STATUS[$step]:-not_run}"
    CFG_POST["$step"]="${CFG_POST[$step]:-not_checked}"
  done
  if (( CFG_EVIDENCE )); then
    rm -f -- "$CFG_OUTPUT/.changed" "$CFG_OUTPUT/.transaction"
    cfg_evidence_finish "$outcome" "$reason" || outcome=6
  fi
  if [[ "$outcome" == 0 ]]; then
    cfg_log 'MirrorOS configure: graphical login is available at the next boot; SDDM was not started.'
  else
    cfg_log "MirrorOS configure: step ${CFG_CURRENT:-validation}: ${reason:-internal failure} (outcome $outcome). Next action: rerun sudo operations/configure." >&2
  fi
  exit "$outcome"
}

cfg_execute() {
  local step child_status
  trap 'cfg_finish 3 "interrupted by SIGINT"' INT
  trap 'cfg_finish 5 "terminated by SIGTERM"' TERM
  trap 'cfg_finish 5 "terminated by SIGHUP"' HUP
  trap 'cfg_finish 5 "command failed (child status $?)"' ERR
  for step in "${CFG_STEPS[@]}"; do
    CFG_CURRENT="$step"
    cfg_log "== $step =="
    rm -f -- "$CFG_OUTPUT/.changed"
    child_status=0
    # A foreground step receives terminal SIGINT normally. A conditional subshell would
    # disable errexit; instead temporarily disable only the parent's error handling.
    trap - ERR
    set +e
    (
      set -Eeuo pipefail
      CFG_IN_STEP=1
      trap 'printf "Command failed (child status %s).\\n" "$?" >&2; exit 5' ERR
      trap 'exit 3' INT
      trap 'exit 5' TERM HUP
      STEP_DIR="$CAPABILITIES_DIR/$step"
      # shellcheck disable=SC1091 # The ordered, checked capability path is loaded at runtime.
      source "$STEP_DIR/apply"
    ) >> "$CFG_OUTPUT/configure.log" 2>&1
    child_status=$?
    set -e
    trap 'cfg_finish 5 "command failed (child status $?)"' ERR
    if (( child_status != 0 )); then
      case "$child_status" in
        3) cfg_finish 3 'step interrupted by SIGINT' ;;
        4) cfg_finish 4 'postcondition not satisfied; review configure.log' ;;
        6) cfg_finish 6 'internal step contract failure; review configure.log' ;;
        *) cfg_finish 5 "step command failed (child status $child_status); review configure.log" ;;
      esac
    fi
    CFG_STATUS["$step"]=unchanged
    [[ ! -e "$CFG_OUTPUT/.changed" ]] || CFG_STATUS["$step"]=changed
    CFG_POST["$step"]=passed
    cfg_log "$step: ${CFG_STATUS[$step]}"
  done
  CFG_CURRENT=''
  cfg_finish 0
}
