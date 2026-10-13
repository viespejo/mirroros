# Isolated D19/D20 presentation contracts; no terminal, target, or VM is required.
# shellcheck disable=SC1091,SC2034,SC2329 # Sourced presentation code invokes the doubles and reads the state.
setup() {
  source "${BATS_TEST_DIRNAME}/../../../install/confirmation/lib/ui.sh"
  clear_logo() { :; }
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

@test "D19 wraps every diagnostic line and preserves long paths and log words" {
  local path='/a/very/long/run/directory/with/no/short/path/segments'
  printf '%s\n' 'A diagnostic line with words that must remain visible.' "$path" > "${BATS_TEST_TMPDIR}/engine.log"
  run ui_engine_failure install_packages 5 true "${BATS_TEST_TMPDIR}/engine.log" "$path"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | awk 'length > 40 { found=1 } END { exit found }'
  [[ "${output//[[:space:]]/}" == *"${path}"* ]]
  [[ "${output//[[:space:]]/}" == *'partiallymodifiedandinstallationdidnotcomplete.'* ]]
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
