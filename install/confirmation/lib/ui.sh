#!/usr/bin/bash
# shellcheck disable=SC2034 # Presentation state is read by the screen and flow libraries that source this file.
# Presentation layer of the guided live installer (ADR 0006, contracts/installation-confirmation.md).
#
# Reproduces the frozen reference in prototypes/frontend/guided-installer/: the two-tone logo, the Tokyo Night
# console palette, the centering, the Gum widget settings, and the step() screen. Presentation text and
# behavior adapted from omacom/omarchy-iso; see install/confirmation/UPSTREAM.md and docs/attribution.md.
# Nothing here plans, digests, or applies anything, and nothing sources the prototype or any Omarchy code.
#
# Gum only presents and collects input. Statuses follow Gum: 0 accepted, 1 Esc or decline, 130 Ctrl+C.

LOGO_PATH=''
LOGO_WIDTH=0
TERM_WIDTH=80
PADDING_LEFT=0
PADDING_LEFT_SPACES=''
LOGO_PADDING_LEFT=0
PADDING='0 0 0 0'

ui_interactive() {
  [[ -t 0 && -t 1 ]]
}

# The supported presentation is the colored interactive console of the live ISO. There is no colorless
# variant, and no variable or option fakes a terminal (ADR 0006). Exits 2 with a message and no side effects.
ui_terminal_gate() {
  if ! ui_interactive; then
    printf '%s\n' \
      'MirrorOS install: stdin or stdout is not an interactive terminal.' \
      'Next step: run mirroros-install from an interactive console; nothing was asked or changed.' >&2
    return 2
  fi
  if [[ -z "${TERM:-}" || "${TERM:-}" == dumb ]]; then
    printf '%s\n' \
      'MirrorOS install: the terminal type is unset or dumb, which is outside the supported colored live console.' \
      'Next step: run mirroros-install from a colored live console (for example TERM=linux); nothing was asked or changed.' >&2
    return 2
  fi
  if [[ -n "${NO_COLOR:-}" ]]; then
    printf '%s\n' \
      'MirrorOS install: NO_COLOR requests a colorless interface, which is outside the supported colored live console.' \
      'Next step: unset NO_COLOR and rerun mirroros-install; nothing was asked or changed.' >&2
    return 2
  fi
}

# Centers the logo and the guide as one block with a shared left edge.
measure_terminal() {
  TERM_WIDTH=$(stty size 2> /dev/null < /dev/tty | awk '{print $2}') || TERM_WIDTH=''
  [[ "$TERM_WIDTH" =~ ^[0-9]+$ ]] && (( TERM_WIDTH > 0 )) || TERM_WIDTH=${COLUMNS:-80}

  local guide_width=$LOGO_WIDTH
  if (( guide_width > TERM_WIDTH )); then guide_width=$TERM_WIDTH; fi
  PADDING_LEFT=$(((TERM_WIDTH - guide_width) / 2))
  PADDING_LEFT_SPACES=$(printf '%*s' "$PADDING_LEFT" '')
  LOGO_PADDING_LEFT=$PADDING_LEFT

  PADDING="0 0 0 $PADDING_LEFT"
  export GUM_CHOOSE_PADDING="$PADDING"
  export GUM_FILTER_PADDING="$PADDING"
  export GUM_INPUT_PADDING="$PADDING"
  export GUM_SPIN_PADDING="$PADDING"
  export GUM_TABLE_PADDING="$PADDING"
  export GUM_CONFIRM_PADDING="$PADDING"
}

clear_logo() {
  measure_terminal
  printf '\033[H\033[2J'
  local row white=$'\033[97m' blue=$'\033[34m'
  printf '\n\n'
  while IFS= read -r row || [[ -n $row ]]; do
    printf '%*s%s%s%s%s\033[0m\n' "$LOGO_PADDING_LEFT" '' "$blue" "${row:0:60}" "$white" "${row:60}"
  done < "$LOGO_PATH"
}

# One screen: the logo, a blank line, the title, and a blank line.
step() {
  clear_logo
  echo
  gum style --padding "0 0 0 $PADDING_LEFT" "$1"
  echo
}

# Sets up the colored presentation. Arguments: the directory that holds banner.txt.
ui_setup() {
  LOGO_PATH="$1/banner.txt"
  [[ -r "$LOGO_PATH" ]] || return 6
  LOGO_WIDTH=$(awk '{ if (length > max) max = length } END { print max+0 }' "$LOGO_PATH")
  export LOGO_PATH LOGO_WIDTH
  export GUM_CONFIRM_PROMPT_FOREGROUND=6
  export GUM_CONFIRM_SELECTED_FOREGROUND=0
  export GUM_CONFIRM_SELECTED_BACKGROUND=2
  export GUM_CONFIRM_UNSELECTED_FOREGROUND=7
  export GUM_CONFIRM_UNSELECTED_BACKGROUND=0
  export GUM_INPUT_PROMPT_FOREGROUND="${GUM_CHOOSE_HEADER_FOREGROUND:-99}"
  export GUM_INPUT_CURSOR_FOREGROUND="${GUM_CHOOSE_CURSOR_FOREGROUND:-212}"
  export CLICOLOR_FORCE=1 FORCE_COLOR=1
  COLUMNS=$(tput cols 2> /dev/null) || COLUMNS=80
  LINES=$(tput lines 2> /dev/null) || LINES=24
  export COLUMNS LINES
  measure_terminal
  # The Tokyo Night VT palette. It changes only a real virtual console.
  if [[ $(tty) == /dev/tty* ]]; then
    printf '\e]P01a1b26\e]P1f7768e\e]P29ece6a\e]P3e0af68\e]P47aa2f7\e]P5bb9af7\e]P67dcfff\e]P7a9b1d6'
    printf '\e]P8414868\e]P9f7768e\e]PA9ece6a\e]PBe0af68\e]PC7aa2f7\e]PDbb9af7\e]PE7dcfff\e]PFc0caf5\033[0m'
  fi
}

# The engine progress screen (D17). Arguments: operations completed, total, one-based position of the current
# operation, its plan description, and the package count (empty when none). The bar is the completed operations over
# the total; the package count never moves it.
ui_progress() {
  local completed=$1 total=$2 position=$3 description=$4 packages=$5
  local width=34 filled=0 bar empty
  if ((total > 0)); then filled=$((completed * width / total)); fi
  printf -v bar '%*s' "$filled" ''
  printf -v empty '%*s' "$((width - filled))" ''
  clear_logo
  echo
  gum style --padding "0 0 0 $PADDING_LEFT" 'Installing MirrorOS'
  echo
  printf '%s%s%s\n' "$PADDING_LEFT_SPACES" "${bar// /█}" "${empty// /░}"
  gum style --foreground 8 --padding "$PADDING" "[${position}/${total}] ${description}"
  if [[ -n $packages ]]; then gum style --foreground 8 --padding "$PADDING" "Packages installed: ${packages}"; fi
}

# The success screen (D18). Argument: the elapsed seconds of the engine phase.
ui_success() {
  local seconds=$1 duration
  if ((seconds >= 3600)); then
    duration="$((seconds / 3600))h $((seconds % 3600 / 60))m $((seconds % 60))s"
  elif ((seconds >= 60)); then
    duration="$((seconds / 60))m $((seconds % 60))s"
  else
    duration="${seconds}s"
  fi
  clear_logo
  echo
  gum style --padding "$PADDING" "Installed MirrorOS in ${duration}"
  gum style --foreground 8 --padding "$PADDING" 'Base system installed. Configuration checks passed before the first restart.'
  echo
}

# Word-wrap D19 and D20 only, splitting a word when it is wider than the available terminal space.
ui_wrapped_style() {
  local foreground=$1 text width=$((TERM_WIDTH - PADDING_LEFT - 1))
  shift
  ((width > 0)) || width=1
  for text in "$@"; do
    gum style --foreground "$foreground" --padding "$PADDING" "$(printf '%s\n' "$text" | fold -s -w "$width")"
  done
}

# The failure screen of an engine failure or interruption (D19). Arguments: failed operation, exit status, whether a
# destructive operation had started (true or false), the engine log, and the run directory. The log tail has no
# control characters and is wrapped to the terminal width.
ui_engine_failure() {
  local operation=$1 status=$2 destructive=$3 log=$4 run_directory=$5 line
  clear_logo
  echo
  ui_wrapped_style 1 'MirrorOS installation stopped'
  echo
  ui_wrapped_style 7 "Failed operation: ${operation:-unknown}" "Exit status: ${status}"
  if [[ $destructive == true ]]; then
    ui_wrapped_style 1 'The disk was partially modified and installation did not complete.'
  else
    ui_wrapped_style 7 'The disk was not modified.'
  fi
  echo
  while IFS= read -r line || [[ -n $line ]]; do
    ui_wrapped_style 7 "$line"
  done < <(tail -n 15 -- "$log" 2> /dev/null | LC_ALL=C sed -e 's/\x1b\[[0-9;?]*[ -\/]*[@-~]//g' | tr -cd '[:print:]\n')
  echo
  ui_wrapped_style 8 "Run directory: ${run_directory}"
}

# The unverified installation screen (D20). Results come only from the engine's validated record.
ui_not_verified() {
  local record=$1 run_directory=$2 id detail
  clear_logo
  echo
  ui_wrapped_style 1 'MirrorOS installation could not be verified'
  echo
  ui_wrapped_style 1 'Installation finished, but the installed system failed verification. Do not rely on it.'
  while IFS=$'\t' read -r id detail; do
    ui_wrapped_style 7 "Failed check: ${id}" "$detail"
  done < <(node --input-type=module - "$record" <<'NODE'
import { readFileSync } from 'node:fs';
const run = JSON.parse(readFileSync(process.argv[2], 'utf8'));
for (const check of run.postconditions.checks.filter(item => item.status === 'failed')) {
  process.stdout.write(`${check.id}\t${check.detail}\n`);
}
NODE
  )
  echo
  ui_wrapped_style 8 'The disk was modified. The full result is in the run directory.' "Run directory: ${run_directory}"
}

# A failed phase is reported with its phase, cause, and next action. Arguments: phase, cause, next action.
ui_failure() {
  gum style --foreground 1 --padding "$PADDING" "Phase: $1" "Cause: $2" "Next: $3"
}
