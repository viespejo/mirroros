# Isolated live presentation contracts: no real VT, font change, discovery, or disk operation.
# shellcheck disable=SC1091,SC2034,SC2329 # Presentation libraries consume the doubles and shared state.
# shellcheck disable=SC2030,SC2031 # Bats isolates each test and its shared-state changes.
setup() {
  SOURCE_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/../../.." && pwd -P)"
  source "${SOURCE_ROOT}/install/confirmation/lib/ui.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/live.sh"
  source "${SOURCE_ROOT}/install/confirmation/lib/screens.sh"
  FLOW_TMP="${BATS_TEST_TMPDIR}/private"
  mkdir "$FLOW_TMP"
  CALLS="${BATS_TEST_TMPDIR}/calls"
  QUEUE="${BATS_TEST_TMPDIR}/queue"
  : > "$CALLS"
  : > "$QUEUE"
  ROWS=40 COLS=149 FONT_STATUS=0 CHOOSE_STATUS=0
  tty() { printf '/dev/tty8\n'; }
  stty() { printf '%s %s\n' "$ROWS" "$COLS"; }
  tput() { if [[ $1 == cols ]]; then printf '%s\n' "$COLS"; else printf '%s\n' "$ROWS"; fi; }
  setfont() {
    printf 'setfont %s\n' "$*" >> "$CALLS"
    if [[ $FONT_STATUS != 0 ]]; then return "$FONT_STATUS"; fi
    if [[ ${3:-} == -O ]]; then printf 'synthetic font and mapping\n' > "$4"; fi
  }
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    if [[ $1 == choose ]]; then
      if [[ $CHOOSE_STATUS != 0 ]]; then return "$CHOOSE_STATUS"; fi
      local answer
      IFS= read -r answer < "$QUEUE"
      tail -n +2 "$QUEUE" > "${QUEUE}.next"
      mv "${QUEUE}.next" "$QUEUE"
      printf '%s\n' "$answer"
    fi
  }
}

@test "setup centers the standalone symbol independently and uses native Gum help colors" {
  ui_setup "${SOURCE_ROOT}/install/confirmation" > /dev/null
  [ "$LOGO_WIDTH" -eq 16 ]
  [ "$LOGO_PADDING_LEFT" -eq 66 ]
  [ "$PADDING_LEFT" -eq 34 ]
  [ "$COLUMNS" -eq 149 ]
  [ "$LINES" -eq 40 ]
  [ "$COLORTERM" = yes ]
  [ "$GUM_CHOOSE_CURSOR" = '› ' ]
  [ "$GUM_CHOOSE_SELECTED_FOREGROUND" = 4 ]
  [ "$GUM_CHOOSE_SELECTED_BACKGROUND" = 0 ]
  [ "$GUM_CHOOSE_ITEM_FOREGROUND" = 7 ]
  [ -r "$UI_ORIGINAL_FONT" ]
}

@test "welcome uses the approved production text and Continue does not call another form" {
  printf 'Continue\n' > "$QUEUE"
  welcome_form
  grep -qF "Let's set up your machine." "$CALLS"
  grep -qF 'Installation keyboard: English (US)' "$CALLS"
  grep -qF 'Used only during installation.' "$CALLS"
  grep -qF -- '--show-help --height 3 --selected Continue Continue Change keyboard layout Change text size' "$CALLS"
  grep -qF -- '--cursor ›  --cursor.foreground 4 --cursor.background 0 --selected.foreground 4 --selected.background 0 --item.foreground 7' "$CALLS"
  run grep -qF 'A guided installation' "$CALLS"
  [ "$status" -eq 1 ]
}

@test "both text sizes load the exact captured font and doubling is absolute" {
  ui_setup "${SOURCE_ROOT}/install/confirmation" > /dev/null
  ui_apply_text_size 'Original x2'
  ui_apply_text_size 'Original x2'
  [ "$UI_TEXT_SIZE" = 'Original x2' ]
  [ "$(grep -cF "setfont -C /dev/tty8 -d $UI_ORIGINAL_FONT" "$CALLS")" -eq 2 ]
  ui_apply_text_size Original
  [ "$UI_TEXT_SIZE" = Original ]
  grep -qxF "setfont -C /dev/tty8 $UI_ORIGINAL_FONT" "$CALLS"
}

@test "text size form keeps native help and the current selection" {
  ui_setup "${SOURCE_ROOT}/install/confirmation" > /dev/null
  printf 'Original x2\n' > "$QUEUE"
  live_console_text_size_form
  [ "$UI_TEXT_SIZE" = 'Original x2' ]
  grep -qF -- '--show-help --height 2 --selected Original Original Original x2' "$CALLS"
}

@test "font loading failure is not accepted and cleanup restores the original" {
  ui_setup "${SOURCE_ROOT}/install/confirmation" > /dev/null
  FONT_STATUS=1
  run ui_apply_text_size 'Original x2'
  [ "$status" -eq 5 ]
  [ "$UI_TEXT_SIZE" = Original ]
  FONT_STATUS=0
  ui_cleanup > /dev/null
  grep -qxF "setfont -C /dev/tty8 $UI_ORIGINAL_FONT" "$CALLS"
}

@test "font capture failure stops setup without offering a substituted font" {
  FONT_STATUS=1
  run ui_setup "${SOURCE_ROOT}/install/confirmation"
  [ "$status" -eq 5 ]
  [[ "$output" == *'Could not save the live console font.'* ]]
  [ -z "$UI_ORIGINAL_FONT" ]
}

@test "pseudo-terminals never invoke setfont and reject a font change" {
  tty() { printf '/dev/pts/9\n'; }
  ui_setup "${SOURCE_ROOT}/install/confirmation" > /dev/null
  run grep -q '^setfont ' "$CALLS"
  [ "$status" -eq 1 ]
  run ui_apply_text_size 'Original x2'
  [ "$status" -eq 2 ]
}

@test "welcome text-size navigation returns to welcome and Esc does not apply a font" {
  ui_setup "${SOURCE_ROOT}/install/confirmation" > /dev/null
  printf 'Change text size\nOriginal x2\nContinue\n' > "$QUEUE"
  welcome_form > /dev/null
  [ "$UI_TEXT_SIZE" = 'Original x2' ]
  CHOOSE_STATUS=1
  run live_console_text_size_form
  [ "$status" -eq 1 ]
  [ "$(grep -cF "setfont -C /dev/tty8 -d $UI_ORIGINAL_FONT" "$CALLS")" -eq 1 ]
}

@test "short welcome and font selector omit the symbol without suppressing their titles" {
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  LOGO_WIDTH=16
  ROWS=20 COLS=74 LINES=20 COLUMNS=74
  run step 'Welcome to MirrorOS'
  [ "$status" -eq 0 ]
  [[ "$output" != *'█'* ]]
  grep -qF 'Welcome to MirrorOS' "$CALLS"
  run step 'Installation text size'
  [[ "$output" != *'█'* ]]
  ROWS=40 COLS=149 LINES=40 COLUMNS=149
  run step 'Welcome to MirrorOS'
  [[ "$output" == *'█'* ]]
}

@test "connection screen preserves live-only text and choices with the approved selector and spacing" {
  step() { :; }
  live_network_method_form() { [ "$1" = Ethernet ]; }
  printf 'Ethernet\n' > "$QUEUE"
  live_connect_form > "${BATS_TEST_TMPDIR}/connection-output"
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/connection-output")" -eq 1 ]
  grep -qF 'Internet access is needed to prepare and install MirrorOS. This connection is for the live environment only.' "$CALLS"
  grep -qF -- 'gum choose --header  --cursor ›  --cursor.foreground 4 --cursor.background 0 --selected.foreground 4 --selected.background 0 --item.foreground 7 --show-help --height 3 --selected Ethernet Ethernet Wi-Fi Cancel' "$CALLS"
}

@test "connection heading matches welcome spacing and omits the symbol on short consoles" {
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  LOGO_WIDTH=16
  step 'Welcome to MirrorOS' > "${BATS_TEST_TMPDIR}/welcome-output"
  step 'Connect to the internet' > "${BATS_TEST_TMPDIR}/connection-output"
  cmp "${BATS_TEST_TMPDIR}/welcome-output" "${BATS_TEST_TMPDIR}/connection-output"
  grep -qF 'Connect to the internet' "$CALLS"
  ROWS=20 COLS=74 LINES=20 COLUMNS=74
  run step 'Connect to the internet'
  [ "$status" -eq 0 ]
  [[ "$output" != *'█'* ]]
}

@test "connection selector preserves Esc Ctrl+C and explicit preparation cancellation" {
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  CHOOSE_STATUS=1
  run live_connect_form
  [ "$status" -eq 1 ]
  CHOOSE_STATUS=130
  run live_connect_form
  [ "$status" -eq 130 ]
  CHOOSE_STATUS=0
  flow_cancel() { [ "$1" = preparation ] || exit 6; exit 3; }
  printf 'Cancel\n' > "$QUEUE"
  run live_connect_form
  [ "$status" -eq 3 ]
}

@test "Ethernet uses secondary instructions separated from errors and the shared selector" {
  step() { :; }
  live_prepare_check() { return "$LIVE_NETWORK_NOT_READY"; }
  printf 'Retry connection check\nBack\n' > "$QUEUE"
  local result=0
  live_network_method_form Ethernet > "${BATS_TEST_TMPDIR}/ethernet-output" || result=$?
  [ "$result" -eq 1 ]
  [ "$live_network_status" = 'Not connected' ]
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/ethernet-output")" -eq 3 ]
  grep -qF 'gum style --foreground 8 --padding 0 0 0 0 Connect a network cable, then retry the connection check.' "$CALLS"
  grep -qF 'gum style --foreground 1 --padding 0 0 0 0 Could not verify internet access. Check your connection and retry.' "$CALLS"
  grep -qF -- 'gum choose --header  --cursor ›  --cursor.foreground 4 --cursor.background 0 --selected.foreground 4 --selected.background 0 --item.foreground 7 --show-help --height 2 --selected Retry connection check Retry connection check Back' "$CALLS"
}

@test "Ethernet preserves Esc Ctrl+C and successful retry outcomes" {
  step() { :; }
  CHOOSE_STATUS=1
  run live_network_method_form Ethernet
  [ "$status" -eq 1 ]
  CHOOSE_STATUS=130
  run live_network_method_form Ethernet
  [ "$status" -eq 130 ]
  CHOOSE_STATUS=0
  live_prepare_check() { return 0; }
  printf 'Retry connection check\n' > "$QUEUE"
  live_network_method_form Ethernet
  [ "$live_network_status" = Connected ]
}

@test "Ethernet heading matches welcome spacing and short-console symbol omission" {
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  LOGO_WIDTH=16
  step 'Welcome to MirrorOS' > "${BATS_TEST_TMPDIR}/welcome-output"
  step 'Connect with Ethernet' > "${BATS_TEST_TMPDIR}/ethernet-output"
  cmp "${BATS_TEST_TMPDIR}/welcome-output" "${BATS_TEST_TMPDIR}/ethernet-output"
  ROWS=20 COLS=74 LINES=20 COLUMNS=74
  run step 'Connect with Ethernet'
  [ "$status" -eq 0 ]
  [[ "$output" != *'█'* ]]
  grep -qF 'Connect with Ethernet' "$CALLS"
}

@test "Wi-Fi uses secondary instructions separated from errors and the shared selector" {
  step() { :; }
  live_prepare_check() { return "$LIVE_NETWORK_NOT_READY"; }
  printf 'Retry connection check\nBack\n' > "$QUEUE"
  local result=0
  live_network_method_form 'Wi-Fi' > "${BATS_TEST_TMPDIR}/wifi-output" || result=$?
  [ "$result" -eq 1 ]
  [ "$live_network_status" = 'Not connected' ]
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/wifi-output")" -eq 3 ]
  grep -qF 'gum style --foreground 8 --padding 0 0 0 0 Configure Wi-Fi with iwctl in another live console, then return here.' "$CALLS"
  grep -qF 'gum style --foreground 8 --padding 0 0 0 0 Select Show connection instructions for the complete Wi-Fi setup steps.' "$CALLS"
  grep -qF 'gum style --foreground 1 --padding 0 0 0 0 Could not verify internet access. Check your connection and retry.' "$CALLS"
  grep -qF -- 'gum choose --header  --cursor ›  --cursor.foreground 4 --cursor.background 0 --selected.foreground 4 --selected.background 0 --item.foreground 7 --show-help --height 3 --selected Retry connection check Retry connection check Show connection instructions Back' "$CALLS"
}

@test "Wi-Fi preserves Esc Ctrl+C and successful retry outcomes" {
  step() { :; }
  CHOOSE_STATUS=1
  run live_network_method_form 'Wi-Fi'
  [ "$status" -eq 1 ]
  CHOOSE_STATUS=130
  run live_network_method_form 'Wi-Fi'
  [ "$status" -eq 130 ]
  CHOOSE_STATUS=0
  live_prepare_check() { return 0; }
  printf 'Retry connection check\n' > "$QUEUE"
  live_network_method_form 'Wi-Fi'
  [ "$live_network_status" = Connected ]
}

@test "Wi-Fi instruction inspection preserves exact text and pager return statuses" {
  step() { :; }
  FLOW_CODE_ROOT=$SOURCE_ROOT
  local pager_status
  gum() {
    printf 'gum %s\n' "$*" >> "$CALLS"
    case $1 in
      choose)
        local answer
        IFS= read -r answer < "$QUEUE"
        tail -n +2 "$QUEUE" > "${QUEUE}.next"
        mv "${QUEUE}.next" "$QUEUE"
        printf '%s\n' "$answer"
        ;;
      pager)
        tee "${BATS_TEST_TMPDIR}/pager-input" > /dev/null
        return "$pager_status"
        ;;
    esac
  }
  for pager_status in 0 1 130; do
    printf 'Show connection instructions\nBack\n' > "$QUEUE"
    run live_network_method_form 'Wi-Fi'
    if [[ $pager_status == 130 ]]; then
      [ "$status" -eq 130 ]
      [ "$(wc -l < "$QUEUE")" -eq 1 ]
    else
      [ "$status" -eq 1 ]
      [ ! -s "$QUEUE" ]
    fi
    cmp "${SOURCE_ROOT}/install/confirmation/instructions/live-wifi.txt" "${BATS_TEST_TMPDIR}/pager-input"
    [ "$live_network_status" = 'Not checked' ]
  done
}

@test "Wi-Fi heading matches welcome spacing and short-console symbol omission" {
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  LOGO_WIDTH=16
  step 'Welcome to MirrorOS' > "${BATS_TEST_TMPDIR}/welcome-output"
  step 'Connect with Wi-Fi' > "${BATS_TEST_TMPDIR}/wifi-output"
  cmp "${BATS_TEST_TMPDIR}/welcome-output" "${BATS_TEST_TMPDIR}/wifi-output"
  ROWS=20 COLS=74 LINES=20 COLUMNS=74
  run step 'Connect with Wi-Fi'
  [ "$status" -eq 0 ]
  [[ "$output" != *'█'* ]]
  grep -qF 'Connect with Wi-Fi' "$CALLS"
}

@test "pager border uses the approved blue-gray accent for Wi-Fi instructions" {
  step() { :; }
  FLOW_CODE_ROOT=$SOURCE_ROOT
  printf 'Show connection instructions\nBack\n' > "$QUEUE"
  run live_network_method_form 'Wi-Fi'
  [ "$status" -eq 1 ]
  grep -qxF 'gum pager --border-foreground 4' "$CALLS"
  [ "$live_network_status" = 'Not checked' ]
}

@test "clock screen uses secondary explanations and a separated shared selector" {
  step() { :; }
  printf 'Retry clock check\n' > "$QUEUE"
  live_clock_form > "${BATS_TEST_TMPDIR}/clock-output"
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/clock-output")" -eq 1 ]
  grep -qF 'gum style --foreground 8 --padding 0 0 0 0 Accurate time is needed to verify secure connections and package signatures.' "$CALLS"
  grep -qF 'gum style --foreground 8 --padding 0 0 0 0 Automatic time synchronization is enabled. Make sure the network works, then retry.' "$CALLS"
  grep -qF -- 'gum choose --header  --cursor ›  --cursor.foreground 4 --cursor.background 0 --selected.foreground 4 --selected.background 0 --item.foreground 7 --show-help --height 2 --selected Retry clock check Retry clock check Cancel' "$CALLS"
}

@test "clock screen preserves Esc Ctrl+C and explicit preparation cancellation" {
  step() { :; }
  CHOOSE_STATUS=1
  run live_clock_form
  [ "$status" -eq 1 ]
  CHOOSE_STATUS=130
  run live_clock_form
  [ "$status" -eq 130 ]
  CHOOSE_STATUS=0
  flow_cancel() { [ "$1" = preparation ] || exit 6; exit 3; }
  printf 'Cancel\n' > "$QUEUE"
  run live_clock_form
  [ "$status" -eq 3 ]
}

@test "clock heading matches welcome spacing and short-console symbol omission" {
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  LOGO_WIDTH=16
  step 'Welcome to MirrorOS' > "${BATS_TEST_TMPDIR}/welcome-output"
  step 'Waiting for the system clock' > "${BATS_TEST_TMPDIR}/clock-output"
  cmp "${BATS_TEST_TMPDIR}/welcome-output" "${BATS_TEST_TMPDIR}/clock-output"
  ROWS=20 COLS=74 LINES=20 COLUMNS=74
  run step 'Waiting for the system clock'
  [ "$status" -eq 0 ]
  [[ "$output" != *'█'* ]]
  grep -qF 'Waiting for the system clock' "$CALLS"
}

@test "keyring waiting shows one secondary status only when readiness requires a wait" {
  step() { printf 'step %s\n' "$*" >> "$CALLS"; }
  systemctl() {
    [ "$*" = 'is-active pacman-init.service' ] || return 6
    if [[ -e "${BATS_TEST_TMPDIR}/keyring-checked" ]]; then
      printf 'active\n'
    else
      touch "${BATS_TEST_TMPDIR}/keyring-checked"
      printf 'activating\n'
      return 3
    fi
  }
  sleep() { printf 'sleep %s\n' "$*" >> "$CALLS"; }
  live_keyring_ready
  [ "$(grep -cxF 'step Preparing the package keyring' "$CALLS")" -eq 1 ]
  grep -qxF 'gum style --foreground 8 --padding 0 0 0 0 Waiting for the package keyring to be initialized...' "$CALLS"
  grep -qxF 'sleep 1' "$CALLS"
  : > "$CALLS"
  live_keyring_ready
  [ ! -s "$CALLS" ]
}

@test "keyring failure uses secondary explanations and a separated shared selector" {
  step() { :; }
  printf 'Retry keyring check\n' > "$QUEUE"
  live_keyring_form > "${BATS_TEST_TMPDIR}/keyring-output"
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/keyring-output")" -eq 1 ]
  grep -qF 'gum style --foreground 8 --padding 0 0 0 0 Package signatures cannot be verified until the keyring is ready. Wait a moment, then retry.' "$CALLS"
  grep -qF -- 'gum choose --header  --cursor ›  --cursor.foreground 4 --cursor.background 0 --selected.foreground 4 --selected.background 0 --item.foreground 7 --show-help --height 2 --selected Retry keyring check Retry keyring check Cancel' "$CALLS"
}

@test "keyring failure preserves Esc Ctrl+C and explicit preparation cancellation" {
  step() { :; }
  CHOOSE_STATUS=1
  run live_keyring_form
  [ "$status" -eq 1 ]
  CHOOSE_STATUS=130
  run live_keyring_form
  [ "$status" -eq 130 ]
  CHOOSE_STATUS=0
  flow_cancel() { [ "$1" = preparation ] || exit 6; exit 3; }
  printf 'Cancel\n' > "$QUEUE"
  run live_keyring_form
  [ "$status" -eq 3 ]
}

@test "keyring headings match welcome spacing and short-console symbol omission" {
  LOGO_PATH="${SOURCE_ROOT}/install/confirmation/symbol.txt"
  LOGO_WIDTH=16
  local title
  step 'Welcome to MirrorOS' > "${BATS_TEST_TMPDIR}/welcome-output"
  for title in 'Preparing the package keyring' 'Package keyring not ready'; do
    step "$title" > "${BATS_TEST_TMPDIR}/keyring-output"
    cmp "${BATS_TEST_TMPDIR}/welcome-output" "${BATS_TEST_TMPDIR}/keyring-output"
  done
  ROWS=20 COLS=74 LINES=20 COLUMNS=74
  for title in 'Preparing the package keyring' 'Package keyring not ready'; do
    run step "$title"
    [ "$status" -eq 0 ]
    [[ "$output" != *'█'* ]]
    grep -qF "$title" "$CALLS"
  done
}

@test "flow cleanup restores the font before removing the private temporary directory" {
  source "${SOURCE_ROOT}/install/confirmation/lib/flow.sh"
  FLOW_TMP="${BATS_TEST_TMPDIR}/private"
  ui_setup "${SOURCE_ROOT}/install/confirmation" > /dev/null
  setfont() {
    [ -r "$UI_ORIGINAL_FONT" ] || return 1
    printf 'restored\n' >> "$CALLS"
  }
  flow_cleanup > /dev/null
  grep -qx restored "$CALLS"
  [ ! -d "$FLOW_TMP" ]
}
