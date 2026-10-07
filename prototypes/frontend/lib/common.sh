#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared across the frontend libraries sourced by run.
# Frontend contract check: pty driver, output detectors, and the attended verdict prompt.
# Non-production. Automated points drive the scenarios through script(1) so that Gum sees a real
# terminal; keys are fed through the pty and never as arguments of an external command.

FE_PTY_SETTLE=1
FE_PTY_STEP=0.8
FE_PTY_TAIL=1.5
FE_PTY_TIMEOUT=40
FE_PTY_COLUMNS=100
FE_PTY_ROWS=30

# Arguments: typescript path, environment words, command string, then the keys to send.
# Keys are printf %b strings sent one at a time. The colored profile is the default, so an ambient
# NO_COLOR is removed first. The returned status is the one of the command run in the pty.
fe_pty_run() {
  local typescript="$1"
  local env_words="$2"
  local command="$3"
  local key
  local -a env_args=()

  shift 3
  read -r -a env_args <<< "$env_words"
  {
    sleep "$FE_PTY_SETTLE"
    for key in "$@"; do
      printf '%b' "$key"
      sleep "$FE_PTY_STEP"
    done
    sleep "$FE_PTY_TAIL"
  } | env -u NO_COLOR "${env_args[@]}" timeout "$FE_PTY_TIMEOUT" \
    script -qefc "stty cols ${FE_PTY_COLUMNS} rows ${FE_PTY_ROWS}; ${command}" "$typescript" > /dev/null
  return "${PIPESTATUS[1]}"
}

# Prints the value of a KEY=value marker that a scenario wrote into a transcript.
fe_marker() {
  tr -d '\r' < "$1" | grep -ao "${2}=[0-9A-Za-z]*" | tail -n 1 | cut -d= -f2
}

# Succeeds when the fixed text occurs in the file.
fe_has() {
  grep -aqF -- "$2" "$1"
}

# Counts lines that carry at least one SGR color sequence (foreground, background, or extended).
# Bold, underline, and reset are not colors.
fe_color_count() {
  tr -d '\r' < "$1" | LC_ALL=C grep -acP '\x1b\[(?:[0-9;:]*[;:])?(?:3[0-9]|4[0-9]|9[0-7]|10[0-7])(?:[;:][0-9;:]*)?m' || true
}

# Prints yes, no, or unknown: whether the line of the Yes/No buttons of gum confirm carries any SGR
# sequence, which is the only way Gum shows which button has the focus.
fe_native_focus_cue() {
  local line

  line="$(tr -d '\r' < "$1" | grep -aE '^ *Yes +No' | head -n 1)"
  if [[ -z "$line" ]]; then
    printf 'unknown'
  elif [[ "$line" == *$'\033'* ]]; then
    printf 'yes'
  else
    printf 'no'
  fi
}

FE_SAMPLER_PID=''

# Samples the command line of every process into a file until fe_sampler_stop.
fe_sampler_start() {
  local samples="$1"

  (
    while :; do
      ps -eo args= >> "$samples" 2> /dev/null
      sleep 0.2
    done
  ) &
  FE_SAMPLER_PID=$!
}

fe_sampler_stop() {
  [[ -n "$FE_SAMPLER_PID" ]] || return 0
  kill "$FE_SAMPLER_PID" 2> /dev/null
  wait "$FE_SAMPLER_PID" 2> /dev/null
  FE_SAMPLER_PID=''
}

FE_VERDICT=''
FE_NOTE=''

# Asks the maintainer for a verdict and a short note through plain read, not through Gum.
fe_ask_verdict() {
  local label="$1"
  local answer

  FE_VERDICT=''
  while :; do
    read -r -p "${label} verdict [pass/fail]: " answer || return 1
    case "$answer" in
      pass | fail)
        FE_VERDICT="$answer"
        break
        ;;
    esac
    printf '%s\n' 'Answer pass or fail.'
  done
  read -r -p 'Short note (optional, plain text): ' FE_NOTE || FE_NOTE=''
  FE_NOTE="$(printf '%s' "$FE_NOTE" | tr -cd '[:print:]' | cut -c1-200)"
}
