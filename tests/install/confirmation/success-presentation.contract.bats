# Synthetic success presentation only; no engine, credentials, target, or power actions.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced functions consume shared state and doubles.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/flow.sh"
  LOGO_PATH="${BATS_TEST_TMPDIR}/symbol.txt"
  printf 'symbol-a\nsymbol-b\n' > "$LOGO_PATH"
  LOGO_WIDTH=8
  ROWS=40 COLS=149
  CALLS="${BATS_TEST_TMPDIR}/calls"
  POWER="${BATS_TEST_TMPDIR}/power"
  : > "$CALLS"
  : > "$POWER"
  MENU_CHOICE='Restart now' MENU_STATUS=0
  measure_terminal() {
    TERM_WIDTH=$COLS TERM_HEIGHT=$ROWS
    PADDING_LEFT=$(((COLS > 80 ? COLS - 80 : 0) / 2))
    LOGO_PADDING_LEFT=$(((COLS - LOGO_WIDTH) / 2))
    PADDING="0 0 0 $PADDING_LEFT"
  }
  ui_interactive() { return 1; }
  flow_leave_interactive() { printf 'leave-interactive\n' >> "$CALLS"; }
  flow_power_action() { printf '%s\n' "$1" >> "$POWER"; }
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    [[ $1 == choose ]] || return 6
    printf '%s\n' "$MENU_CHOICE"
    return "$MENU_STATUS"
  }
  plain() { sed -E $'s/\x1b\[[0-9;?]*[A-Za-z]//g'; }
}

@test "success presentation centers the composition and restores the progress cursor" {
  local frame="${BATS_TEST_TMPDIR}/frame" title
  UI_PROGRESS_LAYOUT=synthetic-progress
  ui_success 754 > "$frame"
  [ -z "$UI_PROGRESS_LAYOUT" ]
  [ "$UI_SUCCESS_PADDING" = '0 0 0 60' ]
  [[ "$(< "$frame")" == *$'\033[?25h'* ]]
  [[ "$(< "$frame")" == *$'\033[16;1H'* ]]
  printf -v title '%60sInstalled MirrorOS in 12m 34s' ''
  [[ "$(< "$frame")" == *"$title"* ]]
  [[ "$(< "$frame")" == *$'symbol-b\n\n\n'* ]]
  [[ "$(< "$frame")" != *'Base system verified and graphical environment configured.'* ]]
}

@test "success presentation retains seconds minutes and hours without a redundant explanation" {
  local seconds expected
  for seconds in 5 75 3661; do
    case $seconds in
      5) expected='5s' ;;
      75) expected='1m 15s' ;;
      3661) expected='1h 1m 1s' ;;
    esac
    run ui_success "$seconds"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installed MirrorOS in $expected"* ]]
    [[ "$output" != *'Base system verified and graphical environment configured.'* ]]
  done
}

@test "success presentation omits the short-console symbol and wraps the complete duration title" {
  local line compact
  ROWS=20 COLS=74
  run ui_success 754
  [ "$status" -eq 0 ]
  [[ "$output" != *symbol-a* ]]
  [[ "$output" == *$'\033[8;1H'* ]]
  [[ "$output" == *'Installed MirrorOS in 12m 34s'* ]]
  COLS=20
  run ui_success 3661
  [ "$status" -eq 0 ]
  compact=$(printf '%s\n' "$output" | plain | tr -d '[:space:]')
  [[ "$compact" == *'InstalledMirrorOSin1h1m1s'* ]]
  while IFS= read -r line; do
    [ "${#line}" -le 20 ]
  done < <(printf '%s\n' "$output" | plain)
}

@test "success presentation aligns vertical options and native help with the title and preserves power choices" {
  local code choice
  ui_success 754 > /dev/null
  for code in 0 1 130; do
    for choice in 'Restart now' 'Return to shell'; do
      : > "$CALLS"
      : > "$POWER"
      MENU_STATUS=$code MENU_CHOICE=$choice
      run flow_success_menu
      [ "$status" -eq 0 ]
      grep -qxF 'leave-interactive' "$CALLS"
      grep -qxF 'gum choose --header  --cursor ›  --cursor.foreground 4 --cursor.background 0 --selected.foreground 4 --selected.background 0 --item.foreground 7 --padding 0 0 0 60 --show-help --height 2 --selected Restart now Restart now Return to shell' "$CALLS"
      if [[ $code == 0 && $choice == 'Restart now' ]]; then
        [ "$(< "$POWER")" = reboot ]
      else
        [ ! -s "$POWER" ]
      fi
    done
  done
}
