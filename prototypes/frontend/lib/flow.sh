#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are read by the scenarios and the contract points.
# shellcheck disable=SC2016 # Literal backticks and dollars appear only inside quoted messages.
# Frontend contract check: the Gum presentation flow under test. Non-production.
#
# Gum only presents and collects input. Nothing here plans, digests, or applies anything.
# Each wrapper_* function is a named adaptation of native Gum behavior. The contract points report
# which wrappers a point needs, because each reported wrapper becomes a binding constraint of
# ADR 0004. Confirmations never default to yes.
#
# Statuses follow the normalized exit statuses: 0 success, 2 invalid input or unmet precondition,
# 3 explicit cancellation, 5 execution failure (the original status is recorded). The Ctrl+C status
# of Gum (130) is passed through without mapping; its mapping is left to Story 2.4.

FLOW_HEADER_TEXT='MirrorOS interactive session (mock)'
FLOW_BANNER_FILE="${BASH_SOURCE[0]%/*}/banner.txt"
FLOW_LOG="${FLOW_LOG:-}"
FLOW_NONINTERACTIVE=0
FLOW_NATIVE_STATUS=''
FLOW_ORIGINAL_STATUS=''

flow_interactive() {
  [[ -t 0 && -t 1 ]]
}

# NO_COLOR (non-empty) and TERM=dumb select the colorless profile.
flow_colorless() {
  [[ -n "${NO_COLOR:-}" || "${TERM:-}" == dumb ]]
}

# Appends one plain-text line to the persistent log. Styled output is never written here.
flow_log() {
  [[ -n "$FLOW_LOG" ]] || return 0
  printf '%s\n' "$*" >> "$FLOW_LOG"
}

# Generic non-interactive flags exist to prove that none of them bypasses a confirmation.
flow_parse_flags() {
  local argument

  for argument in "$@"; do
    case "$argument" in
      --yes | --non-interactive | --assume-yes) FLOW_NONINTERACTIVE=1 ;;
      *)
        printf 'Invalid option: %s\n' "$argument" >&2
        return 2
        ;;
    esac
  done
}

# Wrapper: a confirmation or secret prompt without an interactive terminal fails with 2.
# Native gum confirm and gum choose return 1 and gum spin silently runs the command.
wrapper_tty_precheck() {
  if ! flow_interactive; then
    printf '%s\n' \
      'Confirmation failed: stdin or stdout is not an interactive terminal.' \
      'Next action: run this command from an interactive terminal; nothing was confirmed.' >&2
    return 2
  fi
}

# Wrapper: the styled header exists only with an interactive terminal and never in non-interactive mode.
wrapper_tty_gate() {
  flow_interactive && [[ "$FLOW_NONINTERACTIVE" -eq 0 ]]
}

# Wrapper: native gum confirm returns 1 for both a decline and Esc. Both map to 3. The Ctrl+C
# status is returned unmapped.
wrapper_confirm_status_map() {
  case "$1" in
    0) return 0 ;;
    1) return 3 ;;
    130) return 130 ;;
    *)
      flow_log "confirm: unexpected upstream status ${1}"
      return 5
      ;;
  esac
}

# Wrapper: with NO_COLOR or TERM=dumb, gum confirm shows no cue for the focused button. The
# confirmation is asked with gum choose, whose cursor is the text "> ", and the safe answer is first.
wrapper_colorless_confirm() {
  local prompt="$1"
  local answer
  local status=0

  answer="$(gum choose --header "$prompt" --cursor '> ' 'No, cancel' 'Yes, apply')" || status=$?
  if [[ "$status" -eq 0 && "$answer" != 'Yes, apply' ]]; then
    status=1
  fi
  FLOW_NATIVE_STATUS=$status
}

# Wrapper: without an interactive terminal a stage is announced as plain text and run directly.
wrapper_spin_plain_fallback() {
  local title="$1"
  local status=0

  shift
  printf 'Stage: %s\n' "$title"
  "$@" || status=$?
  return "$status"
}

# Wrapper: any failure of a stage is normalized to 5 and reports stage, reason, and next action. The
# original status is shown and logged.
wrapper_stage_status_normalization() {
  local title="$1"
  local original="$2"
  local next_action="$3"

  FLOW_ORIGINAL_STATUS=$original
  printf '%s\n' \
    "Stage failed: ${title}" \
    "Reason: the operation exited with status ${original} (normalized to 5)." \
    "Next action: ${next_action}" >&2
  flow_log "stage=${title} status=5 original_status=${original}"
  return 5
}

flow_header() {
  local line
  local index=0
  local -a shades=(255 252 249 246 243 240)

  wrapper_tty_gate || return 0
  while IFS= read -r line; do
    gum style --foreground "${shades[index]:-240}" "$line"
    index=$((index + 1))
  done < "$FLOW_BANNER_FILE"
  gum style --border rounded --border-foreground 245 --bold --padding '0 2' "$FLOW_HEADER_TEXT"
}

flow_section() {
  if flow_interactive; then
    gum style --bold --foreground 255 "$1"
  else
    printf '%s\n' "$1"
  fi
}

flow_destructive() {
  if flow_interactive; then
    gum style --bold --foreground 0 --background 255 "DESTRUCTIVE: $1"
  else
    printf 'DESTRUCTIVE: %s\n' "$1"
  fi
}

# Arguments: prompt. Returns 0 yes, 3 decline or Esc, 2 without an interactive terminal, 130 unmapped.
flow_confirm() {
  local prompt="$1"
  local native=0

  FLOW_NATIVE_STATUS=''
  wrapper_tty_precheck || return 2
  if flow_colorless; then
    wrapper_colorless_confirm "$prompt"
    native=$FLOW_NATIVE_STATUS
  else
    gum confirm --default=false --affirmative 'Yes, apply' --negative 'No, cancel' \
      --prompt.foreground 255 --selected.foreground 0 --selected.background 255 \
      --unselected.foreground 250 --unselected.background 236 "$prompt" || native=$?
    FLOW_NATIVE_STATUS=$native
  fi
  wrapper_confirm_status_map "$native"
}

# Arguments: prompt, name of the variable that receives the secret. The secret stays in a shell
# variable; it is never an argument, never in the environment, and never logged.
flow_read_secret() {
  local prompt="$1"
  local -n flow_secret_target="$2"

  wrapper_tty_precheck || return 2
  flow_secret_target="$(gum input --password --placeholder 'hidden input' \
    --header.foreground 255 --prompt.foreground 250 --cursor.foreground 255 --header "$prompt")" || return 3
}

# Arguments: title, next action, command and arguments. Returns 0, or 5 with the original status.
flow_stage() {
  local title="$1"
  local next_action="$2"
  local status=0

  shift 2
  if flow_interactive; then
    gum spin --show-error --spinner.foreground 250 --title.foreground 255 --title "$title" -- "$@" || status=$?
  else
    wrapper_spin_plain_fallback "$title" "$@" || status=$?
  fi
  if [[ "$status" -eq 0 ]]; then
    printf 'Done: %s\n' "$title"
    flow_log "stage=${title} status=0"
    return 0
  fi
  wrapper_stage_status_normalization "$title" "$status" "$next_action"
}

# The six-step plan review flow. Arguments: the complete plan file.
flow_review() {
  local plan_file="$1"
  local choice
  local status=0
  local operation

  wrapper_tty_precheck || return 2
  flow_header
  flow_section 'Step 1/6: Target summary'
  mock_target_summary
  printf '\n'
  flow_section 'Step 2/6: Proposed defaults and their provenance'
  mock_defaults
  printf '\n'
  flow_section 'Step 3/6: Destructive operations'
  while IFS= read -r operation; do
    flow_destructive "$operation"
  done < <(mock_destructive_operations)
  printf '\n'
  flow_section 'Step 4/6: The complete plan is available in a pager'
  printf '\n'
  while :; do
    status=0
    choice="$(gum choose --cursor '> ' --header.foreground 255 --cursor.foreground 255 \
      --selected.foreground 255 --item.foreground 245 \
      --header 'Step 5/6: Choose how to proceed (cancelling makes no changes)' \
      'Inspect the complete plan' 'Continue to confirmation' 'Cancel without changes')" || status=$?
    if [[ "$status" -eq 130 ]]; then
      return 130
    elif [[ "$status" -ne 0 ]]; then
      choice='Cancel without changes'
    fi
    case "$choice" in
      'Inspect the complete plan')
        gum pager --match.foreground 255 --match-highlight.foreground 0 \
          --match-highlight.background 255 < "$plan_file"
        ;;
      'Continue to confirmation') break ;;
      *)
        flow_log 'review: cancelled before confirmation'
        printf '%s\n' 'Cancelled. No changes were made.'
        return 3
        ;;
    esac
  done
  flow_section 'Step 6/6: Confirmation bound to the target and the plan digest'
  status=0
  flow_confirm "$MOCK_REVIEW_PROMPT" || status=$?
  case "$status" in
    0)
      flow_log 'review: confirmed (mock)'
      printf '%s\n' 'Confirmed (mock). Nothing was changed.'
      ;;
    3)
      flow_log 'review: declined at confirmation'
      printf '%s\n' 'Cancelled. No changes were made.'
      ;;
  esac
  return "$status"
}
