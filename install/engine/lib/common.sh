#!/usr/bin/bash
# shellcheck disable=SC2034 # Engine state is read by the other libraries and by apply, which source this file.
# Shared helpers of the installation engine (contracts/installation-engine.md): the run state, command
# execution, the check helpers, the records, and the single terminal path `finish`.
#
# MIRROROS_ENGINE_RUN_ROOT and MIRROROS_DISCOVERY_ROOT are small process context for tests; the engine offers
# no option for either. Nothing here ever echoes or logs the password, and xtrace is never enabled.

ENGINE_RUN_ROOT="${MIRROROS_ENGINE_RUN_ROOT:-/run/mirroros}"
ENGINE_RUN_ROOT="${ENGINE_RUN_ROOT%/}"
LOCK_FILE="${ENGINE_RUN_ROOT}/install.lock"
TARGET="${ENGINE_RUN_ROOT}/target"
DISCOVERY_ROOT="${MIRROROS_DISCOVERY_ROOT:-/}"
DISCOVERY_ROOT="${DISCOVERY_ROOT%/}"

PLAN_FILE=''
CONFIRMED_DIGEST=''
OUTPUT=''
ENGINE_LOG=''
PLAN_TEXT=''
STARTED_AT=''
IDENTITY_COMMIT=''
IDENTITY_DIRTY=''
PASSWORD=''
CURRENT_OP=''
COMPLETED=()
CONSTANTS=()
RESOLVED=()
CLEANUP=()
MIRROR_SERVERS=()
MIRRORLIST_SHA256=''
POSTCONDITIONS_JSON=''
LAST_ARGV=()
LAST_STATUS=0
FINISHING=0
STORAGE_OPTION=''
HIBERNATION=''
DISK_PATH=''
DISK_BY_ID=''
DISK_NODE=''
ESP_PART=''
ROOT_PART=''
ESP_UUID=''
ROOT_UUID=''
RESUME_OFFSET=''
PACKAGE_COUNT=''

# Paths below the test root; with the default root they are the real paths.
sys_path() {
  printf '%s%s' "$DISCOVERY_ROOT" "$1"
}

now_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

engine_log() {
  printf '%s\n' "$*" >> "$ENGINE_LOG"
}

# Runs a node helper with the plan text (when held) on stdin, without the lock descriptor.
node_helper() {
  local script="$1"
  shift
  printf '%s' "$PLAN_TEXT" | node "${SCRIPT_DIR}/${script}" "$@" 4>&-
}

join_by_comma() {
  local IFS=,
  printf '%s' "$*"
}

write_state() {
  local status="$1" current="${2:-}" failed="${3:-}"
  local arguments=(--output "$OUTPUT" --status "$status" --completed "$(join_by_comma "${COMPLETED[@]}")")
  [[ -z "$current" ]] || arguments+=(--current "$current")
  [[ -z "$failed" ]] || arguments+=(--failed "$failed")
  [[ -z "$PACKAGE_COUNT" || "$current" != install_packages ]] || arguments+=(--packages "$PACKAGE_COUNT")
  node_helper engine-record.mjs state "${arguments[@]}" || true
}

# Runs one external command with stdin from /dev/null, its output appended to engine.log, and neither the
# password nor the lock descriptor inherited. A failure ends the run through stage_fail. The command runs with
# umask 022: the engine's own umask 077 would otherwise leave directories it creates implicitly in the target
# (such as /etc) unreadable for ordinary users.
run() {
  LAST_ARGV=("$@")
  printf '$ %s\n' "$*" >> "$ENGINE_LOG"
  (umask 022; exec "$@") < /dev/null >> "$ENGINE_LOG" 2>&1 3>&- 4>&- || {
    LAST_STATUS=$?
    stage_fail
  }
}

# Like run, with the given text as stdin.
run_with_input() {
  local input="$1"
  shift
  LAST_ARGV=("$@")
  printf '$ %s (input from the engine)\n' "$*" >> "$ENGINE_LOG"
  printf '%s\n' "$input" | (umask 022; exec "$@") >> "$ENGINE_LOG" 2>&1 3>&- 4>&- || {
    LAST_STATUS=$?
    stage_fail
  }
}

# Like run, with stdout stored in the named variable (stderr goes to the log).
capture() {
  local name="$1" output
  shift
  LAST_ARGV=("$@")
  printf '$ %s\n' "$*" >> "$ENGINE_LOG"
  output="$( (umask 022; exec "$@") < /dev/null 2>> "$ENGINE_LOG" 3>&- 4>&-)" || {
    LAST_STATUS=$?
    stage_fail
  }
  printf -v "$name" '%s' "$output"
}

# Like run, with stdout written to a file of the target with the given mode.
run_to_target_file() {
  local mode="$1" relative="$2"
  shift 2
  LAST_ARGV=("$@")
  printf '$ %s > %s\n' "$*" "$relative" >> "$ENGINE_LOG"
  mkdir -p -- "$(dirname -- "${TARGET}${relative}")"
  "$@" < /dev/null > "${TARGET}${relative}" 2>> "$ENGINE_LOG" 3>&- 4>&- || {
    LAST_STATUS=$?
    stage_fail
  }
  chmod "$mode" -- "${TARGET}${relative}"
}

chroot_run() {
  run arch-chroot "$TARGET" "$@"
}

# Writes stdin to a file of the target with ordinary permissions (the engine itself runs with umask 077).
put_file() {
  local mode="$1" relative="$2"
  (
    umask 022
    mkdir -p -- "$(dirname -- "${TARGET}${relative}")"
    cat > "${TARGET}${relative}"
  ) || { LAST_ARGV=(write "$relative"); LAST_STATUS=1; stage_fail; }
  chmod "$mode" -- "${TARGET}${relative}"
}

record_constant() {
  CONSTANTS+=("$1=$2")
}

check_fail() {
  LAST_ARGV=(check "$1")
  LAST_STATUS=1
  engine_log "check failed: $1"
  stage_fail
}

stage_fail() {
  finish failed 5 stage_failed "$CURRENT_OP" \
    "The installation stopped at ${CURRENT_OP}: ${LAST_ARGV[0]:-the operation} did not complete (status ${LAST_STATUS})." \
    'Review engine.log in the run directory; retrying requires a new run with a new plan and confirmation.' \
    "$LAST_STATUS"
}

asset_fail() {
  LAST_ARGV=(asset "$CURRENT_OP")
  LAST_STATUS=6
  finish failed 6 engine_asset_mismatch "$CURRENT_OP" "$1" \
    'Rebuild or re-clone the installation medium; nothing was written from the mismatching asset.' ''
}

# Non-destructive best-effort cleanup: deactivate a swapfile and unmount what the engine mounted. It never
# wipes again and never touches a mount outside its own mount point.
cleanup_target() {
  local swapfile
  if [[ -d "$TARGET" ]]; then
    for swapfile in "$TARGET"/swapfile "$TARGET"/swap/swapfile; do
      if [[ -e "$swapfile" ]] && grep -qF -- "$swapfile" "$(sys_path /proc/swaps)" 2> /dev/null; then
        if swapoff "$swapfile" >> "$ENGINE_LOG" 2>&1 < /dev/null 3>&- 4>&-; then CLEANUP+=('swapoff=ok'); else CLEANUP+=('swapoff=failed'); fi
      fi
    done
    if mountpoint -q "$TARGET" 2> /dev/null; then
      if umount -R "$TARGET" >> "$ENGINE_LOG" 2>&1 < /dev/null 3>&- 4>&-; then CLEANUP+=('umount=ok'); else CLEANUP+=('umount=failed'); fi
    fi
  fi
}

# The single terminal path: records, cleanup, and exit. Arguments: outcome, exit status, reason code,
# operation, message, next step, child status (optional). The password is discarded first.
finish() {
  local outcome="$1" status="$2" code="${3:-}" operation="${4:-}" message="${5:-}" next_step="${6:-}" child="${7:-}"
  local item
  PASSWORD=''
  if (( FINISHING )); then exit "$status"; fi
  FINISHING=1
  trap - ERR INT TERM HUP
  if [[ -n "$OUTPUT" ]]; then
    if [[ "$outcome" != blocked && "$outcome" != invalidated ]]; then cleanup_target; fi
    local arguments=(--output "$OUTPUT" --started "$STARTED_AT" --outcome "$outcome" --exit "$status"
      --completed "$(join_by_comma "${COMPLETED[@]}")")
    [[ -z "$CONFIRMED_DIGEST" ]] || arguments+=(--digest "$CONFIRMED_DIGEST")
    [[ -z "$IDENTITY_COMMIT" ]] || arguments+=(--commit "$IDENTITY_COMMIT" --dirty "$IDENTITY_DIRTY")
    if [[ -n "$code" ]]; then
      arguments+=(--reason-code "$code" --reason-operation "${operation:-precheck}" --reason-message "$message" --reason-next-step "$next_step")
      [[ -z "$child" ]] || arguments+=(--child-status "$child")
    fi
    if [[ "$outcome" == failed && -n "$operation" && "$code" != engine_interrupted ]]; then
      arguments+=(--failed-operation "$operation")
      for item in "${LAST_ARGV[@]}"; do arguments+=(--failed-arg "$item"); done
    fi
    for item in "${RESOLVED[@]}"; do arguments+=(--resolved "$item"); done
    for item in "${MIRROR_SERVERS[@]}"; do arguments+=(--server "$item"); done
    [[ -z "$MIRRORLIST_SHA256" ]] || arguments+=(--mirrorlist-sha256 "$MIRRORLIST_SHA256")
    [[ -z "$POSTCONDITIONS_JSON" ]] || arguments+=(--postconditions "$POSTCONDITIONS_JSON")
    for item in "${CONSTANTS[@]}"; do arguments+=(--constant "$item"); done
    for item in "${CLEANUP[@]}"; do arguments+=(--cleanup "$item"); done
    node_helper engine-record.mjs run "${arguments[@]}" || status=6
    write_state "$outcome" "" "$([[ "$outcome" == failed && "$code" != engine_interrupted ]] && printf '%s' "$operation")" || true
  fi
  if [[ -n "$message" ]]; then printf 'MirrorOS engine: %s\n' "$message" >&2; fi
  exit "$status"
}

# The postconditions phase (contracts/installation-engine.md, "Postconditions"): after the last operation and before
# the terminal cleanup, the read-only checker inspects the still-mounted target and its answer decides the outcome.
# Every path ends in finish: installed (0), not_verified (4), or failed (5) when the checker gave no valid answer.
# A not_verified run is never retried, repaired, or converted into success or into status 5.
run_postconditions() {
  local result status=0 verdict failed first
  CURRENT_OP=postconditions
  engine_log '== postconditions =='
  write_state running postconditions
  LAST_ARGV=(install/postconditions/check)
  result="$("${CODE_ROOT}/install/postconditions/check" --plan "$PLAN_FILE" --digest "$CONFIRMED_DIGEST" --target-root "$TARGET" \
    < /dev/null 2>> "$ENGINE_LOG" 3>&- 4>&-)" || status=$?
  printf '%s\n' "$result" >> "$ENGINE_LOG"
  if [[ "$status" != 0 && "$status" != 4 ]]; then
    LAST_STATUS="$status"
    stage_fail
  fi
  verdict="$(node_helper engine-record.mjs verify-postconditions --result "$result" --exit "$status" 4>&-)" || verdict=invalid
  if [[ "$verdict" != valid:* ]]; then
    engine_log 'the postconditions result is not valid for this plan'
    LAST_STATUS="$status"
    stage_fail
  fi
  POSTCONDITIONS_JSON="$result"
  CURRENT_OP=''
  if [[ "$status" == 0 ]]; then finish installed 0; fi
  failed="${verdict#valid:}"
  first="${failed%%,*}"
  finish not_verified 4 '' postconditions \
    "Installation finished but could not be verified: the check ${first} failed. The disk was modified." ''
}

on_unexpected_error() {
  local status="$1"
  LAST_STATUS="$status"
  LAST_ARGV=("${LAST_ARGV[@]:-}")
  stage_fail
}

on_signal() {
  local number="$1"
  finish failed "$((128 + number))" engine_interrupted "${CURRENT_OP:-precheck}" \
    "The installation engine was interrupted by signal ${number}." \
    'Retrying requires a new run with a new plan and confirmation.' ''
}

# Plan parameter access: values of the current operation from the loader stream.
declare -A PARAM=()
param() {
  printf '%s' "${PARAM["${CURRENT_OP}.$1"]-}"
}

param_lines() {
  local -n target_array="$2"
  mapfile -t target_array <<< "${PARAM["${CURRENT_OP}.$1"]-}"
  if [[ "${#target_array[@]}" -eq 1 && -z "${target_array[0]}" ]]; then target_array=(); fi
}
