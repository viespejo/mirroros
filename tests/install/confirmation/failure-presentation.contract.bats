# Synthetic failure presentation only; no engine, credentials, target, or power actions.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced functions consume shared state and doubles.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/flow.sh"
  LOGO_PATH="${BATS_TEST_TMPDIR}/symbol.txt"
  printf 'synthetic-symbol\n' > "$LOGO_PATH"
  LOGO_WIDTH=16 ROWS=40 COLS=149
  CALLS="${BATS_TEST_TMPDIR}/calls"
  POWER="${BATS_TEST_TMPDIR}/power"
  VISITS="${BATS_TEST_TMPDIR}/visits"
  PAGER_CONTENT="${BATS_TEST_TMPDIR}/pager-content"
  : > "$CALLS"
  : > "$POWER"
  : > "$VISITS"
  FLOW_RUN_DIR="${BATS_TEST_TMPDIR}/synthetic-run"
  mkdir -p "${FLOW_RUN_DIR}/engine"
  LOG="${FLOW_RUN_DIR}/engine/engine.log"
  printf '%s\n' 'Synthetic diagnostic line.' > "$LOG"
  FLOW_ENGINE_UNVERIFIED=false FLOW_ENGINE_DESTRUCTIVE=true
  FLOW_ENGINE_FAILED_OPERATION=install_packages FLOW_ENGINE_FAILED_STATUS=1
  MENU_CHOICE='Return to shell' MENU_FIRST='' MENU_STATUS=0 PAGER_STATUS=0
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
    local kind=$1 padding='0 0 0 0' text visit=0 line
    shift
    case $kind in
      style)
        while (($#)); do
          case $1 in
            --foreground) shift 2 ;;
            --padding) padding=$2; shift 2 ;;
            *) break ;;
          esac
        done
        for text in "$@"; do
          while IFS= read -r line; do
            printf '%*s%s\n' "${padding##* }" '' "$line"
          done <<< "$text"
        done
        ;;
      choose)
        if [[ -s $VISITS ]]; then read -r visit < "$VISITS"; fi
        printf '%s\n' "$((visit + 1))" > "$VISITS"
        if [[ $visit == 0 && -n $MENU_FIRST ]]; then
          printf '%s\n' "$MENU_FIRST"
        else
          printf '%s\n' "$MENU_CHOICE"
        fi
        return "$MENU_STATUS"
        ;;
      pager)
        while IFS= read -r line || [[ -n $line ]]; do printf '%s\n' "$line"; done > "$PAGER_CONTENT"
        return "$PAGER_STATUS"
        ;;
      *) return 6 ;;
    esac
  }
  plain() { sed -E $'s/\x1b\[[0-9;?]*[A-Za-z]//g'; }
  measure_terminal
}

@test "failure presentation uses compact top spacing and separated complete diagnostic blocks" {
  local warning='The disk was partially modified and installation did not complete.'
  run ui_engine_failure install_packages 1 true "$LOG" /preview/synthetic-run
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033[37m\n\n'*'MirrorOS installation stopped'* ]]
  [[ "$output" != *synthetic-symbol* ]]
  [[ "$output" == *$'Exit status: 1\n\n'*"$warning"* ]]
  [[ "$output" == *"$warning"$'\n\n'*'Synthetic diagnostic line.'* ]]
  grep -qxF 'gum style --foreground 1 --padding 0 0 0 34 MirrorOS installation stopped' "$CALLS"
  grep -qxF "gum style --foreground 1 --padding 0 0 0 34 $warning" "$CALLS"
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 34 Run directory: /preview/synthetic-run' "$CALLS"
}

@test "failure presentation preserves exactly the last fifteen sanitized log lines" {
  local index
  : > "$LOG"
  for ((index=1; index<=20; index++)); do
    printf '\033[31mlog-%03d\033[0m\001\n' "$index" >> "$LOG"
  done
  run ui_engine_failure install_packages 1 true "$LOG" /preview/synthetic-run
  [ "$status" -eq 0 ]
  [[ "$output" != *log-005* && "$output" == *log-006* && "$output" == *log-020* ]]
  [ "$(printf '%s\n' "$output" | grep -c 'log-')" -eq 15 ]
  [[ "$output" != *$'\033[31m'* && "$output" != *$'\001'* ]]
}

@test "failure presentation caps only its own form and retains narrow text and unmodified wording" {
  local text path line compact
  printf -v text '%110s' ''
  text=${text// /x}
  printf '%s\n' "$text" > "$LOG"
  path='/preview/a/very/long/synthetic/run/directory/with/no/short/path/segments'
  run ui_engine_failure install_packages 1 true "$LOG" "$path"
  [ "$status" -eq 0 ]
  while IFS= read -r line; do [ "${#line}" -le 114 ]; done < <(printf '%s\n' "$output" | plain)
  compact=$(printf '%s\n' "$output" | plain | tr -d '[:space:]')
  [[ "$compact" == *"$text"* && "$compact" == *"$path"* ]]
  run ui_wrapped_style 7 "$text"
  [ "$status" -eq 0 ]
  [ "${#output}" -eq 144 ]
  ROWS=20 COLS=74
  run ui_engine_failure prepare_target_disk 1 false "$LOG" "$path"
  [ "$status" -eq 0 ]
  [[ "$output" == *'The disk was not modified.'* && "$output" != *'partially modified'* ]]
  compact=$(printf '%s\n' "$output" | plain | tr -d '[:space:]')
  [[ "$compact" == *"$text"* && "$compact" == *"$path"* ]]
  while IFS= read -r line; do [ "${#line}" -le 73 ]; done < <(printf '%s\n' "$output" | plain)
}

@test "failure presentation retains selected shell native help and explicit power choices" {
  local choice code
  for code in 0 1 130; do
    for choice in 'Return to shell' Restart 'Power off'; do
      : > "$CALLS"
      : > "$POWER"
      MENU_CHOICE=$choice MENU_STATUS=$code
      run flow_failure_menu
      [ "$status" -eq 0 ]
      grep -qxF 'leave-interactive' "$CALLS"
      grep -qxF 'gum choose --header  --cursor ›  --cursor.foreground 4 --cursor.background 0 --selected.foreground 4 --selected.background 0 --item.foreground 7 --show-help --height 4 --selected Return to shell View full log Return to shell Restart Power off' "$CALLS"
      if [[ $code == 0 && $choice == Restart ]]; then
        [ "$(< "$POWER")" = reboot ]
      elif [[ $code == 0 && $choice == 'Power off' ]]; then
        [ "$(< "$POWER")" = poweroff ]
      else
        [ ! -s "$POWER" ]
      fi
    done
  done
}

@test "failure presentation inspects the unchanged log with an accent border and redraws without a power action" {
  MENU_FIRST='View full log'
  PAGER_STATUS=1
  run flow_failure_menu
  [ "$status" -eq 0 ]
  grep -qxF 'gum pager --border-foreground 4' "$CALLS"
  cmp "$LOG" "$PAGER_CONTENT"
  [ "$(grep -c 'gum style .*MirrorOS installation stopped' "$CALLS")" -eq 2 ]
  [ "$(< "$VISITS")" -eq 2 ]
  [ ! -s "$POWER" ]
}

@test "failure presentation shares the approved verification selector and pager accent" {
  FLOW_ENGINE_UNVERIFIED=true MENU_FIRST='View full log'
  ui_not_verified() { printf 'Approved verification presentation.\n'; }
  run flow_failure_menu
  [ "$status" -eq 0 ]
  grep -qF 'gum choose --header  --cursor › ' "$CALLS"
  grep -qxF 'gum pager --border-foreground 4' "$CALLS"
  [ ! -s "$POWER" ]
}
