# Confirmation presentation only: synthetic providers, no authorization, credentials, or disk operations.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced forms consume shared state and function doubles.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/screens.sh"
  CALLS="${BATS_TEST_TMPDIR}/calls"
  : > "$CALLS"
  CONFIRM_STATUS=0 INPUT_STATUS=0 PROVIDER_STATUS=0 NAME_STATUS=0
  TYPED=vda DISK_ID=synthetic-disk-A ROWS=40 COLS=149
  FLOW_PLAN_FILE=synthetic-plan FLOW_PROFILE_STATUS=matched
  declare -gA FLOW_REVIEW=([disk]='Synthetic disk A (64 GiB)' [storage_option]=btrfs-limine [storage_tier]=default [plan_reference]=0123456789ab)
  ui_interactive() { return 1; }
  measure_terminal() {
    TERM_WIDTH=$COLS TERM_HEIGHT=$ROWS
    PADDING_LEFT=$(((COLS > 80 ? COLS - 80 : 0) / 2))
    LOGO_PADDING_LEFT=$(((COLS - LOGO_WIDTH) / 2))
    PADDING="0 0 0 $PADDING_LEFT"
  }
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    case $1 in
      style) printf 'style %s\n' "$*" ;;
      confirm) return "$CONFIRM_STATUS" ;;
      input)
        [[ $INPUT_STATUS == 0 ]] || return "$INPUT_STATUS"
        printf '%s\n' "$TYPED"
        ;;
    esac
  }
  flow_reached() { printf 'reached %s\n' "$1" >> "$CALLS"; }
  flow_device_name() { FLOW_DEVICE_NAME=vda; return "$NAME_STATUS"; }
  flow_load_review() { return 0; }
  flow_assistant() {
    [[ $PROVIDER_STATUS == 0 ]] || return "$PROVIDER_STATUS"
    [[ $# == 3 && $1 == get && $2 == "$FLOW_PLAN_FILE" ]] || return 6
    case $3 in
      target.disk.path) printf '/dev/vda\n' ;;
      target.disk.by_id) printf '%s\n' "$DISK_ID" ;;
      *) return 6 ;;
    esac
  }
  flow_cancel() { printf 'cancel %s\n' "$1" >> "$CALLS"; exit 3; }
  flow_mismatch() { printf 'mismatch\n' >> "$CALLS"; exit 3; }
  flow_confirmed() { printf 'confirmed\n' >> "$CALLS"; }
  measure_terminal
}

@test "confirmation presentation aligns complete disk context and preserves warning and accent controls" {
  capture_confirmation() { confirmation_form && printf 'end\n'; }
  run capture_confirmation
  [ "$status" -eq 0 ]
  grep -qxF 'gum style --foreground 7 --padding 0 0 0 34 Disk           Synthetic disk A (64 GiB)' "$CALLS"
  grep -qxF 'gum style --foreground 7 --padding 0 0 0 34 Path           /dev/vda' "$CALLS"
  grep -qxF 'gum style --foreground 7 --padding 0 0 0 34 Disk ID        synthetic-disk-A' "$CALLS"
  grep -qxF 'gum style --foreground 7 --padding 0 0 0 34 New layout     Btrfs + Snapper + Limine - Default' "$CALLS"
  grep -qxF 'gum style --foreground 7 --padding 0 0 0 34 Plan reference 0123456789ab' "$CALLS"
  [[ "$output" == *$'0123456789ab\n\nstyle style --foreground 1'* ]]
  [[ "$output" == *$'This will erase all existing content on this disk.\n\n'* ]]
  grep -qxF 'gum confirm --prompt.foreground 7 --selected.foreground 4 --selected.background 0 --default=false --affirmative Yes, erase --negative No Erase /dev/vda and apply plan 0123456789ab?' "$CALLS"
  grep -qxF 'gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --prompt Device name> ' "$CALLS"
  grep -qxF confirmed "$CALLS"
}

@test "confirmation presentation separates the unchanged device instruction from its accented input" {
  capture_device_instruction() { confirmation_form && printf 'end\n'; }
  run capture_device_instruction
  [ "$status" -eq 0 ]
  [[ "$output" == *$'style style --foreground 8 --padding 0 0 0 34 Type the device name (vda) to confirm.\n\nend'* ]]
  grep -qxF 'gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --prompt Device name> ' "$CALLS"
  run grep -E '^gum input .*--header' "$CALLS"
  [ "$status" -eq 1 ]
  grep -qxF confirmed "$CALLS"
}

@test "confirmation presentation preserves conditional experimental warning and missing identity text" {
  FLOW_PROFILE_STATUS=unqualified DISK_ID=''
  run confirmation_form
  [ "$status" -eq 0 ]
  grep -qxF 'gum style --foreground 3 --padding 0 0 0 34 Experimental: this machine matches no known profile.' "$CALLS"
  grep -qxF 'gum style --foreground 7 --padding 0 0 0 34 Disk ID        not reported' "$CALLS"
  : > "$CALLS"
  FLOW_PROFILE_STATUS=matched
  run confirmation_form
  [ "$status" -eq 0 ]
  run grep -F 'Experimental:' "$CALLS"
  [ "$status" -eq 1 ]
}

@test "confirmation presentation No Esc and Ctrl+C cancel without authorization at either control" {
  local code
  for code in 1 130; do
    : > "$CALLS"
    CONFIRM_STATUS=$code INPUT_STATUS=0
    run confirmation_form
    [ "$status" -eq 3 ]
    grep -qxF 'cancel confirmation' "$CALLS"
    run grep -E '^gum input |^confirmed$' "$CALLS"
    [ "$status" -eq 1 ]
    : > "$CALLS"
    CONFIRM_STATUS=0 INPUT_STATUS=$code
    run confirmation_form
    [ "$status" -eq 3 ]
    grep -qxF 'cancel confirmation' "$CALLS"
    run grep -xF confirmed "$CALLS"
    [ "$status" -eq 1 ]
  done
}

@test "confirmation presentation requires exact device name and never retries a mismatch" {
  local value
  for value in VDA /dev/vda 'vda ' ''; do
    : > "$CALLS"
    TYPED=$value
    run confirmation_form
    [ "$status" -eq 3 ]
    [ "$(grep -c '^gum input ' "$CALLS")" -eq 1 ]
    grep -qxF mismatch "$CALLS"
    run grep -xF confirmed "$CALLS"
    [ "$status" -eq 1 ]
  done
}

@test "confirmation presentation provider and widget failures do not confirm" {
  local code
  for code in 5 6; do
    : > "$CALLS"
    PROVIDER_STATUS=$code
    run confirmation_form
    [ "$status" -eq 6 ]
    run grep -E '^gum confirm |^gum input |^confirmed$' "$CALLS"
    [ "$status" -eq 1 ]
    PROVIDER_STATUS=0 CONFIRM_STATUS=$code
    run confirmation_form
    [ "$status" -eq "$code" ]
    run grep -E '^gum input |^confirmed$' "$CALLS"
    [ "$status" -eq 1 ]
    CONFIRM_STATUS=0 INPUT_STATUS=$code
    run confirmation_form
    [ "$status" -eq "$code" ]
    run grep -xF confirmed "$CALLS"
    [ "$status" -eq 1 ]
    INPUT_STATUS=0
  done
}

@test "confirmation presentation heading matches welcome and omits symbol on short consoles" {
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt" LOGO_WIDTH=16
  step 'Welcome to MirrorOS' > "${BATS_TEST_TMPDIR}/welcome-output"
  step 'Confirm installation' > "${BATS_TEST_TMPDIR}/screen-output"
  [ "$(grep -c '█' "${BATS_TEST_TMPDIR}/screen-output")" -eq "$(grep -c '█' "${BATS_TEST_TMPDIR}/welcome-output")" ]
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/screen-output")" -eq "$(wc -l < "${BATS_TEST_TMPDIR}/welcome-output")" ]
  ROWS=20 COLS=74
  run step 'Confirm installation'
  [ "$status" -eq 0 ]
  [[ "$output" != *'█'* ]]
  [[ "$output" == *'Confirm installation'* ]]
}
