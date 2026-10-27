# Isolated hibernation and locale presentation: synthetic providers, no live keyboard or disk operations.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced libraries consume shared state and function doubles.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/screens.sh"
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  LOGO_WIDTH=16
  CALLS="${BATS_TEST_TMPDIR}/calls"
  ANSWERS="${BATS_TEST_TMPDIR}/answers"
  POSITION="${BATS_TEST_TMPDIR}/position"
  : > "$CALLS"
  : > "$ANSWERS"
  printf '0\n' > "$POSITION"
  FLOW_PREVIEW=synthetic-preview
  ROWS=40 COLS=149
  declare -gA CHOICES=([hibernation]=true [swapfile_size]=4096 [timezone]=Europe/London [lang]=es_ES.UTF-8 [regional_format]=follow_language [console_keymap]=es)
  ui_interactive() { return 1; }
  measure_terminal() {
    TERM_WIDTH=$COLS TERM_HEIGHT=$ROWS
    PADDING_LEFT=$(((COLS > 80 ? COLS - 80 : 0) / 2))
    LOGO_PADDING_LEFT=$(((COLS - LOGO_WIDTH) / 2))
    PADDING="0 0 0 $PADDING_LEFT"
  }
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    if [[ $1 == choose || $1 == input ]]; then
      local position index=0 code answer
      read -r position < "$POSITION"
      while IFS=$'\t' read -r code answer; do
        if ((index == position)); then
          printf '%s\n' "$((position + 1))" > "$POSITION"
          if [[ $code != 0 ]]; then return "$code"; fi
          printf '%s\n' "$answer"
          return 0
        fi
        index=$((index + 1))
      done < "$ANSWERS"
      return 6
    fi
  }
  flow_choice() { printf '%s\n' "${CHOICES[$1]:-8192}"; }
  flow_assistant() {
    [[ $1 == get && $2 == "$FLOW_PREVIEW" ]] || return 6
    case $3 in
      options.swapfile_size.minimum) printf '512\n' ;;
      options.swapfile_size.maximum) printf '8192\n' ;;
      *) return 6 ;;
    esac
  }
  flow_apply_choice() {
    printf 'apply %s %s\n' "$1" "$2" >> "$CALLS"
    if [[ $1 == swapfile_size ]]; then
      [[ $2 =~ ^[0-9]+$ && ${#2} -le 4 ]] || return 1
      ((10#$2 >= 512 && 10#$2 <= 8192)) || return 1
    fi
    CHOICES[$1]=$2
    if [[ $1:$2 == hibernation:false ]]; then unset 'CHOICES[swapfile_size]'; fi
  }
}

@test "hibernation-locale enabled revisits preserve explicit size and the original input contract" {
  printf '0\tEnabled\n0\t4096\n' > "$ANSWERS"
  hibernation_form > "${BATS_TEST_TMPDIR}/output"
  grep -qF -- '--selected Enabled Enabled Disabled' "$CALLS"
  grep -qxF 'gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --value 4096 --placeholder Size in MiB --prompt Swapfile size (MiB)> ' "$CALLS"
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 Hibernation lets the machine power off and resume where it left off. Enabled keeps a swapfile on disk; it also serves as fallback swap when zram is full.' "$CALLS"
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 34 The swapfile holds the hibernation image and also serves as fallback swap after zram. The default does not guarantee hibernation for every workload.' "$CALLS"
  grep -qF 'gum choose --header  --cursor › ' "$CALLS"
  [ "$(grep -c '^apply ' "$CALLS")" -eq 1 ]
  [ "${CHOICES[swapfile_size]}" -eq 4096 ]
}

@test "hibernation-locale disabling skips sizing and re-enabling requests the reset provider proposal" {
  printf '0\tDisabled\n0\tEnabled\n0\t8192\n' > "$ANSWERS"
  hibernation_form > /dev/null
  [ "${CHOICES[hibernation]}" = false ]
  [ -z "${CHOICES[swapfile_size]:-}" ]
  run grep -q '^gum input' "$CALLS"
  [ "$status" -eq 1 ]
  hibernation_form > /dev/null
  grep -qF -- '--selected Disabled Enabled Disabled' "$CALLS"
  grep -qF 'gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --value 8192 ' "$CALLS"
  [ "${CHOICES[hibernation]}" = true ]
  [ "${CHOICES[swapfile_size]}" -eq 8192 ]
  grep -qxF 'apply hibernation false' "$CALLS"
  grep -qxF 'apply hibernation true' "$CALLS"
}

@test "hibernation-locale Esc from sizing returns to hibernation without applying incomplete size" {
  printf '0\tEnabled\n1\t\n0\tDisabled\n' > "$ANSWERS"
  hibernation_form > /dev/null
  grep -qF 'Choose swapfile size' "$CALLS"
  grep -qF 'Choose hibernation' "$CALLS"
  [ "$(grep -c '^gum choose ' "$CALLS")" -eq 2 ]
  run grep -q '^apply swapfile_size' "$CALLS"
  [ "$status" -eq 1 ]
  [ "${CHOICES[hibernation]}" = false ]
}

@test "hibernation-locale invalid sizes preserve retry values separated red errors and normalization" {
  printf '0\t511\n0\t8193\n0\tabc\n0\t\n0\t000512\n' > "$ANSWERS"
  swapfile_size_form > "${BATS_TEST_TMPDIR}/output"
  [ "${CHOICES[swapfile_size]}" -eq 512 ]
  [ "$(grep -c '^gum input ' "$CALLS")" -eq 5 ]
  [ "$(grep -c '^gum style --foreground 1 .*Use a whole number from 512 to 8192 MiB\.$' "$CALLS")" -eq 4 ]
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 Enter an integer from 512 to 8192 MiB. A real plan checks that the complete layout fits the selected disk.' "$CALLS"
  grep -qF 'gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --value 511 ' "$CALLS"
  grep -qF 'gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --value 8193 ' "$CALLS"
  grep -qF 'gum input --show-help --prompt.foreground 4 --placeholder.foreground 8 --cursor.foreground 4 --value abc ' "$CALLS"
  grep -qxF 'apply swapfile_size 512' "$CALLS"
  # Two blank separators per sizing draw, plus one before each retry error.
  # The real heading also emits spacing, so inspect the initial two separators independently.
  printf '0\t8192\n' > "$ANSWERS"
  printf '0\n' > "$POSITION"
  swapfile_size_form > "${BATS_TEST_TMPDIR}/initial-output"
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/initial-output")" -eq 2 ]
}

@test "hibernation-locale timezone language formats and installed keyboard keep options and mappings" {
  printf '0\tUTC\n0\tEnglish (US)\n0\tUnited States\n0\tSpanish (ES)\n' > "$ANSWERS"
  timezone_form > /dev/null
  system_language_form > "${BATS_TEST_TMPDIR}/language-output"
  regional_formats_form > "${BATS_TEST_TMPDIR}/formats-output"
  keyboard_form > "${BATS_TEST_TMPDIR}/keyboard-output"
  [ "${CHOICES[timezone]}" = UTC ]
  [ "${CHOICES[lang]}" = en_US.UTF-8 ]
  [ "${CHOICES[regional_format]}" = en_US.UTF-8 ]
  [ "${CHOICES[console_keymap]}" = es ]
  grep -qF -- '--selected Europe/London' "$CALLS"
  grep -qF -- '--selected Spanish (Spain) English (US) Spanish (Spain)' "$CALLS"
  grep -qF -- '--selected Follow system language Follow system language Spain United States' "$CALLS"
  grep -qF -- '--selected Spanish (ES)' "$CALLS"
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 Follow system language currently means: English (US).' "$CALLS"
  grep -qxF "gum style --foreground 8 --padding 0 0 0 0 Choose the installed system's console keyboard layout. Wayland desktop layouts are configured separately." "$CALLS"
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 Choose the default language for system messages and applications. Applications may use their own language preference. Keyboard is separate.' "$CALLS"
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 Choose formats for dates, numbers, currency, and measurement units. This does not change the language of messages or your keyboard.' "$CALLS"
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/language-output")" -eq 1 ]
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/formats-output")" -eq 2 ]
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/keyboard-output")" -eq 1 ]
  [ "$(grep -c '^gum choose --header  --cursor › ' "$CALLS")" -eq 4 ]
}

@test "hibernation-locale alternate language format and keyboard mappings remain available" {
  printf '0\tSpanish (Spain)\n0\tSpain\n0\tFollow system language\n0\tEnglish (US)\n0\tEurope/Madrid\n0\tEurope/London\n' > "$ANSWERS"
  system_language_form > /dev/null
  [ "${CHOICES[lang]}" = es_ES.UTF-8 ]
  regional_formats_form > /dev/null
  [ "${CHOICES[regional_format]}" = es_ES.UTF-8 ]
  regional_formats_form > /dev/null
  [ "${CHOICES[regional_format]}" = follow_language ]
  keyboard_form > /dev/null
  [ "${CHOICES[console_keymap]}" = us ]
  timezone_form > /dev/null
  [ "${CHOICES[timezone]}" = Europe/Madrid ]
  timezone_form > /dev/null
  [ "${CHOICES[timezone]}" = Europe/London ]
}

@test "hibernation-locale all selectors and sizing preserve Esc and Ctrl+C without applying answers" {
  local form code
  for form in hibernation_form swapfile_size_form timezone_form system_language_form regional_formats_form keyboard_form; do
    for code in 1 130; do
      printf '%s\t\n' "$code" > "$ANSWERS"
      printf '0\n' > "$POSITION"
      run "$form"
      [ "$status" -eq "$code" ]
    done
  done
  run grep -q '^apply ' "$CALLS"
  [ "$status" -eq 1 ]
}

@test "hibernation-locale unexpected provider and validation statuses propagate" {
  printf '0\t8192\n' > "$ANSWERS"
  flow_apply_choice() { return 5; }
  run swapfile_size_form
  [ "$status" -eq 5 ]
  flow_choice() { return 6; }
  run hibernation_form
  [ "$status" -eq 6 ]
}

@test "hibernation-locale six headings match welcome spacing and short-console symbol omission" {
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  LOGO_WIDTH=16
  local title
  step 'Welcome to MirrorOS' > "${BATS_TEST_TMPDIR}/welcome-output"
  for title in 'Choose hibernation' 'Choose swapfile size' 'Select your timezone' 'Choose system language' 'Choose regional formats' 'Choose installed console keyboard'; do
    step "$title" > "${BATS_TEST_TMPDIR}/screen-output"
    cmp "${BATS_TEST_TMPDIR}/welcome-output" "${BATS_TEST_TMPDIR}/screen-output"
    ROWS=20 COLS=74
    run step "$title"
    [ "$status" -eq 0 ]
    [[ "$output" != *'█'* ]]
    grep -qF "$title" "$CALLS"
    ROWS=40 COLS=149
  done
}
