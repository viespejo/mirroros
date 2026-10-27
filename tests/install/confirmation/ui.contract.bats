# Isolated engine failure presentation contracts; no terminal, target, or VM is required.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced presentation code invokes the doubles and reads the state.
setup() {
  source "${BATS_TEST_DIRNAME}/../../../install/confirmation/lib/ui.sh"
  clear_logo() { :; }
  # Progress now measures its own centered composition on each state redraw.
  measure_terminal() { TERM_WIDTH=80 TERM_HEIGHT=25; }
  gum() {
    local padding='0 0 0 0' text
    while [[ $# -gt 0 ]]; do
      case "$1" in
        style) shift ;;
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
  }
  TERM_WIDTH=40
  PADDING_LEFT=5
  PADDING='0 0 0 5'
}

@test "the engine no-valid-record failure wraps every line without truncation" {
  local path='/a/very/long/run/directory/with/no/short/path/segments'
  run ui_engine_record_failure 5 "$path"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | awk 'length > 40 { found=1 } END { exit found }'
  [[ "${output//[[:space:]]/}" == *'Phase:Installationengine'* ]]
  [[ "${output//[[:space:]]/}" == *'Cause:Theengineendedwithstatus5andleftnovalidrecord.'* ]]
  [[ "${output//[[:space:]]/}" == *"Next:Checkinstall.logandengine/in${path}."* ]]
}

@test "failed phase diagnostics wrap without truncating the cause" {
  local cause='A diagnostic line longer than the available terminal width remains complete.'
  run ui_failure Discovery "$cause" 'Run discovery again.'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | awk 'length > 40 { found=1 } END { exit found }'
  [[ "${output//[[:space:]]/}" == *"Cause:${cause//[[:space:]]/}"* ]]
}

@test "D19 wraps every diagnostic line and preserves long paths and log words" {
  local path='/a/very/long/run/directory/with/no/short/path/segments'
  printf '%s\n' 'A diagnostic line with words that must remain visible.' "$path" > "${BATS_TEST_TMPDIR}/engine.log"
  run ui_engine_failure install_packages 5 true "${BATS_TEST_TMPDIR}/engine.log" "$path"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | awk 'length > 40 { found=1 } END { exit found }'
  [[ "${output//[[:space:]]/}" == *"${path}"* ]]
  [[ "${output//[[:space:]]/}" == *'partiallymodifiedandinstallationdidnotcomplete.'* ]]
}

@test "D22 wraps the failed step and installed-system recovery without truncation" {
  run ui_not_configured desktop/compositor/providers/hyprland '/a/very/long/run/directory/with/no/short/path/segments'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | awk 'length > 40 { found=1 } END { exit found }'
  [[ "${output//[[:space:]]/}" == *'Basesysteminstalledandverified;environmentconfigurationfailedatstepdesktop/compositor/providers/hyprland.'* ]]
  [[ "${output//[[:space:]]/}" == *'Boottheinstalledsystem,loginattheconsole,andrunsudomirroros-configure.'* ]]
}

@test "D17 configure progress shows the step instead of a package count and D18 shows the duration" {
  PADDING_LEFT_SPACES='     '
  run ui_progress 3 4 4 'Configure the graphical environment.' 'Configure step: 4/5 desktop/compositor/providers/hyprland'
  [ "$status" -eq 0 ]
  [[ "$output" == *'[4/4] Configure the graphical environment.'* ]]
  [[ "$output" == *'Configure step: 4/5 desktop/compositor/providers/hyprland'* ]]
  [[ "$output" != *'Packages installed:'* ]]
  run ui_success 75
  [ "$status" -eq 0 ]
  [[ "$output" == *'Installed MirrorOS in 1m 15s'* ]]
  [[ "$output" != *'Base system verified and graphical environment configured.'* ]]
}

@test "D17 initial configure progress never presents the step label as a package count" {
  PADDING_LEFT_SPACES='     '
  run ui_progress 3 4 4 'Configure the graphical environment.' 'Configure step:'
  [ "$status" -eq 0 ]
  [[ "$output" == *'Configure step:'* ]]
  [[ "$output" != *'Packages installed:'* ]]
}

@test "D20 wraps the title, warning, check detail, and run directory without truncation" {
  printf '%s\n' '{"postconditions":{"checks":[{"id":"boot_resume_parameters","status":"failed","detail":"Expected offset 1234 but observed offset 5678 in the configured boot entry."}]}}' > "${BATS_TEST_TMPDIR}/engine-run.json"
  run ui_not_verified "${BATS_TEST_TMPDIR}/engine-run.json" '/a/very/long/run/directory/with/no/short/path/segments'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | awk 'length > 40 { found=1 } END { exit found }'
  [[ "${output//[[:space:]]/}" == *'Failedcheck:boot_resume_parameters'* ]]
  [[ "${output//[[:space:]]/}" == *'Expectedoffset1234butobservedoffset5678intheconfiguredbootentry.'* ]]
  [[ "${output//[[:space:]]/}" == *'Donotrelyonit.'* ]]
}
