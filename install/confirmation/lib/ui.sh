#!/usr/bin/bash
# shellcheck disable=SC2034 # Presentation state is read by the screen and flow libraries that source this file.
# Presentation layer of the guided live installer (ADR 0006, contracts/installation-confirmation.md).
#
# Uses the MirrorOS visual baseline of ADR 0018. Screen text and behavior were adapted from
# omacom/omarchy-iso; see install/confirmation/UPSTREAM.md and docs/attribution.md.
# The frozen reference remains unchanged; runtime never sources it.
# Nothing here plans, digests, or applies anything, and nothing sources the prototype or any Omarchy code.
#
# Gum only presents and collects input. Statuses follow Gum: 0 accepted, 1 Esc or decline, 130 Ctrl+C.

LOGO_PATH=''
LOGO_WIDTH=0
TERM_WIDTH=80
TERM_HEIGHT=25
UI_FONT_CONSOLE=''
UI_ORIGINAL_FONT=''
UI_TEXT_SIZE='Original'
UI_PROGRESS_LAYOUT=''
UI_SUCCESS_PADDING='0 0 0 0'
UI_DIAGNOSTIC_FILE=''
UI_DIAGNOSTIC_PAGED=false
UI_DIAGNOSTIC_LOGO=false
UI_DIAGNOSTIC_REQUIRED_ROWS=0
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

# Centers the symbol on the screen and the 80-column guide independently.
measure_terminal() {
  TERM_WIDTH=$(stty size 2> /dev/null < /dev/tty | awk '{print $2}') || TERM_WIDTH=''
  [[ "$TERM_WIDTH" =~ ^[0-9]+$ ]] && (( TERM_WIDTH > 0 )) || TERM_WIDTH=${COLUMNS:-80}

  TERM_HEIGHT=$(stty size 2> /dev/null < /dev/tty | awk '{print $1}') || TERM_HEIGHT=''
  [[ "$TERM_HEIGHT" =~ ^[0-9]+$ ]] && (( TERM_HEIGHT > 0 )) || TERM_HEIGHT=${LINES:-25}
  COLUMNS=$TERM_WIDTH LINES=$TERM_HEIGHT
  export COLUMNS LINES

  local guide_width=80
  if (( guide_width > TERM_WIDTH )); then guide_width=$TERM_WIDTH; fi
  PADDING_LEFT=$(((TERM_WIDTH - guide_width) / 2))
  PADDING_LEFT_SPACES=$(printf '%*s' "$PADDING_LEFT" '')
  LOGO_PADDING_LEFT=$(((TERM_WIDTH - LOGO_WIDTH) / 2))
  (( LOGO_PADDING_LEFT >= 0 )) || LOGO_PADDING_LEFT=0

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
  if [[ -n $UI_PROGRESS_LAYOUT ]]; then
    printf '\033[?25h'
    UI_PROGRESS_LAYOUT=''
  fi
  printf '\033[H\033[2J'
  local row
  printf '\033[0m\033[37m\n\n'
  if [[ ${1:-} == compact ]]; then return 0; fi
  while IFS= read -r row || [[ -n $row ]]; do
    printf '%*s%s\n' "$LOGO_PADDING_LEFT" '' "$row"
  done < "$LOGO_PATH"
}

# Individually reviewed screens use a two-line symbol gap; other screens await review.
step() {
  measure_terminal
  if [[ $1 == 'Review your choices' ]]; then
    clear_logo compact
  elif [[ $1 == 'Welcome to MirrorOS' || $1 == 'Installation text size' || $1 == 'Connect to the internet' || $1 == 'Connect with Ethernet' || $1 == 'Connect with Wi-Fi' || $1 == 'Waiting for the system clock' || $1 == 'Preparing the package keyring' || $1 == 'Package keyring not ready' || $1 == 'Machine check' || $1 == 'Choose installation disk' || $1 == 'Choose storage layout' || $1 == 'Choose hibernation' || $1 == 'Choose swapfile size' || $1 == 'Select your timezone' || $1 == 'Choose system language' || $1 == 'Choose regional formats' || $1 == 'Choose installed console keyboard' || $1 == 'Name your machine' || $1 == "Let's setup your user account..." || $1 == 'Choose root account policy' || $1 == 'Confirm installation' || $1 == 'Password' ]]; then
    if (( TERM_HEIGHT < 32 )); then
      clear_logo compact
    else
      clear_logo
      printf '\n\n'
    fi
  else
    clear_logo
    echo
  fi
  gum style --padding "0 0 0 $PADDING_LEFT" "$1"
  echo
}

# Review warnings wrap within the form and preserve continuation alignment.
ui_warning_block() {
  local text width=80 available=$((TERM_WIDTH - PADDING_LEFT - 1))
  if ((width > available)); then width=$available; fi
  if ((width < 1)); then width=1; fi
  for text in "$@"; do
    gum style --foreground 3 --padding "$PADDING" "$(printf '%s\n' "$text" | fold -s -w "$width")"
  done
}

# Pin the approved selector style and omit Gum's generic header.
ui_choose() {
  if ui_interactive; then printf '\033[0m\033[37m' > /dev/tty; fi
  gum choose --header '' --cursor '› ' --cursor.foreground 4 --cursor.background 0 \
    --selected.foreground 4 --selected.background 0 --item.foreground 7 "$@"
}

# Capture only a real Linux VT; pseudo-terminals cannot change a console font.
ui_save_font() {
  UI_FONT_CONSOLE=$(tty) || return 2
  if [[ ! $UI_FONT_CONSOLE =~ ^/dev/tty[0-9]+$ ]]; then
    UI_FONT_CONSOLE=''
    return 0
  fi
  command -v setfont > /dev/null || { printf 'setfont is required to save the live console font.\n' >&2; return 2; }
  local saved="${FLOW_TMP}/original-font.psf"
  if ! setfont -C "$UI_FONT_CONSOLE" -O "$saved"; then
    printf 'Could not save the live console font. No installation was run.\n' >&2
    return 5
  fi
  UI_ORIGINAL_FONT=$saved
}

ui_apply_text_size() {
  local size=$1
  local -a arguments=()
  case $size in
    Original) ;;
    'Original x2') arguments=(-d) ;;
    *) return 6 ;;
  esac
  if [[ -z $UI_ORIGINAL_FONT || ! -r $UI_ORIGINAL_FONT ]]; then
    printf 'Text size can only be changed on the live virtual console with a saved original font.\n' >&2
    return 2
  fi
  if ! setfont -C "$UI_FONT_CONSOLE" "${arguments[@]}" "$UI_ORIGINAL_FONT"; then
    printf 'Could not change the live console font. No installation was run.\n' >&2
    return 5
  fi
  UI_TEXT_SIZE=$size
  measure_terminal
}

# Called before flow cleanup removes the private saved font, on every handled exit.
ui_cleanup() {
  if [[ -n $UI_ORIGINAL_FONT ]]; then
    if ! setfont -C "$UI_FONT_CONSOLE" "$UI_ORIGINAL_FONT"; then
      printf 'Could not restore the saved console font. Reboot the live medium to restore its font.\n' >&2
    fi
  fi
  if [[ -n $UI_FONT_CONSOLE ]]; then printf '\033[0m\033]R\033[?25h'; fi
}

# Sets up the colored presentation. Arguments: the directory that holds symbol.txt.
ui_setup() {
  LOGO_PATH="$1/symbol.txt"
  [[ -r "$LOGO_PATH" ]] || return 6
  LOGO_WIDTH=$(awk '{ if (length > max) max = length } END { print max+0 }' "$LOGO_PATH")
  export LOGO_PATH LOGO_WIDTH
  export GUM_CONFIRM_PROMPT_FOREGROUND=6
  export GUM_CONFIRM_SELECTED_FOREGROUND=0
  export GUM_CONFIRM_SELECTED_BACKGROUND=2
  export GUM_CONFIRM_UNSELECTED_FOREGROUND=7
  export GUM_CONFIRM_UNSELECTED_BACKGROUND=0
  export GUM_CHOOSE_CURSOR='› '
  export GUM_CHOOSE_CURSOR_FOREGROUND=4 GUM_CHOOSE_CURSOR_BACKGROUND=0
  export GUM_CHOOSE_SELECTED_FOREGROUND=4 GUM_CHOOSE_SELECTED_BACKGROUND=0
  export GUM_CHOOSE_ITEM_FOREGROUND=7
  export GUM_INPUT_PROMPT_FOREGROUND=7
  export GUM_INPUT_CURSOR_FOREGROUND=4
  export CLICOLOR_FORCE=1 FORCE_COLOR=1 COLORTERM=yes
  COLUMNS=$(tput cols 2> /dev/null) || COLUMNS=80
  LINES=$(tput lines 2> /dev/null) || LINES=24
  export COLUMNS LINES
  measure_terminal
  ui_save_font || return $?
  # The MirrorOS VT palette. Keep the remaining slots for screens awaiting individual review.
  if [[ -n $UI_FONT_CONSOLE ]]; then
    printf '\e]P0101315\e]P1a55555\e]P29ece6a\e]P3e0af68\e]P48fafc1\e]P5bb9af7\e]P67dcfff\e]P7cacccc'
    printf '\e]P88c9698\e]P9a55555\e]PA9ece6a\e]PBe0af68\e]PC8fafc1\e]PDbb9af7\e]PE7dcfff\e]PFcacccc\033[0m\033[37m'
  fi
}

# The engine progress screen (D17). Arguments: operations completed, total, one-based position of the current
# operation, its description, and the package count or configure step (empty when none). The bar is the completed
# operations over the total; the detail never moves it.
ui_progress() {
  local completed=$1 total=$2 position=$3 description=$4 packages=$5
  local width=34 filled=0 bar empty row text detail='' logo_height=0 height top dynamic key
  local -a status_lines=() detail_lines=()
  measure_terminal
  if ((width > TERM_WIDTH)); then width=$TERM_WIDTH; fi
  if ((total > 0)); then filled=$((completed * width / total)); fi
  printf -v bar '%*s' "$filled" ''
  printf -v empty '%*s' "$((width - filled))" ''
  if [[ $packages == 'Configure step:' || $packages == 'Configure step: '* ]]; then
    detail=$packages
  elif [[ -n $packages ]]; then
    detail="Packages installed: ${packages}"
  fi
  mapfile -t status_lines < <(printf '[%s/%s] %s\n' "$position" "$total" "$description" | fold -s -w "$TERM_WIDTH")
  if [[ -n $detail ]]; then
    mapfile -t detail_lines < <(printf '%s\n' "$detail" | fold -s -w "$TERM_WIDTH")
  fi
  if ((TERM_HEIGHT >= 32)); then logo_height=$(wc -l < "$LOGO_PATH"); fi
  height=$((4 + ${#status_lines[@]} + ${#detail_lines[@]}))
  if ((logo_height > 0)); then height=$((height + logo_height + 1)); fi
  top=$(((TERM_HEIGHT - height) / 2 + 1))
  if ((top < 1)); then top=1; fi
  dynamic=$top
  if ((logo_height > 0)); then dynamic=$((top + logo_height + 1)); fi
  key="$TERM_WIDTH:$TERM_HEIGHT:$height:$logo_height"
  if [[ $UI_PROGRESS_LAYOUT != "$key" ]]; then
    printf '\033[0m\033[37m\033[?25l\033[H\033[2J\033[%s;1H' "$top"
    if ((logo_height > 0)); then
      while IFS= read -r row || [[ -n $row ]]; do
        printf '%*s%s\n' "$LOGO_PADDING_LEFT" '' "$row"
      done < "$LOGO_PATH"
    fi
    UI_PROGRESS_LAYOUT=$key
  fi
  printf '\033[%s;1H\033[J\033[37m' "$dynamic"
  text='Installing MirrorOS'
  printf '%*s%s\n\n' "$(((TERM_WIDTH - ${#text}) / 2))" '' "$text"
  printf '%*s\033[37m%s\033[90m%s\033[0m\n\n' "$(((TERM_WIDTH - width) / 2))" '' "${bar// /█}" "${empty// /░}"
  for text in "${status_lines[@]}" "${detail_lines[@]}"; do
    printf '%*s\033[90m%s\033[0m\n' "$(((TERM_WIDTH - ${#text}) / 2))" '' "$text"
  done
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
  local text row logo_height=0 height top padding title_width=0
  local -a title_lines=()
  measure_terminal
  mapfile -t title_lines < <(printf 'Installed MirrorOS in %s\n' "$duration" | fold -s -w "$TERM_WIDTH")
  for text in "${title_lines[@]}"; do
    if ((${#text} > title_width)); then title_width=${#text}; fi
  done
  UI_SUCCESS_PADDING="0 0 0 $(((TERM_WIDTH - title_width) / 2))"
  if ((TERM_HEIGHT >= 32)); then logo_height=$(wc -l < "$LOGO_PATH"); fi
  height=$((5 + ${#title_lines[@]}))
  if ((logo_height > 0)); then height=$((height + logo_height + 2)); fi
  top=$(((TERM_HEIGHT - height) / 2 + 1))
  if ((top < 1)); then top=1; fi
  clear_logo compact
  printf '\033[%s;1H' "$top"
  if ((logo_height > 0)); then
    while IFS= read -r row || [[ -n $row ]]; do
      printf '%*s%s\n' "$LOGO_PADDING_LEFT" '' "$row"
    done < "$LOGO_PATH"
    printf '\n\n'
  fi
  for text in "${title_lines[@]}"; do
    padding=$(((TERM_WIDTH - ${#text}) / 2))
    printf '%*s%s\n' "$padding" '' "$text"
  done
  echo
}

# Word-wrap diagnostic text, splitting words wider than the available space.
# An optional --width limit caps only the individually reviewed caller's form.
ui_wrapped_style() {
  local foreground=$1 text width=$((TERM_WIDTH - PADDING_LEFT - 1))
  shift
  if [[ ${1:-} == --width ]]; then
    if ((width > $2)); then width=$2; fi
    shift 2
  fi
  ((width > 0)) || width=1
  for text in "$@"; do
    gum style --foreground "$foreground" --padding "$PADDING" "$(printf '%s\n' "$text" | fold -s -w "$width")"
  done
}

# Measure the complete diagnostic, including native menu/help space or terminal evidence output.
# Rendering is private and transient; neither inspection nor this file changes the lifecycle outcome.
ui_diagnostic_select_layout() {
  local menu_rows=$1 run_directory=$2 reserve=2
  shift 2
  measure_terminal
  UI_DIAGNOSTIC_PAGED=false
  UI_DIAGNOSTIC_LOGO=false
  UI_DIAGNOSTIC_FILE="${FLOW_TMP}/diagnostic.txt"
  (
    # Preserve wrapping while removing console-clearing sequences and outer centering from the pager.
    # shellcheck disable=SC2329 # Invoked indirectly by the diagnostic renderer below.
    clear_logo() {
      measure_terminal
      PADDING_LEFT=0 PADDING='0 0 0 0'
      printf '\n\n'
    }
    "$@" || exit 6
    if ((menu_rows == 0)); then
      echo
      ui_wrapped_style 8 --width 80 "Evidence: $run_directory"
    fi
  ) > "$UI_DIAGNOSTIC_FILE" || return 6
  if ((menu_rows > 0)); then reserve=$((menu_rows + 4)); fi
  UI_DIAGNOSTIC_REQUIRED_ROWS=$(($(wc -l < "$UI_DIAGNOSTIC_FILE") + reserve))
  if ((UI_DIAGNOSTIC_REQUIRED_ROWS > TERM_HEIGHT)); then
    UI_DIAGNOSTIC_PAGED=true
  else
    ui_diagnostic_select_logo "$UI_DIAGNOSTIC_REQUIRED_ROWS"
  fi
}

ui_diagnostic_select_logo() {
  local rows=$1 logo_rows
  UI_DIAGNOSTIC_LOGO=false
  if ((TERM_HEIGHT < 32)); then return 0; fi
  logo_rows=$(wc -l < "$LOGO_PATH") || return 6
  if ((rows + logo_rows + 2 <= TERM_HEIGHT)); then UI_DIAGNOSTIC_LOGO=true; fi
}

# The post-inspection summary has its own height budget, including the extra inspection choice.
ui_diagnostic_select_summary() {
  local menu_rows=$1 run_directory=$2 reserve=2 file="${FLOW_TMP}/diagnostic-summary.txt"
  shift 2
  UI_DIAGNOSTIC_LOGO=false
  measure_terminal
  (
    # shellcheck disable=SC2329 # Invoked indirectly by the summary renderer below.
    clear_logo() {
      measure_terminal
      PADDING_LEFT=0 PADDING='0 0 0 0'
      printf '\n\n'
    }
    "$@" || exit 6
    if ((menu_rows == 0)); then
      echo
      ui_wrapped_style 8 --width 80 "Evidence: $run_directory"
    fi
  ) > "$file" || return 6
  if ((menu_rows > 0)); then reserve=$((menu_rows + 4)); fi
  ui_diagnostic_select_logo "$(($(wc -l < "$file") + reserve))"
}

ui_diagnostic_clear() {
  if [[ $UI_DIAGNOSTIC_LOGO == true ]]; then
    clear_logo
    printf '\n\n'
  else
    clear_logo compact
  fi
}

ui_diagnostic_pager() {
  local status=0
  gum pager --border-foreground 4 < "$UI_DIAGNOSTIC_FILE" || status=$?
  case $status in
    0 | 1) return 0 ;;
    *) return "$status" ;;
  esac
}

ui_engine_failure_summary() {
  ui_diagnostic_clear
  ui_wrapped_style 1 --width 80 'MirrorOS installation stopped'
  echo
  ui_wrapped_style 7 --width 80 "Failed operation: ${1:-unknown}" "Exit status: $2"
  echo
  if [[ $3 == true ]]; then
    ui_wrapped_style 1 --width 80 'The disk was partially modified and installation did not complete.'
  else
    ui_wrapped_style 7 --width 80 'The disk was not modified.'
  fi
}

ui_not_verified_summary() {
  ui_diagnostic_clear
  ui_wrapped_style 1 --width 80 'MirrorOS installation could not be verified'
  echo
  ui_wrapped_style 1 --width 80 'Installation finished, but the installed system failed verification. Do not rely on it.'
  echo
  ui_wrapped_style 8 --width 80 'The disk was modified. The full result is in the run directory.'
}

ui_not_configured_summary() {
  ui_diagnostic_clear
  ui_wrapped_style 1 --width 80 "Base system installed and verified; environment configuration failed at step ${1:-unknown}."
  echo
  ui_wrapped_style 7 --width 80 'Boot the installed system, log in at the console, and run sudo mirroros-configure.'
}

ui_failure_summary() {
  ui_diagnostic_clear
  ui_wrapped_style 1 --width 80 "Phase: $1"
  echo
  ui_wrapped_style 1 --width 80 "Next: $2"
}

# The failure screen of an engine failure or interruption (D19). Arguments: failed operation, exit status, whether a
# destructive operation had started (true or false), the engine log, and the run directory. The log tail has no
# control characters and is wrapped to the terminal width.
ui_engine_failure() {
  local operation=$1 status=$2 destructive=$3 log=$4 run_directory=$5 line
  ui_diagnostic_clear
  ui_wrapped_style 1 --width 80 'MirrorOS installation stopped'
  echo
  ui_wrapped_style 7 --width 80 "Failed operation: ${operation:-unknown}" "Exit status: ${status}"
  echo
  if [[ $destructive == true ]]; then
    ui_wrapped_style 1 --width 80 'The disk was partially modified and installation did not complete.'
  else
    ui_wrapped_style 7 --width 80 'The disk was not modified.'
  fi
  echo
  while IFS= read -r line || [[ -n $line ]]; do
    ui_wrapped_style 7 --width 80 "$line"
  done < <(tail -n 15 -- "$log" 2> /dev/null | LC_ALL=C sed -e 's/\x1b\[[0-9;?]*[ -\/]*[@-~]//g' | tr -cd '[:print:]\n')
  echo
  ui_wrapped_style 8 --width 80 "Run directory: ${run_directory}"
}

# The unverified installation screen (D20). Results come only from the engine's validated record.
ui_not_verified() {
  local record=$1 run_directory=$2 id detail
  ui_diagnostic_clear
  ui_wrapped_style 1 --width 80 'MirrorOS installation could not be verified'
  echo
  ui_wrapped_style 1 --width 80 'Installation finished, but the installed system failed verification. Do not rely on it.'
  echo
  while IFS=$'\t' read -r id detail; do
    ui_wrapped_style 7 --width 80 "Failed check: ${id}" "$detail"
    echo
  done < <(node --input-type=module - "$record" <<'NODE'
import { readFileSync } from 'node:fs';
const run = JSON.parse(readFileSync(process.argv[2], 'utf8'));
for (const check of run.postconditions.checks.filter(item => item.status === 'failed')) {
  process.stdout.write(`${check.id}\t${check.detail}\n`);
}
NODE
  )
  ui_wrapped_style 8 --width 80 'The disk was modified. The full result is in the run directory.' "Run directory: ${run_directory}"
}

# The unconfigured environment screen (D22). Arguments: failed configure step and run directory.
ui_not_configured() {
  local step=$1 run_directory=$2
  ui_diagnostic_clear
  ui_wrapped_style 1 --width 80 "Base system installed and verified; environment configuration failed at step ${step:-unknown}."
  echo
  ui_wrapped_style 7 --width 80 'Boot the installed system, log in at the console, and run sudo mirroros-configure.'
  echo
  ui_wrapped_style 8 --width 80 "Run directory: ${run_directory}"
}

# The engine ended without a valid record. Arguments: exit status and run directory.
ui_engine_record_failure() {
  local status=$1 run_directory=$2
  ui_diagnostic_clear
  ui_wrapped_style 1 --width 80 'Phase: Installation engine'
  echo
  ui_wrapped_style 1 --width 80 "Cause: The engine ended with status ${status} and left no valid record."
  echo
  ui_wrapped_style 1 --width 80 "Next: Check install.log and engine/ in ${run_directory}."
}

# A failed phase is reported with its phase, cause, and next action. Arguments: phase, cause, next action.
ui_failure() {
  ui_diagnostic_clear
  ui_wrapped_style 1 --width 80 "Phase: $1"
  echo
  ui_wrapped_style 1 --width 80 "Cause: $2"
  echo
  ui_wrapped_style 1 --width 80 "Next: $3"
}
