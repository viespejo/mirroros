#!/usr/bin/bash
# Frontend contract check: scenario entry points run by the contract points, inside a pty or
# directly. Usage: scenario.sh <name> [--yes|--non-interactive]. Non-production, mock data only.
#
# Scenarios: confirm, native-confirm, styled, review, secrets, stage-ok, stage-fail, native-spin,
# header, visual. The exit status is the status of the flow under test.

SCENARIO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091 # Resolved relative to this file.
source "${SCENARIO_DIR}/mock.sh" || exit 6
# shellcheck disable=SC1091 # Resolved relative to this file.
source "${SCENARIO_DIR}/flow.sh" || exit 6

scenario_confirm() {
  local status=0

  flow_confirm "Apply the mock plan to ${MOCK_TARGET_ID}?" || status=$?
  printf 'FE_NATIVE=%s\n' "${FLOW_NATIVE_STATUS:-none}"
  if [[ "$status" -eq 0 ]]; then
    printf 'FE_CONFIRMED=1\n'
  fi
  flow_log "confirm: status=${status}"
  return "$status"
}

# Native gum confirm with no wrapper, to measure what Gum does by itself.
scenario_native_confirm() {
  local status=0

  gum confirm --default=false 'Native confirmation?' || status=$?
  printf 'FE_NATIVE=%s\n' "$status"
  return "$status"
}

# Sections 1 to 3 of the review and a confirmation, for the colorless and dumb-terminal points.
scenario_styled() {
  local operation
  local status=0

  flow_header
  flow_section 'Step 1/6: Target summary'
  mock_target_summary
  flow_section 'Step 2/6: Proposed defaults and their provenance'
  mock_defaults
  flow_section 'Step 3/6: Destructive operations'
  while IFS= read -r operation; do
    flow_destructive "$operation"
  done < <(mock_destructive_operations)
  flow_confirm "$MOCK_REVIEW_PROMPT" || status=$?
  printf 'FE_NATIVE=%s\n' "${FLOW_NATIVE_STATUS:-none}"
  flow_log "styled: status=${status}"
  return "$status"
}

scenario_review() {
  local plan_file
  local status=0

  plan_file="$(mktemp)" || return 6
  mock_plan_write "$plan_file"
  flow_review "$plan_file" || status=$?
  rm -f -- "$plan_file"
  return "$status"
}

# Reads two secrets and writes them to the file named by FE_SECRET_OUT so that the harness can
# compare them with the canaries. The values are never printed or logged.
scenario_secrets() {
  local user_secret=''
  local root_secret=''

  [[ -n "${FE_SECRET_OUT:-}" ]] || return 6
  flow_read_secret 'Enter the user password (mock)' user_secret || return $?
  flow_read_secret 'Enter the root password (mock)' root_secret || return $?
  (
    umask 077
    printf '%s\n%s\n' "$user_secret" "$root_secret" > "$FE_SECRET_OUT"
  )
  flow_log "secrets: collected user_length=${#user_secret} root_length=${#root_secret}"
  printf '%s\n' 'Secrets collected (not displayed).'
}

scenario_stage_ok() {
  flow_stage 'Stage 1/1: Applying the mock partition layout' \
    'none' sleep 1.5
}

scenario_stage_fail() {
  flow_stage 'Stage 1/1: Applying the mock partition layout' \
    'check the mock target and run the command again.' \
    sh -c 'sleep 1; echo "mock error: cannot write the partition table" >&2; exit 7'
}

# Native gum spin with no wrapper, to measure the status that Gum preserves.
scenario_native_spin() {
  local status=0

  gum spin --title 'Native stage' -- sh -c 'sleep 1; exit 7' || status=$?
  printf 'FE_NATIVE=%s\n' "$status"
  return "$status"
}

scenario_header() {
  flow_header
  printf '%s\n' 'FE_HEADER_DONE'
}

# Attended visual check: borders, colors, spinner glyphs, and a destructive line.
scenario_visual() {
  local color

  flow_header
  flow_section 'Visual check 1/3: borders'
  gum style --border double --border-foreground 99 --padding '1 3' --foreground 212 \
    'Double border with padding'
  gum style --border normal --padding '0 2' 'Normal border (plain foreground)'
  flow_section 'Visual check 2/3: colors'
  for color in 1 2 3 4 5 6 7 9 10 11 12 13 14 15; do
    gum style --foreground "$color" --bold "color ${color}: abcdefghij 0123456789"
  done
  flow_destructive 'sample destructive operation (text marker plus color)'
  flow_section 'Visual check 3/3: spinner'
  flow_stage 'Stage 1/2: Spinner glyph check' 'none' sleep 3
  flow_stage 'Stage 2/2: Second spinner check' 'none' sleep 3
  printf '%s\n' 'Visual check finished.'
}

main() {
  local name="${1:-}"

  shift || true
  flow_parse_flags "$@" || return 2
  case "$name" in
    confirm) scenario_confirm ;;
    native-confirm) scenario_native_confirm ;;
    styled) scenario_styled ;;
    review) scenario_review ;;
    secrets) scenario_secrets ;;
    stage-ok) scenario_stage_ok ;;
    stage-fail) scenario_stage_fail ;;
    native-spin) scenario_native_spin ;;
    header) scenario_header ;;
    visual) scenario_visual ;;
    *)
      printf 'Unknown scenario: %s\n' "$name" >&2
      return 2
      ;;
  esac
}

main "$@"
exit $?
