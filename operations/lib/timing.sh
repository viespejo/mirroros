#!/usr/bin/bash
# Diagnostic intervals only: no wall-clock fallback, subprocess, or lifecycle failure.
# Callers may override timing_clock_read in command-double tests, never through runtime input.
declare -gA TIMING_START=() TIMING_SUM=() TIMING_REASON=() TIMING_CLASS=() TIMING_SEEN=()
declare -ga TIMING_IDS=()
TIMING_LAST=''
TIMING_NOW=''
TIMING_CLOCK_REASON=''

timing_clock_read() {
  local uptime='' _idle=''
  TIMING_NOW=''
  TIMING_CLOCK_REASON=clock_unreadable
  if ! { read -r uptime _idle < /proc/uptime; } 2>/dev/null; then return 0; fi
  TIMING_CLOCK_REASON=clock_malformed
  # Bound arithmetic and reject anything other than the kernel's centisecond format.
  if [[ ! "$uptime" =~ ^([0-9]{1,12})\.([0-9]{2})$ ]]; then return 0; fi
  TIMING_NOW=$((10#${BASH_REMATCH[1]} * 1000 + 10#${BASH_REMATCH[2]} * 10))
  TIMING_CLOCK_REASON=''
}

timing_sample() {
  timing_clock_read
  if [[ -n "$TIMING_NOW" ]]; then
    if [[ -n "$TIMING_LAST" ]] && (( TIMING_NOW < TIMING_LAST )); then
      TIMING_NOW=''
      TIMING_CLOCK_REASON=clock_regressed
    else
      TIMING_LAST="$TIMING_NOW"
    fi
  fi
  return 0
}

timing_begin() {
  local id="$1" classification="${2:-}"
  if [[ -z "${TIMING_SEEN[$id]:-}" ]]; then
    TIMING_IDS+=("$id")
    TIMING_SEEN[$id]=1
    TIMING_SUM[$id]=0
    TIMING_CLASS[$id]="$classification"
  fi
  # Starting an already active interval does not reset it.
  [[ -z "${TIMING_START[$id]+present}" ]] || return 0
  timing_sample
  TIMING_START[$id]="$TIMING_NOW"
  if [[ -z "$TIMING_NOW" ]]; then TIMING_REASON[$id]="$TIMING_CLOCK_REASON"; fi
  return 0
}

timing_end() {
  local id="$1" start elapsed
  [[ -n "${TIMING_START[$id]+present}" ]] || return 0
  start="${TIMING_START[$id]}"
  timing_sample
  if [[ -z "$TIMING_NOW" ]]; then
    TIMING_REASON[$id]="$TIMING_CLOCK_REASON"
  elif [[ -n "$start" ]]; then
    elapsed=$((TIMING_NOW - start))
    if (( elapsed < 0 )); then
      TIMING_REASON[$id]=clock_regressed
    elif (( TIMING_SUM[$id] > 9007199254740990 - elapsed )); then
      TIMING_REASON[$id]=duration_overflow
    else
      TIMING_SUM[$id]=$((TIMING_SUM[$id] + elapsed))
    fi
  fi
  unset 'TIMING_START[$id]'
  return 0
}

timing_end_work() {
  local id index
  # Close inner work before its enclosing interval on handled termination.
  for (( index = ${#TIMING_IDS[@]} - 1; index >= 0; index-- )); do
    id="${TIMING_IDS[index]}"
    [[ "$id" == total ]] || timing_end "$id"
  done
  return 0
}

timing_end_all() {
  timing_end_work
  timing_end total
}

# Only fixed safe reason codes and caller-owned identifiers are serialized.
timing_value_json() {
  local id="$1"
  if [[ -n "${TIMING_REASON[$id]:-}" ]]; then
    printf '{"status":"unavailable","reason":"%s"}' "${TIMING_REASON[$id]}"
  else
    printf '{"status":"available","duration_ms":%s}' "${TIMING_SUM[$id]}"
  fi
}

timing_json() {
  local id separator=''
  printf '{"total":'
  timing_value_json total
  printf ',"intervals":['
  for id in "${TIMING_IDS[@]}"; do
    [[ "$id" != total ]] || continue
    printf '%s{"id":"%s"' "$separator" "$id"
    if [[ -n "${TIMING_CLASS[$id]}" ]]; then printf ',"classification":"%s"' "${TIMING_CLASS[$id]}"; fi
    printf ',"measurement":'
    timing_value_json "$id"
    printf '}'
    separator=,
  done
  printf ']}'
}
