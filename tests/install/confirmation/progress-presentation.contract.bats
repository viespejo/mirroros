# Synthetic presentation only; no engine, target, discovery, or power actions.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced functions consume shared state and doubles.
setup() {
  source "${BATS_TEST_DIRNAME}/../../../install/confirmation/lib/ui.sh"
  LOGO_PATH="${BATS_TEST_TMPDIR}/symbol.txt"
  printf 'symbol-a\nsymbol-b\n' > "$LOGO_PATH"
  LOGO_WIDTH=8
  ROWS=40 COLS=149
  measure_terminal() {
    TERM_WIDTH=$COLS TERM_HEIGHT=$ROWS
    PADDING_LEFT=$(((COLS > 80 ? COLS - 80 : 0) / 2))
    LOGO_PADDING_LEFT=$(((COLS - LOGO_WIDTH) / 2))
    PADDING="0 0 0 $PADDING_LEFT"
  }
  plain() { sed -E $'s/\x1b\\[[0-9;?]*[A-Za-z]//g'; }
}

@test "progress presentation centers the block and contrasts completed and remaining cells" {
  local title bar filled empty
  run ui_progress 4 11 5 'Install packages.' 12
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033[16;1H'* ]]
  [[ "$output" == *$'\033[19;1H'* ]]
  printf -v title '%65sInstalling MirrorOS' ''
  [[ "$output" == *"$title"* ]]
  printf -v filled '%12s' ''
  printf -v empty '%22s' ''
  printf -v bar '%57s\033[37m%s\033[90m%s\033[0m' '' "${filled// /█}" "${empty// /░}"
  [[ "$output" == *"$bar"* ]]
  [[ "$output" == *'[5/11] Install packages.'* ]]
  [[ "$output" == *'Packages installed: 12'* ]]
}

@test "progress presentation updates only dynamic content until geometry or height changes" {
  local first="${BATS_TEST_TMPDIR}/first" second="${BATS_TEST_TMPDIR}/second" third="${BATS_TEST_TMPDIR}/third"
  ui_progress 4 11 5 'Install packages.' 12 > "$first"
  ui_progress 4 11 5 'Install packages.' 86 > "$second"
  [[ "$(< "$first")" == *$'\033[2J'* ]]
  [[ "$(< "$second")" != *$'\033[2J'* ]]
  [[ "$(< "$second")" != *symbol-a* ]]
  [[ "$(< "$second")" == *$'\033[J'*'Packages installed: 86'* ]]
  # Counts change the detail, never the completed fraction.
  [ "$(plain < "$first" | grep '[█░]')" = "$(plain < "$second" | grep '[█░]')" ]
  ui_progress 4 11 5 'Install packages.' '' > "$third"
  [[ "$(< "$third")" == *$'\033[2J'* ]]
  COLS=100
  ui_progress 4 11 5 'Install packages.' '' > "$third"
  [[ "$(< "$third")" == *$'\033[2J'* ]]
}

@test "progress presentation omits the short-console symbol and preserves wrapped configure text" {
  local description='Configure the graphical environment with a deliberately long synthetic description that must remain complete.'
  local detail='Configure step: 2/3 synthetic/configure/path/with/a/deliberately/long/component/name'
  local compact expected line
  ROWS=20 COLS=74
  run ui_progress 10 11 11 "$description" "$detail"
  [ "$status" -eq 0 ]
  [[ "$output" != *symbol-a* && "$output" != *'Packages installed:'* ]]
  compact=$(printf '%s\n' "$output" | plain | tr -d '[:space:]')
  expected="[11/11]${description//[[:space:]]/}${detail//[[:space:]]/}"
  [[ "$compact" == *"$expected"* ]]
  while IFS= read -r line; do
    [ "${#line}" -le 74 ]
  done < <(printf '%s\n' "$output" | plain)
  COLS=20
  run ui_progress 0 0 1 'Starting.' ''
  [ "$status" -eq 0 ]
  [[ "$output" != *█* ]]
  while IFS= read -r line; do
    [ "${#line}" -le 20 ]
  done < <(printf '%s\n' "$output" | plain)
}

@test "progress presentation completes only from completed work and restores cursor on screen transition" {
  local frame="${BATS_TEST_TMPDIR}/frame" transition="${BATS_TEST_TMPDIR}/transition" bar
  ui_progress 11 11 11 'Configure the graphical environment.' '' > "$frame"
  printf -v bar '%34s' ''
  [[ "$(< "$frame")" == *"${bar// /█}"* ]]
  [[ "$(< "$frame")" != *░* ]]
  [ -n "$UI_PROGRESS_LAYOUT" ]
  clear_logo compact > "$transition"
  [ -z "$UI_PROGRESS_LAYOUT" ]
  [[ "$(< "$transition")" == *$'\033[?25h'* ]]
  ui_progress 0 11 1 'Prepare the target disk.' '' > "$frame"
  [[ "$(< "$frame")" == *$'\033[2J'* ]]
}
