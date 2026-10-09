load support

setup() {
  confirm_setup
  confirm_scenario reference-vm-empty
}

teardown() {
  confirm_teardown
}

# Scripted answers of the shortest approving run: target, menu, confirmation, device name.
approve_script() {
  confirm_queue choose '0|reference-vm' '0|Continue to confirmation'
  confirm_queue confirm 0
  confirm_queue input '0|vda'
}

@test "apply --help succeeds without a terminal and without touching anything" {
  confirm_run_plain apply --help
  [ "$CONFIRM_STATUS" -eq 0 ]
  grep -qF 'Usage: install apply [--plan <file>] [--output <dir>]' "$STDOUT_PATH"
  grep -qF 'Normalized exit outcomes:' "$STDOUT_PATH"
  grep -qF 'Documentation: docs/procedures/install.md' "$STDOUT_PATH"
  [ ! -s "$STDERR_PATH" ]
  [ ! -s "${DOUBLE_STATE}/gum-calls.log" ]
}

@test "apply without an interactive terminal exits 2 before any prompt or discovery" {
  approve_script
  confirm_run_plain apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  grep -qF 'not an interactive terminal' "$STDERR_PATH"
  [ ! -e "$RUN_DIR" ]
  [ ! -s "${DOUBLE_STATE}/gum-calls.log" ]
  [ ! -s "${DOUBLE_STATE}/calls.log" ]
}

@test "apply refuses bypass options and unknown options before any prompt" {
  local option

  approve_script
  for option in --yes --non-interactive --assume-yes --bogus; do
    confirm_run_pty apply "$option" --output "$RUN_DIR"
    [ "$CONFIRM_STATUS" -eq 2 ]
    confirm_assert_output_contains "unsupported argument: ${option}"
    [ ! -e "$RUN_DIR" ]
  done
  [ ! -s "${DOUBLE_STATE}/gum-calls.log" ]
}

@test "apply rejects malformed arguments and an occupied output directory" {
  confirm_run_pty apply --plan
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_run_pty apply --plan "${TEST_ROOT}/missing.json"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_output_contains '--plan is not a file'
  mkdir -p "${TEST_ROOT}/occupied"
  printf '%s\n' keep > "${TEST_ROOT}/occupied/previous.txt"
  confirm_run_pty apply --output "${TEST_ROOT}/occupied"
  [ "$CONFIRM_STATUS" -eq 2 ]
  [ "$(find "${TEST_ROOT}/occupied" -mindepth 1 | wc -l)" -eq 1 ]
  [ ! -s "${DOUBLE_STATE}/gum-calls.log" ]
}

@test "a valid approval stops at the engine boundary with 2 and outcome approved" {
  local before

  approve_script
  before="$(confirm_root_manifest)"
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 approved
  confirm_assert_reason engine_not_available
  confirm_assert_output_contains 'installation engine is not part of this MirrorOS version'
  [ "$before" == "$(confirm_root_manifest)" ]
  [ -f "${RUN_DIR}/discovery/initial/target-facts.json" ]
  [ -f "${RUN_DIR}/discovery/final/target-facts.json" ]
  [ -f "${RUN_DIR}/plans/01/installation-plan.json" ]
  [ -f "${RUN_DIR}/plans/01/choices.json" ]
  confirm_json_assert "${RUN_DIR}/apply-run.json" "d.digests.length === 1 && d.target_id === 'reference-vm' && /2\\./.test(d.gum_version)"
  confirm_assert_private
  confirm_assert_log_plain
  [ ! -e "${CODE_ROOT}/install/engine/apply" ]
}

@test "choosing Cancel exits 3, rediscovers nothing, and still writes the records" {
  confirm_queue choose '0|reference-vm' '0|Cancel'
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  [ ! -e "${RUN_DIR}/discovery/final" ]
  confirm_assert_output_contains 'No changes were made'
  confirm_assert_private
}

@test "answering No or pressing Esc at the confirmation exits 3" {
  confirm_queue choose '0|reference-vm' '0|Continue to confirmation'
  confirm_queue confirm 1
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  [ ! -e "${RUN_DIR}/discovery/final" ]
  confirm_assert_gum_not_called '^input '
}

@test "Esc at the menu and Gum status 130 cancel with 3" {
  confirm_queue choose '0|reference-vm' '1'
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled

  rm -rf -- "$RUN_DIR"
  confirm_queue choose '0|reference-vm' '0|Continue to confirmation'
  confirm_queue confirm 130
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
}

@test "a real Ctrl+C during the review exits 3 with the records written" {
  confirm_queue choose '0|reference-vm' 'hang'
  CONFIRM_KEYS=('\003')
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
}

@test "a real Ctrl+C outside the interactive phase keeps 130 and writes no approval" {
  confirm_queue spin hang
  CONFIRM_KEYS=('\003')
  confirm_queue choose '0|reference-vm'
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 130 ]
  [ ! -e "${RUN_DIR}/approval-record.json" ]
}

@test "a mismatching device name exits 3 with confirmation_mismatch and no retry" {
  confirm_queue choose '0|reference-vm' '0|Continue to confirmation'
  confirm_queue confirm 0
  confirm_queue input '0|sda' '0|vda'
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  confirm_assert_reason confirmation_mismatch
  confirm_json_assert "${RUN_DIR}/approval-record.json" "d.reason === 'confirmation_mismatch'"
  [ ! -e "${RUN_DIR}/discovery/final" ]
  [ "$(grep -c '^input ' "${DOUBLE_STATE}/gum-calls.log")" -eq 1 ]
}

# Replaces one choice value inside a plan file without recomputing its digest.
tamper_plan() {
  node -e '
    const fs = require("node:fs");
    const plan = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    plan.choices.hostname.value = "tampered";
    fs.writeFileSync(process.argv[1], JSON.stringify(plan, null, 2) + "\n");
  ' "$1"
}

# A hook that swaps the fixture root for another raw fixture, as if the disk changed under the run.
swap_scenario_hook() {
  confirm_hook "$1" "find '${FIXTURE_ROOT}' -mindepth 1 -delete; node '${CONFIRM_DISCOVERY_SUPPORT}/build-root.mjs' '${CONFIRM_FIXTURES}/${2}.json' '${FIXTURE_ROOT}' '${DOUBLE_STATE}'"
}

@test "the target menu lists every target definition" {
  confirm_queue choose '0|reference-vm' '0|Cancel'
  confirm_run_pty apply --output "$RUN_DIR"
  confirm_assert_gum_called 'Choose the installation target (Esc cancels) framework-13-pro-amd reference-vm'
}

@test "editing regenerates the plan with a new digest and choices accumulate" {
  confirm_queue choose '0|reference-vm' '0|Edit a choice' '0|hostname' '0|Edit a choice' '0|user_name' '0|Continue to confirmation'
  confirm_queue input '0|laptop' '0|alice' '0|vda'
  confirm_queue confirm 0
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 approved
  confirm_json_assert "${RUN_DIR}/apply-run.json" "d.digests.length === 3 && new Set(d.digests).size === 3 && d.final_digest === d.digests[2]"
  confirm_json_assert "${RUN_DIR}/plans/03/choices.json" "d.hostname === 'laptop' && d.user_name === 'alice' && d.format_version === 1"
  confirm_json_assert "${RUN_DIR}/plans/02/choices.json" "d.hostname === 'laptop' && !('user_name' in d)"
  confirm_json_assert "${RUN_DIR}/plans/03/installation-plan.json" "d.choices.hostname.value === 'laptop' && d.choices.user_name.value === 'alice'"
  confirm_assert_output_contains 'Plan regenerated: user_name changed.'
  confirm_assert_private
}

@test "an invalid edit shows the reason, keeps the previous plan, and discards the attempt" {
  confirm_queue choose '0|reference-vm' '0|Edit a choice' '0|swapfile_size' '0|Cancel'
  confirm_queue input '0|99999999'
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_output_contains 'Next step:'
  confirm_assert_output_contains 'The edit was discarded; the previous plan stays.'
  confirm_json_assert "${RUN_DIR}/apply-run.json" "d.digests.length === 1"
  [ ! -e "${RUN_DIR}/plans/02" ]
}

@test "Esc inside an edit widget returns to the dashboard without cancelling" {
  confirm_queue choose '0|reference-vm' '0|Edit a choice' '0|hostname' '0|Continue to confirmation'
  confirm_queue input '1' '0|vda'
  confirm_queue confirm 0
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 approved
  confirm_json_assert "${RUN_DIR}/apply-run.json" "d.digests.length === 1"
}

@test "a target with several eligible disks asks for the disk before generating a plan" {
  confirm_scenario_two_disks
  confirm_queue choose '0|reference-vm' '0|/dev/vdb (32.0 GiB)' '0|Cancel'
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_gum_called 'Choose the target disk (Esc cancels)'
  confirm_json_assert "${RUN_DIR}/plans/01/choices.json" "d.target_disk === '/dev/vdb'"
  confirm_json_assert "${RUN_DIR}/plans/01/installation-plan.json" "d.target.disk.path === '/dev/vdb'"
}

@test "apply --plan reviews a copy of the plan and the original stays untouched" {
  confirm_make_plan
  cp -- "$PLAN_FILE" "${TEST_ROOT}/given.json"
  confirm_queue choose '0|Edit a choice' '0|hostname' '0|Continue to confirmation'
  confirm_queue input '0|laptop' '0|vda'
  confirm_queue confirm 0
  confirm_run_pty apply --plan "${TEST_ROOT}/given.json" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 approved
  cmp -- "$PLAN_FILE" "${TEST_ROOT}/given.json"
  cmp -- "$PLAN_FILE" "${RUN_DIR}/plans/01/installation-plan.json"
  confirm_json_assert "${RUN_DIR}/plans/01/choices.json" "d.format_version === 1"
  confirm_json_assert "${RUN_DIR}/plans/02/choices.json" "d.hostname === 'laptop'"
  confirm_assert_gum_not_called 'Choose the installation target'
}

@test "a tampered plan given with --plan is invalidated before any prompt" {
  confirm_make_plan
  tamper_plan "$PLAN_FILE"
  : > "${DOUBLE_STATE}/calls.log"
  approve_script
  confirm_run_pty apply --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason digest_mismatch
  confirm_assert_output_contains 'Next step: Regenerate and review the installation plan.'
  confirm_assert_gum_not_called '^(choose|confirm|input) '
  [ ! -s "${DOUBLE_STATE}/calls.log" ]
}

@test "a changed policy invalidates the plan before review" {
  confirm_make_plan
  node -e '
    const fs = require("node:fs");
    const policy = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    policy.policy.swapfile_size.value = 2048;
    fs.writeFileSync(process.argv[1], JSON.stringify(policy, null, 2) + "\n");
  ' "${CODE_ROOT}/install/plan/policy.json"
  confirm_run_pty apply --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason policy_changed
  confirm_assert_gum_not_called '^(choose|confirm|input) '
}

@test "a changed layout invalidates the plan before review" {
  confirm_make_plan
  confirm_scenario reference-vm-layout
  confirm_run_pty apply --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason target_layout_changed
  confirm_assert_gum_not_called '^(choose|confirm|input) '
}

@test "a layout change after confirmation invalidates the approval" {
  confirm_make_plan
  swap_scenario_hook input reference-vm-layout
  confirm_queue choose '0|Continue to confirmation'
  confirm_queue confirm 0
  confirm_queue input '0|vda'
  confirm_run_pty apply --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason target_layout_changed
  [ -f "${RUN_DIR}/discovery/final/target-facts.json" ]
  confirm_json_assert "${RUN_DIR}/approval-record.json" "d.reason === 'target_layout_changed'"
}

@test "a plan file changed after confirmation fails the digest re-check" {
  confirm_make_plan
  confirm_hook input "node -e 'const fs=require(\"node:fs\");const p=process.argv[1];const d=JSON.parse(fs.readFileSync(p,\"utf8\"));d.choices.hostname.value=\"tampered\";fs.writeFileSync(p,JSON.stringify(d,null,2)+\"\\n\")' '${RUN_DIR}/plans/01/installation-plan.json'"
  confirm_queue choose '0|Continue to confirmation'
  confirm_queue confirm 0
  confirm_queue input '0|vda'
  confirm_run_pty apply --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason digest_mismatch
}

@test "invalid facts block the run before any review" {
  confirm_scenario disks-none-eligible
  confirm_queue choose '0|reference-vm'
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 blocked
  confirm_assert_gum_not_called 'Choose how to proceed'
}

@test "a Gum major version other than 2 exits 6 and records that it is not qualified" {
  printf '%s\n' 'gum version 3.0.0 (double)' > "${DOUBLE_STATE}/version"
  approve_script
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 6 ]
  confirm_assert_run 6 failed
  confirm_assert_reason gum_not_qualified
  confirm_assert_output_contains 'is not qualified'
  confirm_assert_gum_not_called '^(choose|confirm|input) '
  [ ! -s "${DOUBLE_STATE}/calls.log" ]

  rm -rf -- "$RUN_DIR"
  : > "${DOUBLE_STATE}/version"
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 6 ]
  confirm_json_assert "${RUN_DIR}/apply-run.json" "!('gum_version' in d)"
}

@test "colored runs use gum confirm with the safe default" {
  approve_script
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_gum_called 'confirm --default=false --affirmative Yes, apply --negative No, cancel'
  confirm_assert_gum_called 'format --theme '
}

@test "NO_COLOR and TERM=dumb use the gum choose variant with the safe answer first" {
  local variable

  for variable in NO_COLOR=1 TERM=dumb; do
    rm -rf -- "$RUN_DIR"
    : > "${DOUBLE_STATE}/gum-calls.log"
    CONFIRM_ENV=("$variable")
    confirm_queue choose '0|reference-vm' '0|Continue to confirmation' '0|Yes, apply'
    confirm_queue input '0|vda'
    confirm_run_pty apply --output "$RUN_DIR"
    [ "$CONFIRM_STATUS" -eq 2 ]
    confirm_assert_run 2 approved
    confirm_assert_gum_not_called '^confirm '
    confirm_assert_gum_called "--cursor >  No, cancel Yes, apply"
  done

  rm -rf -- "$RUN_DIR"
  confirm_queue choose '0|reference-vm' '0|Continue to confirmation' '0|No, cancel'
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
}

@test "no secret is requested or recorded and no color escapes reach the log" {
  # Exported, not passed in the command line: the typescript header records the command.
  export MIRROROS_ROOT_PASSWORD="$CONFIRM_CANARY" ROOT_PASSWORD="$CONFIRM_CANARY"
  approve_script
  confirm_run_pty apply --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_no_canary
  confirm_assert_gum_not_called '--password'
  confirm_assert_log_plain
  confirm_assert_private
}
