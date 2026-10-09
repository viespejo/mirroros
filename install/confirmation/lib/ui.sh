#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are read by the flow library that sources this file.
# Gum presentation layer of the interactive installation flow (ADR 0004).
#
# Gum only presents and collects input here; nothing in this file plans, digests, or applies anything.
# Each ui_* wrapper is a named adaptation of native Gum behavior recorded in ADR 0004. Confirmations
# never default to yes. Styling uses the grayscale palette of the frontend contract check: titles and
# selection 255, accents 250, explanatory text 248, borders and idle items 245; no hue.
#
# Statuses follow the normalized exit statuses. Ctrl+C (Gum status 130) is returned unmapped by the
# wrappers; the orchestrator maps it to cancellation only inside the interactive phase.

UI_ACTION=''
UI_VALUE=''
UI_NATIVE_STATUS=''

ui_interactive() {
  [[ -t 0 && -t 1 ]]
}

# NO_COLOR (non-empty) and TERM=dumb select the colorless profile.
ui_colorless() {
  [[ -n "${NO_COLOR:-}" || "${TERM:-}" == dumb ]]
}

# Wrapper tty_precheck: native gum confirm and gum choose return 1 without a terminal, which looks like
# a decline. A missing terminal fails with 2 before anything is asked.
ui_tty_precheck() {
  if ! ui_interactive; then
    printf '%s\n' \
      'MirrorOS install apply: stdin or stdout is not an interactive terminal.' \
      'Next step: run apply from an interactive terminal; nothing was confirmed.' >&2
    return 2
  fi
}

# Wrapper tty_gate: styled decoration exists only with an interactive terminal.
ui_tty_gate() {
  ui_interactive
}

# Wrapper confirm_status_map: native gum confirm returns 1 for both a decline and Esc. Both map to 3.
# The Ctrl+C status is returned unmapped.
ui_confirm_status_map() {
  case "$1" in
    0) return 0 ;;
    1) return 3 ;;
    130) return 130 ;;
    *) return 5 ;;
  esac
}

# Wrapper colorless_confirm: with NO_COLOR or TERM=dumb, gum confirm shows no cue for the focused
# button. The confirmation is asked with gum choose, whose cursor is the text "> ", and the safe answer
# is first. The native status is left in UI_NATIVE_STATUS.
ui_colorless_confirm() {
  local prompt="$1"
  local answer
  local status=0

  answer="$(gum choose --header "$prompt" --cursor '> ' 'No, cancel' 'Yes, apply')" || status=$?
  if [[ "$status" -eq 0 && "$answer" != 'Yes, apply' ]]; then
    status=1
  fi
  UI_NATIVE_STATUS=$status
}

# Wrapper spin_plain_fallback: without an interactive terminal a stage is announced as plain text and
# run directly.
ui_spin_plain_fallback() {
  local title="$1"
  local status=0

  shift
  printf 'Stage: %s\n' "$title"
  "$@" > /dev/null || status=$?
  return "$status"
}

# Wrapper stage_status_normalization: an unexpected status of a stage is reported with its stage, reason,
# and next action, and normalized to 5. The original status is shown.
ui_stage_status_normalization() {
  local title="$1"
  local original="$2"
  local next_action="$3"

  printf '%s\n' \
    "Stage failed: ${title}" \
    "Reason: the operation exited with status ${original} (normalized to 5)." \
    "Next action: ${next_action}" >&2
  return 5
}

# Maps the status of a Gum prompt for one phase (menu, edit, confirm, name) to UI_ACTION. Gum returns 1
# for decline and Esc, and 130 for Ctrl+C. Esc inside an edit widget goes back to the dashboard; every
# other decline or Esc cancels.
ui_map_status() {
  case "$1" in
    0) UI_ACTION=proceed ;;
    130) UI_ACTION=cancel ;;
    1)
      if [[ "$2" == edit ]]; then
        UI_ACTION=back
      else
        UI_ACTION=cancel
      fi
      ;;
    *) UI_ACTION=fail ;;
  esac
}

ui_header() {
  ui_tty_gate || return 0
  gum style --border rounded --border-foreground 245 --bold --padding '0 2' 'MirrorOS installation'
}

ui_note() {
  gum style --foreground 248 "$1"
}

# Renders Markdown with the project grayscale glamour style.
ui_format() {
  gum format --theme "$1"
}

# Arguments: header, then the items. Leaves the selection in UI_VALUE and returns the Gum status.
ui_choose() {
  local header="$1"
  local status=0

  shift
  UI_VALUE="$(gum choose --cursor '> ' --header.foreground 255 --cursor.foreground 255 \
    --selected.foreground 255 --item.foreground 245 --header "$header" "$@")" || status=$?
  return "$status"
}

# Arguments: header, the newline-separated list, then extra Gum options (for example --no-limit).
ui_filter() {
  local header="$1"
  local list="$2"
  local status=0

  shift 2
  UI_VALUE="$(gum filter --header "$header" --header.foreground 255 --indicator.foreground 255 \
    --match.foreground 255 --prompt.foreground 250 --text.foreground 248 \
    --placeholder 'Type to filter...' --placeholder.foreground 245 "$@" <<< "$list")" || status=$?
  return "$status"
}

# Arguments: header, placeholder. Never used for secrets: no password input exists in this flow.
ui_input() {
  local status=0

  UI_VALUE="$(gum input --header "$1" --placeholder "$2" --header.foreground 255 \
    --prompt.foreground 250 --cursor.foreground 255 --placeholder.foreground 245)" || status=$?
  return "$status"
}

# Arguments: prompt. Returns 0 yes, 3 decline or Esc, 2 without an interactive terminal, 130 unmapped.
ui_confirm() {
  local prompt="$1"
  local native=0

  UI_NATIVE_STATUS=''
  ui_tty_precheck || return 2
  if ui_colorless; then
    ui_colorless_confirm "$prompt"
    native=$UI_NATIVE_STATUS
  else
    gum confirm --default=false --affirmative 'Yes, apply' --negative 'No, cancel' \
      --prompt.foreground 248 --selected.foreground 0 --selected.background 255 \
      --unselected.foreground 250 --unselected.background 236 "$prompt" || native=$?
    UI_NATIVE_STATUS=$native
  fi
  ui_confirm_status_map "$native"
}
