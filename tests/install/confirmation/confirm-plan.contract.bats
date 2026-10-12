load support

setup() {
  confirm_setup
  confirm_scenario reference-vm-empty
}

teardown() {
  confirm_teardown
}

# The answers of the guided route up to the review, with every proposal accepted: welcome, machine check,
# then the configuration screens (disk, storage, timezone, language, formats, keyboard, root policy) and the
# inputs (swapfile size, hostname, username). The hibernation choice follows the storage layout, Enabled.
queue_to_review() {
  confirm_queue choose '0|Continue' '0|Continue' '0|/dev/vda (32G)' '0|ext4 + systemd-boot - Default' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)'
  confirm_queue input '0|4096' '0|mirroros-ref' '0|mirroros'
}

# After a review that chose Back: Esc back to the hibernation screen, keep it Enabled, answer the size, and walk forward again.
queue_back_to_swapfile() {
  confirm_queue choose '0|Back' '1' '1' '1' '1' '1' '0|Enabled'
  confirm_queue input '1' '1' "0|$1"
  confirm_queue choose '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)'
  confirm_queue input '0|mirroros-ref' '0|mirroros'
}

# The shortest approving run: review, confirmation, device name, and the password explanation.
approve_script() {
  queue_to_review
  confirm_queue choose '0|Continue to confirmation' '0|Return to shell'
  confirm_queue confirm 0
  confirm_queue input '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
}

# The approving run for an existing plan: welcome, machine check, review, and the password explanation.
approve_plan_script() {
  confirm_queue choose '0|Continue' '0|Continue' '0|Continue to confirmation' '0|Return to shell'
  confirm_queue confirm 0
  confirm_queue input '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
}

@test "the guided installer's own help succeeds without a terminal and without touching anything" {
  "${CODE_ROOT}/install/confirmation/confirm-plan" --help > "$STDOUT_PATH" 2> "$STDERR_PATH"
  grep -qF 'Usage: mirroros-install [--plan <file>] [--output <dir>]' "$STDOUT_PATH"
  grep -qF 'Normalized exit outcomes:' "$STDOUT_PATH"
  grep -qF 'Documentation: docs/procedures/install.md' "$STDOUT_PATH"
  [ ! -s "$STDERR_PATH" ]
  [ ! -s "${DOUBLE_STATE}/gum-calls.log" ]
}

@test "the installer without an interactive terminal exits 2 before any prompt or discovery" {
  approve_script
  confirm_run_plain
  [ "$CONFIRM_STATUS" -eq 2 ]
  grep -qF 'not an interactive terminal' "$STDERR_PATH"
  confirm_run_plain --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  grep -qF 'not an interactive terminal' "$STDERR_PATH"
  [ ! -e "$RUN_DIR" ]
  [ ! -s "${DOUBLE_STATE}/gum-calls.log" ]
  [ ! -s "${DOUBLE_STATE}/calls.log" ]
}

@test "bypass options, apply, and unknown options are refused before any prompt" {
  local option

  approve_script
  for option in --yes --non-interactive --assume-yes --bogus apply; do
    confirm_run_pty "$option"
    [ "$CONFIRM_STATUS" -eq 2 ]
    confirm_run_pty --output "$RUN_DIR" "$option"
    [ "$CONFIRM_STATUS" -eq 2 ]
    confirm_assert_output_contains "unsupported argument: ${option}"
    [ ! -e "$RUN_DIR" ]
  done
  [ ! -s "${DOUBLE_STATE}/gum-calls.log" ]
  [ ! -s "${DOUBLE_STATE}/calls.log" ]
}

@test "malformed arguments and an occupied output directory are rejected" {
  confirm_run_pty --plan
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_run_pty --plan "${TEST_ROOT}/missing.json"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_output_contains '--plan is not a file'
  mkdir -p "${TEST_ROOT}/occupied"
  printf '%s\n' keep > "${TEST_ROOT}/occupied/previous.txt"
  confirm_run_pty --output "${TEST_ROOT}/occupied"
  [ "$CONFIRM_STATUS" -eq 2 ]
  [ "$(find "${TEST_ROOT}/occupied" -mindepth 1 | wc -l)" -eq 1 ]
  [ ! -s "${DOUBLE_STATE}/gum-calls.log" ]
}

@test "a colorless request or an unsupported terminal type is rejected before discovery" {
  local variable

  approve_script
  for variable in NO_COLOR=1 TERM=dumb; do
    CONFIRM_ENV=("$variable")
    confirm_run_pty --output "$RUN_DIR"
    [ "$CONFIRM_STATUS" -eq 2 ]
    confirm_assert_output_contains 'outside the supported colored live console'
    [ ! -e "$RUN_DIR" ]
  done
  [ ! -s "${DOUBLE_STATE}/gum-calls.log" ]
  [ ! -s "${DOUBLE_STATE}/calls.log" ]
}

@test "a valid approval follows the guided route through the password and the engine and ends installed with 0" {
  approve_script
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.reasons.length === 0"
  confirm_json_assert "${RUN_DIR}/approval-record.json" "!('reason' in d)"
  confirm_assert_output_contains 'Installed MirrorOS in'
  confirm_assert_output_contains 'Base system installed. Installation postconditions are not verified in this version (Story 2.6).'
  confirm_json_assert "${RUN_DIR}/engine/engine-run.json" "d.outcome === 'installed' && d.exit_status === 0 && d.not_started.length === 0"
  confirm_json_assert "${RUN_DIR}/engine/engine-run.json" "d.plan_digest === JSON.parse(require('node:fs').readFileSync('${RUN_DIR}/plans/01/installation-plan.json', 'utf8')).digest.value"
  confirm_json_assert "${RUN_DIR}/engine/state.json" "d.status === 'installed'"
  [ -f "${RUN_DIR}/engine/engine.log" ]
  [ -f "${RUN_DIR}/discovery/initial/target-facts.json" ]
  [ -f "${RUN_DIR}/discovery/final/target-facts.json" ]
  [ -f "${RUN_DIR}/plans/01/installation-plan.json" ]
  [ -f "${RUN_DIR}/plans/01/installation-plan.txt" ]
  confirm_json_assert "${RUN_DIR}/plans/01/choices.json" "d.format_version === 3 && Object.keys(d).length === 1"
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.format_version === 4 && d.entry === 'guided' && d.digests.length === 1 && d.final_digest === d.digests[0] && /2\\./.test(d.gum_version)"
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.stages.join() === 'preparation,discovery_initial,plan,review,confirmation,password,discovery_final,engine'"
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.profile.status === 'matched' && d.profile.profile_id === 'reference-vm' && d.machine.architecture === 'x86_64'"
  confirm_json_assert "${RUN_DIR}/approval-record.json" "/^[0-9a-f]{64}$/.test(d.digest) && d.outcome === 'installed'"
  confirm_assert_gum_called 'confirm --default=false --affirmative Yes, erase --negative No Erase /dev/vda and apply plan '
  confirm_assert_gum_called 'Recognized machine: reference-vm'
  confirm_assert_gum_called 'input --password --show-help --prompt Password> '
  confirm_assert_gum_called 'input --password --show-help --prompt Confirm> '
  confirm_assert_private
  confirm_assert_log_plain
}

@test "accepted proposals keep their provenance and only a changed value becomes a choice" {
  confirm_queue choose '0|Continue' '0|Continue' '0|/dev/vda (32G)' '0|ext4 + systemd-boot - Default' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Continue to confirmation' '0|Return to shell'
  confirm_queue input '0|2048' '0|mirroros-ref' '0|mirroros' '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_queue confirm 0
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  confirm_json_assert "${RUN_DIR}/plans/01/choices.json" "d.format_version === 3 && d.swapfile_size === 2048 && Object.keys(d).length === 2"
  confirm_json_assert "${RUN_DIR}/plans/01/installation-plan.json" "d.choices.swapfile_size.source === 'choice' && d.choices.swapfile_size.value === 2048 && d.choices.lang.source === 'policy' && d.choices.hostname.source === 'override' && d.choices.hostname.value === 'mirroros-ref'"
}

@test "choosing Cancel at the machine check exits 3, rediscovers nothing, and still writes the records" {
  confirm_queue choose '0|Continue' '0|Cancel'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  [ ! -e "${RUN_DIR}/discovery/final" ]
  confirm_assert_output_contains 'No installation or disk operation was executed.'
  confirm_assert_private
}

@test "No, Esc, and Ctrl+C at the confirmation cancel with 3 and never ask for the device name" {
  local answer

  for answer in 1 130; do
    rm -rf -- "$RUN_DIR"
    : > "${DOUBLE_STATE}/gum-calls.log"
    queue_to_review
    confirm_queue choose '0|Continue to confirmation'
    confirm_queue confirm "$answer"
    confirm_run_pty --output "$RUN_DIR"
    [ "$CONFIRM_STATUS" -eq 3 ]
    confirm_assert_run 3 cancelled
    [ ! -e "${RUN_DIR}/discovery/final" ]
    [ "$(grep -c '^input ' "${DOUBLE_STATE}/gum-calls.log")" -eq 3 ]
  done
}

@test "Esc at the device name cancels with 3" {
  queue_to_review
  confirm_queue choose '0|Continue to confirmation'
  confirm_queue confirm 0
  confirm_queue input '1'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  [ ! -e "${RUN_DIR}/discovery/final" ]
}

@test "a mismatching device name exits 3 with confirmation_mismatch and no retry" {
  queue_to_review
  confirm_queue choose '0|Continue to confirmation'
  confirm_queue confirm 0
  confirm_queue input '0|sda' '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  confirm_assert_reason confirmation_mismatch
  confirm_json_assert "${RUN_DIR}/approval-record.json" "d.reason === 'confirmation_mismatch'"
  [ ! -e "${RUN_DIR}/discovery/final" ]
  [ "$(grep -c '^input ' "${DOUBLE_STATE}/gum-calls.log")" -eq 4 ]
}

@test "a real Ctrl+C during the review exits 3 with the records written" {
  queue_to_review
  confirm_queue choose 'hang'
  confirm_hook_call choose 10 "touch '${TEST_ROOT}/waiting'"
  CONFIRM_WAIT_FOR="${TEST_ROOT}/waiting"
  CONFIRM_KEYS=('\003')
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
}

@test "a real Ctrl+C during read-only discovery keeps 130 and writes no approval" {
  printf '#!/usr/bin/bash\n: > %q\nsleep 30\n' "${TEST_ROOT}/discovering" > "${CODE_ROOT}/install/discovery/discover"
  confirm_queue choose '0|Continue'
  CONFIRM_WAIT_FOR="${TEST_ROOT}/discovering"
  CONFIRM_KEYS=('\003')
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 130 ]
  [ ! -e "${RUN_DIR}/approval-record.json" ]
}

@test "Esc at a configuration screen goes back and keeps the confirmed answers" {
  confirm_queue choose '0|Continue' '0|Continue' '0|/dev/vda (32G)' '1' '0|/dev/vda (32G)' '0|ext4 + systemd-boot - Default' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Continue to confirmation' '0|Return to shell'
  confirm_queue input '0|4096' '0|mirroros-ref' '0|mirroros' '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_queue confirm 0
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  [ "$(grep -c 'Select install disk' "${DOUBLE_STATE}/gum-calls.log")" -eq 2 ]
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.digests.length === 1"
}

@test "an invalid value shows its reason and asks again without keeping it" {
  confirm_queue choose '0|Continue' '0|Continue' '0|/dev/vda (32G)' '0|ext4 + systemd-boot - Default' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Continue to confirmation' '0|Return to shell'
  confirm_queue input '0|100' '0|4096' '0|mirroros-ref' "0|${CONFIRM_CANARY}" '0|mirroros' '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_queue confirm 0
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  confirm_assert_gum_called 'Use a whole number from 512 to 4096 MiB.'
  confirm_assert_gum_called 'Use 1-32 characters, starting with a lowercase letter or underscore.'
  confirm_json_assert "${RUN_DIR}/plans/01/choices.json" "Object.keys(d).length === 1"
  confirm_assert_no_canary
}

@test "answers changed after the review regenerate a new numbered plan before confirmation" {
  queue_to_review
  queue_back_to_swapfile 2048
  confirm_queue choose '0|Continue to confirmation' '0|Return to shell'
  confirm_queue confirm 0
  confirm_queue input '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.digests.length === 2 && new Set(d.digests).size === 2 && d.final_digest === d.digests[1]"
  confirm_json_assert "${RUN_DIR}/plans/01/choices.json" "Object.keys(d).length === 1"
  confirm_json_assert "${RUN_DIR}/plans/02/choices.json" "d.swapfile_size === 2048"
  confirm_json_assert "${RUN_DIR}/plans/02/installation-plan.json" "d.choices.swapfile_size.value === 2048"
  confirm_assert_private
}

@test "an invalid combination keeps the last valid plan, shows its reason, and grants no approval" {
  confirm_scenario_memory 67108864
  queue_to_review
  queue_back_to_swapfile 65536
  confirm_queue choose '0|Cancel'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  confirm_assert_gum_called 'Phase: Plan generation'
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.digests.length === 1"
  [ -f "${RUN_DIR}/plans/01/installation-plan.json" ]
  [ ! -e "${RUN_DIR}/plans/02" ]
  [ ! -e "${RUN_DIR}/discovery/final" ]
  confirm_assert_gum_not_called '^confirm '
}

@test "Esc at the password returns to the review, discards the value, and asks for confirmation again" {
  queue_to_review
  confirm_queue choose '0|Continue to confirmation' '0|Continue to confirmation' '0|Return to shell'
  confirm_queue confirm 0 0
  confirm_queue input '0|vda' '1' '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  [ "$(grep -c '^confirm ' "${DOUBLE_STATE}/gum-calls.log")" -eq 2 ]
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.digests.length === 1"
}

@test "inspecting the complete plan returns to the review and grants no authorization" {
  queue_to_review
  confirm_queue choose '0|Inspect complete plan' '130'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  confirm_assert_gum_called 'pager'
  confirm_assert_gum_not_called '^confirm '
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.digests.length === 1 && d.stages.indexOf('confirmation') < 0"
}

@test "a machine with several eligible disks lists them and records the chosen disk" {
  confirm_scenario_two_disks
  confirm_queue choose '0|Continue' '0|Continue' '0|/dev/vdb (32G)' '0|ext4 + systemd-boot - Default' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Continue to confirmation' '0|Return to shell'
  confirm_queue input '0|4096' '0|mirroros-ref' '0|mirroros' '0|vdb' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_queue confirm 0
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  confirm_assert_gum_called '--header Select install disk /dev/vda (32G) /dev/vdb (32G)'
  confirm_json_assert "${RUN_DIR}/plans/01/choices.json" "d.target_disk === '/dev/vdb'"
  confirm_json_assert "${RUN_DIR}/plans/01/installation-plan.json" "d.target.disk.path === '/dev/vdb'"
  confirm_json_assert "${RUN_DIR}/approval-record.json" "d.disk.path === '/dev/vdb'"
}

@test "an unqualified machine is admitted as experimental with the same confirmation" {
  confirm_scenario_unqualified
  approve_script
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  confirm_assert_gum_called 'Experimental: this machine matches no known profile.'
  confirm_assert_gum_called 'Compatibility is not guaranteed and no support is promised.'
  confirm_assert_gum_not_called 'Recognized machine'
  [ "$(grep -c 'Experimental: this machine matches no known profile.' "${DOUBLE_STATE}/gum-calls.log")" -eq 2 ]
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.profile.status === 'unqualified' && !('profile_id' in d.profile)"
  confirm_json_assert "${RUN_DIR}/plans/01/installation-plan.json" "d.target.profile.status === 'unqualified' && d.warnings.some(w => w.code === 'machine_unqualified')"
  confirm_assert_gum_called 'confirm --default=false'
}

@test "--plan reviews a copy of the plan, the original stays untouched, and confirmation is fresh" {
  confirm_make_plan
  cp -- "$PLAN_FILE" "${TEST_ROOT}/given.json"
  approve_plan_script
  confirm_run_pty --plan "${TEST_ROOT}/given.json" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  cmp -- "$PLAN_FILE" "${TEST_ROOT}/given.json"
  cmp -- "$PLAN_FILE" "${RUN_DIR}/plans/01/installation-plan.json"
  confirm_json_assert "${RUN_DIR}/plans/01/choices.json" "d.format_version === 3 && Object.keys(d).length === 1"
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.entry === 'plan_file' && d.digests.length === 1"
  confirm_assert_gum_not_called 'Choose installation disk'
  confirm_assert_gum_called 'confirm --default=false'
}

@test "a tampered plan given with --plan is invalidated before any prompt" {
  confirm_make_plan
  node -e '
    const fs = require("node:fs");
    const plan = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    plan.choices.hostname.value = "tampered";
    fs.writeFileSync(process.argv[1], JSON.stringify(plan, null, 2) + "\n");
  ' "$PLAN_FILE"
  : > "${DOUBLE_STATE}/calls.log"
  approve_plan_script
  confirm_run_pty --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason digest_mismatch
  confirm_assert_output_contains 'Next step: Regenerate and review the installation plan.'
  confirm_assert_gum_not_called '^(choose|confirm|input) '
  [ ! -s "${DOUBLE_STATE}/calls.log" ]
}

@test "a plan of an earlier format is rejected with regeneration guidance and is not migrated" {
  cp -- "${CONFIRM_SOURCE_ROOT}/tests/fixtures/plan/invalid/plan_format_unsupported--version-1.json" "${TEST_ROOT}/old-plan.json"
  cp -- "${TEST_ROOT}/old-plan.json" "${TEST_ROOT}/old-plan.before"
  confirm_run_pty --plan "${TEST_ROOT}/old-plan.json" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason plan_format_unsupported
  confirm_assert_output_contains 'Next step: Regenerate and review the installation plan.'
  cmp -- "${TEST_ROOT}/old-plan.json" "${TEST_ROOT}/old-plan.before"
  confirm_assert_gum_not_called '^(choose|confirm|input) '
}

@test "a changed policy invalidates the plan before review" {
  confirm_make_plan
  node -e '
    const fs = require("node:fs");
    const policy = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    policy.policy.hibernation.value = false;
    fs.writeFileSync(process.argv[1], JSON.stringify(policy, null, 2) + "\n");
  ' "${CODE_ROOT}/install/plan/policy.json"
  confirm_queue choose '0|Continue'
  confirm_run_pty --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason policy_changed
  confirm_assert_gum_not_called '^(confirm|input) '
  confirm_assert_gum_not_called 'Review navigation'
}

@test "a changed layout invalidates the plan before review" {
  confirm_make_plan
  confirm_scenario reference-vm-layout
  confirm_queue choose '0|Continue'
  confirm_run_pty --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason target_layout_changed
  confirm_assert_gum_not_called 'Review navigation'
}

@test "a changed machine identity invalidates the plan before review" {
  confirm_make_plan
  confirm_scenario_unqualified
  confirm_queue choose '0|Continue'
  confirm_run_pty --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason machine_identity_changed
  confirm_assert_reason profile_binding_changed
  confirm_assert_gum_not_called 'Review navigation'
}

@test "a changed detected memory invalidates the plan before review" {
  confirm_make_plan
  confirm_scenario_memory 8388608
  confirm_queue choose '0|Continue'
  confirm_run_pty --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason machine_identity_changed
  confirm_assert_gum_not_called 'Review navigation'
}

@test "a changed or missing configuration asset invalidates the plan before review" {
  local asset="${CODE_ROOT}/install/plan/assets/usr/lib/sysctl.d/60-mirroros-memory.conf"

  confirm_make_plan
  printf '%s\n' '# changed after the plan' >> "$asset"
  confirm_queue choose '0|Continue'
  confirm_run_pty --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason configuration_assets_changed
  confirm_assert_gum_not_called 'Review navigation'
  rm -rf -- "$RUN_DIR" "$asset"
  confirm_queue choose '0|Continue'
  confirm_run_pty --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason configuration_assets_changed
}

@test "missing detected memory blocks the guided run with 2 and memory_unavailable before any choice" {
  confirm_scenario_memory ''
  confirm_queue choose '0|Continue' '0|Continue'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 blocked
  confirm_assert_reason memory_unavailable
  confirm_assert_gum_not_called 'Hibernation'
  confirm_assert_gum_not_called '^(confirm|input) '
  [ ! -e "${RUN_DIR}/plans/01" ]
}

@test "disabled hibernation asks no size, plans no swapfile, and the review says so without another dialog" {
  confirm_queue choose '0|Continue' '0|Continue' '0|/dev/vda (32G)' '0|ext4 + systemd-boot - Default' '0|Disabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Continue to confirmation' '0|Return to shell'
  confirm_queue input '0|mirroros-ref' '0|mirroros' '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_queue confirm 0
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  confirm_assert_gum_not_called 'Swapfile size'
  confirm_assert_gum_called 'Hibernation is disabled: no swapfile will be created.'
  confirm_json_assert "${RUN_DIR}/plans/01/installation-plan.json" "d.choices.hibernation.value === false && !('swapfile_size' in d.choices) && !d.operations.some(o => o.kind === 'create_swapfile')"
  confirm_assert_private
}

@test "a reduced swapfile size keeps its warning in the review and the plan" {
  confirm_queue choose '0|Continue' '0|Continue' '0|/dev/vda (32G)' '0|ext4 + systemd-boot - Default' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Back' '1' '1' '1' '1' '1' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Continue to confirmation' '0|Return to shell'
  confirm_queue input '0|2048' '0|mirroros-ref' '0|mirroros' '1' '1' '0|2048' '0|mirroros-ref' '0|mirroros' '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_queue confirm 0
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  confirm_assert_gum_called 'Below detected memory: hibernation may be unavailable'
  confirm_json_assert "${RUN_DIR}/plans/01/installation-plan.json" "d.choices.swapfile_size.value === 2048 && d.warnings.some(w => w.code === 'swapfile_below_ram')"
}

@test "disabling and re-enabling hibernation proposes the memory-based size again" {
  confirm_queue choose '0|Continue' '0|Continue' '0|/dev/vda (32G)' '0|ext4 + systemd-boot - Default' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Back' '1' '1' '1' '1' '1' '0|Disabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Back' '1' '1' '1' '1' '1' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Continue to confirmation' '0|Return to shell'
  confirm_queue input '0|2048' '0|mirroros-ref' '0|mirroros' '1' '1' '0|mirroros-ref' '0|mirroros' '1' '1' '0|4096' '0|mirroros-ref' '0|mirroros' '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_queue confirm 0
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  [ "$(grep -c -- '--value 4096' "${DOUBLE_STATE}/gum-calls.log")" -ge 2 ]
  [ "$(grep -c -- '--value 2048' "${DOUBLE_STATE}/gum-calls.log")" -eq 0 ]
  confirm_json_assert "${RUN_DIR}/plans/03/installation-plan.json" "d.choices.hibernation.value === true && d.choices.swapfile_size.value === 4096"
}

@test "Esc at the swapfile size returns to the hibernation choice" {
  confirm_queue choose '0|Continue' '0|Continue' '0|/dev/vda (32G)' '0|ext4 + systemd-boot - Default' '0|Enabled' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Continue to confirmation' '0|Return to shell'
  confirm_queue input '1' '0|4096' '0|mirroros-ref' '0|mirroros' '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_queue confirm 0
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  [ "$(grep -c -- '--header Hibernation' "${DOUBLE_STATE}/gum-calls.log")" -eq 2 ]
}

# A hook that swaps the fixture root for another raw fixture, as if the disk changed under the run.
swap_scenario_hook() {
  confirm_hook "$1" "find '${FIXTURE_ROOT}' -mindepth 1 -delete; node '${CONFIRM_DISCOVERY_SUPPORT}/build-root.mjs' '${CONFIRM_FIXTURES}/${2}.json' '${FIXTURE_ROOT}' '${DOUBLE_STATE}'"
}

@test "a layout change after confirmation invalidates the approval with 2 and target_layout_changed" {
  confirm_make_plan
  swap_scenario_hook input reference-vm-layout
  approve_plan_script
  confirm_run_pty --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason target_layout_changed
  [ -f "${RUN_DIR}/discovery/final/target-facts.json" ]
  confirm_json_assert "${RUN_DIR}/approval-record.json" "d.reason === 'target_layout_changed'"
  confirm_assert_output_contains 'Next step: Regenerate and review the installation plan.'
}

@test "a plan file changed after confirmation fails the digest re-check" {
  confirm_make_plan
  confirm_hook input "node -e 'const fs=require(\"node:fs\");const p=process.argv[1];const d=JSON.parse(fs.readFileSync(p,\"utf8\"));d.choices.hostname.value=\"tampered\";fs.writeFileSync(p,JSON.stringify(d,null,2)+\"\\n\")' '${RUN_DIR}/plans/01/installation-plan.json'"
  approve_plan_script
  confirm_run_pty --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 invalidated
  confirm_assert_reason digest_mismatch
}

@test "invalid facts block the run before any configuration screen" {
  confirm_scenario disks-none-eligible
  confirm_queue choose '0|Continue'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 blocked
  confirm_assert_gum_called 'Phase: discovery_initial'
  confirm_assert_gum_not_called '--header Machine check'
  [ ! -e "${RUN_DIR}/plans/01" ]
}

@test "a Gum major version other than 2 exits 6 and records that it is not qualified" {
  printf '%s\n' 'gum version 3.0.0 (double)' > "${DOUBLE_STATE}/version"
  approve_script
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 6 ]
  confirm_assert_run 6 failed
  confirm_assert_reason gum_not_qualified
  confirm_assert_output_contains 'is not qualified'
  confirm_assert_gum_not_called '^(choose|confirm|input) '
  [ ! -s "${DOUBLE_STATE}/calls.log" ]

  rm -rf -- "$RUN_DIR"
  : > "${DOUBLE_STATE}/version"
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 6 ]
  confirm_json_assert "${RUN_DIR}/install-run.json" "!('gum_version' in d)"
}

@test "a failed network check offers help and retry without bypass, and never asks for credentials" {
  cp -- "${DOUBLE_STATE}/route4" "${DOUBLE_STATE}/route4.saved"
  rm -f -- "${DOUBLE_STATE}/route4" "${DOUBLE_STATE}/route6"
  confirm_queue choose '0|Continue' '0|Wi-Fi' '0|Show connection instructions' '0|Retry connection check' '0|Back' '0|Cancel'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  confirm_assert_gum_called 'Configure Wi-Fi with iwctl in another live console'
  confirm_assert_gum_called 'pager'
  confirm_assert_gum_not_called '^input '
  grep -qF 'live_network_not_ready' "${RUN_DIR}/install.log"
  ! grep -q '^curl ' "${DOUBLE_STATE}/calls.log"
  [ ! -e "${RUN_DIR}/discovery/initial" ]
}

@test "a network that becomes ready lets the guided route continue" {
  cp -- "${DOUBLE_STATE}/route4" "${DOUBLE_STATE}/route4.saved"
  rm -f -- "${DOUBLE_STATE}/route4" "${DOUBLE_STATE}/route6"
  confirm_hook_call choose 3 "cp '${DOUBLE_STATE}/route4.saved' '${DOUBLE_STATE}/route4'"
  confirm_queue choose '0|Continue' '0|Ethernet' '0|Retry connection check' '0|Cancel'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  confirm_assert_gum_called 'Connect a network cable, then retry the connection check.'
  [ -d "${RUN_DIR}/discovery/initial" ]
  grep -qF 'live_network_not_ready' "${RUN_DIR}/install.log"
}

@test "a clock that is not synchronized waits a bounded time, then offers retry or cancellation" {
  local first_curl last_sleep

  printf '%s\n' no > "${DOUBLE_STATE}/ntp"
  confirm_hook_call choose 2 "printf '%s\n' yes > '${DOUBLE_STATE}/ntp'"
  confirm_queue choose '0|Continue' '0|Retry clock check' '0|Continue' '0|/dev/vda (32G)' '0|ext4 + systemd-boot - Default' '0|Enabled' \
    '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' '0|Locked (default)' \
    '0|Continue to confirmation' '0|Return to shell'
  confirm_queue input '0|4096' '0|mirroros-ref' '0|mirroros' '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_queue confirm 0
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  confirm_assert_gum_called 'Accurate time is needed to verify secure connections and package signatures.'
  confirm_assert_gum_not_called 'Ethernet'
  [ "$(grep -c '^sleep 1$' "${DOUBLE_STATE}/calls.log")" -eq 60 ]
  [ "$(grep -c '^timedatectl ' "${DOUBLE_STATE}/calls.log")" -eq 62 ]
  grep -qF 'live_clock_not_ready' "${RUN_DIR}/install.log"
  # The HTTPS check runs only after the clock was reported synchronized.
  first_curl="$(grep -n '^curl ' "${DOUBLE_STATE}/calls.log" | head -n 1 | cut -d: -f1)"
  last_sleep="$(grep -n '^sleep 1$' "${DOUBLE_STATE}/calls.log" | tail -n 1 | cut -d: -f1)"
  [ "$first_curl" -gt "$last_sleep" ]
}

@test "cancelling at the clock screen exits 3 and never bypasses TLS" {
  printf '%s\n' no > "${DOUBLE_STATE}/ntp"
  confirm_queue choose '0|Continue' '0|Cancel'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  [ "$(grep -c '^sleep 1$' "${DOUBLE_STATE}/calls.log")" -eq 60 ]
  ! grep -q '^curl ' "${DOUBLE_STATE}/calls.log"
  [ ! -e "${RUN_DIR}/discovery/initial" ]
  ! grep -rqE -- '--insecure|-k ' "${DOUBLE_STATE}/calls.log"
}

@test "an unreadable clock state is an unexpected failure with the original status retained" {
  printf '%s\n' 1 > "${DOUBLE_STATE}/ntp_status"
  confirm_queue choose '0|Continue'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 5 ]
  confirm_assert_run 5 failed
  confirm_assert_reason stage_failed
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.reasons[0].child_exit_status === 5"
}

@test "the live keyboard change stays in the live session and does not alter the installed choices" {
  confirm_queue choose '0|Change installation keyboard layout' '0|Spanish (ES)' '0|Continue' '0|Continue' '0|/dev/vda (32G)' \
    '0|ext4 + systemd-boot - Default' '0|Enabled' '0|Europe/Madrid' '0|English (US)' '0|Follow system language' '0|English (US)' \
    '0|Locked (default)' '0|Continue to confirmation' '0|Return to shell'
  confirm_queue input '0|4096' '0|mirroros-ref' '0|mirroros' '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_queue confirm 0
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  grep -qx 'loadkeys es' "${DOUBLE_STATE}/calls.log"
  confirm_json_assert "${RUN_DIR}/plans/01/installation-plan.json" "d.choices.console_keymap.value === 'us' && d.choices.console_keymap.source === 'policy'"
  confirm_json_assert "${RUN_DIR}/plans/01/choices.json" "Object.keys(d).length === 1"
}

@test "an unexpected phase failure stops with its status and retained diagnostics" {
  printf '#!/usr/bin/bash\nprintf "boom diagnostic\\n" >&2\nexit 77\n' > "${CODE_ROOT}/install/discovery/discover"
  confirm_queue choose '0|Continue'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 5 ]
  confirm_assert_run 5 failed
  confirm_assert_reason stage_failed
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.reasons[0].child_exit_status === 77"
  grep -qF 'boom diagnostic' "${RUN_DIR}/install.log"
  confirm_assert_gum_called 'Phase: discovery_initial'
  confirm_assert_log_plain
  confirm_assert_private
}

@test "the password reaches only the stdin of chpasswd and no record, log, argument, environment, or terminal output" {
  # An unrelated secret in the environment never reaches a record either. It is exported, not passed in the
  # command line: the typescript header records the command.
  export MIRROROS_ROOT_PASSWORD='PLANTED-ENV-SECRET-0002' ROOT_PASSWORD='PLANTED-ENV-SECRET-0002'
  approve_script
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  confirm_assert_no_canary
  ! grep -rFq -- 'PLANTED-ENV-SECRET-0002' "$RUN_DIR" "$STDOUT_PATH" "$TYPESCRIPT"
  grep -qxF "mirroros:${CONFIRM_PASSWORD}" "${DOUBLE_STATE}/chroot-stdin.log"
  [ "$(grep -cF "$CONFIRM_PASSWORD" "${DOUBLE_STATE}/chroot-stdin.log")" -eq 1 ]
  [ -s "${DOUBLE_STATE}/observed.log" ]
  ! grep -qF "$CONFIRM_PASSWORD" "${DOUBLE_STATE}/observed.log"
  ! grep -qF "$CONFIRM_PASSWORD" "${DOUBLE_STATE}/gum-calls.log" "${DOUBLE_STATE}/calls.log"
  confirm_assert_log_plain
  confirm_assert_private
}

@test "a blank or mismatching password asks both fields again with no attempt limit" {
  queue_to_review
  confirm_queue choose '0|Continue to confirmation' '0|Return to shell'
  confirm_queue confirm 0
  confirm_queue input '0|vda' '0' '0|x' '0|first' '0|second' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  confirm_assert_gum_called "Password can't be blank"
  confirm_assert_gum_called "Passwords didn't match"
  [ "$(grep -c '^input --password' "${DOUBLE_STATE}/gum-calls.log")" -eq 6 ]
  grep -qxF "mirroros:${CONFIRM_PASSWORD}" "${DOUBLE_STATE}/chroot-stdin.log"
  ! grep -qxF 'mirroros:first' "${DOUBLE_STATE}/chroot-stdin.log"
  confirm_assert_no_canary
}

@test "Ctrl+C at the password cancels with 3 and never starts the engine" {
  queue_to_review
  confirm_queue choose '0|Continue to confirmation'
  confirm_queue confirm 0
  confirm_queue input '0|vda' '130'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  [ ! -e "${RUN_DIR}/engine" ]
  [ ! -e "${RUN_DIR}/discovery/final" ]
  ! grep -qE '^(wipefs|sfdisk|pacstrap) ' "${DOUBLE_STATE}/calls.log"
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.stages.join() === 'preparation,discovery_initial,plan,review,confirmation,password'"
  confirm_assert_no_canary
}

@test "a ready keyring draws no screen, and a keyring that becomes ready after the wait lets the route continue" {
  approve_script
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_gum_not_called 'keyring'
  [ "$(grep -c '^sleep 1$' "${DOUBLE_STATE}/calls.log")" -eq 0 ]
  rm -rf -- "$RUN_DIR"
  : > "${DOUBLE_STATE}/gum-calls.log"
  : > "${DOUBLE_STATE}/calls.log"
  rm -f -- "${DOUBLE_STATE}"/*.queue "${DOUBLE_STATE}"/*.count
  : > "${DOUBLE_STATE}/keyring-not-ready"
  confirm_hook_call choose 2 "rm -f '${DOUBLE_STATE}/keyring-not-ready'"
  confirm_queue choose '0|Continue' '0|Retry keyring check' '0|Cancel'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  confirm_assert_gum_called 'Waiting for the package keyring to be initialized...'
  confirm_assert_gum_called 'Package signatures cannot be verified until the keyring is ready.'
  [ "$(grep -c '^sleep 1$' "${DOUBLE_STATE}/calls.log")" -eq 600 ]
  grep -qF 'live_keyring_not_ready' "${RUN_DIR}/install.log"
  [ -d "${RUN_DIR}/discovery/initial" ]
}

@test "a keyring that never becomes ready offers cancellation before any discovery, confirmation, or password" {
  : > "${DOUBLE_STATE}/keyring-not-ready"
  confirm_queue choose '0|Continue' '0|Cancel'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_run 3 cancelled
  [ "$(grep -c '^sleep 1$' "${DOUBLE_STATE}/calls.log")" -eq 600 ]
  [ ! -e "${RUN_DIR}/discovery/initial" ]
  confirm_assert_gum_not_called '^(confirm|input) '
  ! grep -qE '^(wipefs|sfdisk|pacstrap) ' "${DOUBLE_STATE}/calls.log"
}

@test "a failed keyring service offers retry at once without the long wait" {
  printf '%s\n' failed > "${DOUBLE_STATE}/keyring-failed"
  confirm_queue choose '0|Continue' '0|Cancel'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  confirm_assert_gum_called 'Package keyring not ready'
  [ "$(grep -c '^sleep 1$' "${DOUBLE_STATE}/calls.log")" -eq 0 ]
}

@test "a second run exits 2 with install_already_running on stderr only and touches nothing" {
  exec 9> "${RUN_ROOT}/install.lock"
  flock -n 9
  mkdir -p "${RUN_ROOT}/target"
  printf '%s\n' "${RUN_ROOT}/target" > "${DOUBLE_STATE}/mounted.list"
  confirm_run_pty --output "$RUN_DIR"
  exec 9>&-
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_output_contains 'install_already_running'
  [ ! -e "$RUN_DIR" ]
  [ ! -s "${DOUBLE_STATE}/gum-calls.log" ]
  ! grep -q '^umount ' "${DOUBLE_STATE}/calls.log"
  [ "$(< "${DOUBLE_STATE}/mounted.list")" = "${RUN_ROOT}/target" ]
}

@test "the lock is released after success, cancellation, and failure" {
  approve_script
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  flock -n "${RUN_ROOT}/install.lock" true
  rm -rf -- "$RUN_DIR"
  confirm_queue choose '130'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  flock -n "${RUN_ROOT}/install.lock" true
  rm -rf -- "$RUN_DIR"
  printf '%s\n' 1 > "${DOUBLE_STATE}/fail.pacstrap"
  approve_script
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 5 ]
  flock -n "${RUN_ROOT}/install.lock" true
}

@test "the start-of-run cleanup unmounts only the engine's own mount point and logs it" {
  mkdir -p "${RUN_ROOT}/target"
  printf '%s\n' "${RUN_ROOT}/target" "/elsewhere/other" > "${DOUBLE_STATE}/mounted.list"
  confirm_queue choose '130'
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 3 ]
  [ "$(grep -c '^umount ' "${DOUBLE_STATE}/calls.log")" -eq 1 ]
  grep -q "^umount -R -- ${RUN_ROOT}/target\$" "${DOUBLE_STATE}/calls.log"
  [ "$(< "${DOUBLE_STATE}/mounted.list")" = '/elsewhere/other' ]
  grep -qF 'start-of-run cleanup: the engine mount point was unmounted' "${RUN_DIR}/install.log"
}

@test "a plan of another code identity is blocked before review and no confirmation or password is requested" {
  confirm_make_plan
  printf '{\n  "commit": "%s",\n  "dirty": false\n}\n' bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb > "${CODE_ROOT}/identity.json"
  confirm_run_pty --plan "$PLAN_FILE" --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 blocked
  confirm_assert_reason engine_version_mismatch
  confirm_assert_gum_not_called '^(choose|confirm|input) '
  confirm_assert_gum_called 'Generate a new plan with this artifact'
  [ ! -e "${RUN_DIR}/engine" ]
  [ ! -e "${RUN_DIR}/plans/01" ]
}

@test "an engine failure stops with 5, keeps the original status, and shows the stop screen and its menu" {
  printf '%s\n' 1 > "${DOUBLE_STATE}/fail.pacstrap"
  approve_script
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 5 ]
  confirm_assert_run 5 failed
  confirm_assert_reason stage_failed
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.reasons[0].operation === 'install_packages' && d.reasons[0].child_exit_status === 1 && d.stages.at(-1) === 'engine'"
  confirm_json_assert "${RUN_DIR}/engine/engine-run.json" "d.outcome === 'failed' && d.failed_operation.id === 'install_packages' && d.completed.includes('wipe_disk_signatures')"
  confirm_assert_gum_called 'MirrorOS installation stopped'
  confirm_assert_gum_called 'Failed operation: install_packages'
  confirm_assert_gum_called 'The disk was partially modified and installation did not complete.'
  confirm_assert_gum_called "Run directory: ${RUN_DIR}"
  confirm_assert_gum_called 'View full log Return to shell Restart Power off'
  confirm_assert_output_contains 'pacstrap: simulated failure'
  ! grep -qE '^systemctl (reboot|poweroff)' "${DOUBLE_STATE}/calls.log"
  confirm_assert_gum_not_called 'Installed MirrorOS'
  confirm_assert_no_canary
  confirm_assert_private
}

@test "the failure menu shows the full log, and restarts or powers off only when chosen" {
  printf '%s\n' 1 > "${DOUBLE_STATE}/fail.pacstrap"
  queue_to_review
  confirm_queue choose '0|Continue to confirmation' '0|View full log' '0|Power off'
  confirm_queue confirm 0
  confirm_queue input '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 5 ]
  confirm_assert_gum_called 'pager'
  grep -qx 'systemctl poweroff' "${DOUBLE_STATE}/calls.log"
  ! grep -qx 'systemctl reboot' "${DOUBLE_STATE}/calls.log"
  confirm_assert_run 5 failed
}

@test "the success menu restarts only when Restart now is chosen" {
  queue_to_review
  confirm_queue choose '0|Continue to confirmation' '0|Restart now'
  confirm_queue confirm 0
  confirm_queue input '0|vda' "0|$CONFIRM_PASSWORD" "0|$CONFIRM_PASSWORD"
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 0 ]
  confirm_assert_run 0 installed
  grep -qx 'systemctl reboot' "${DOUBLE_STATE}/calls.log"
}

@test "an engine pre-check stop before any destructive operation is blocked with 2 and leaves the disk untouched" {
  confirm_hook_call input 6 "touch '${DOUBLE_STATE}/keyring-not-ready'"
  approve_script
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 2 ]
  confirm_assert_run 2 blocked
  confirm_assert_reason live_keyring_not_ready
  confirm_assert_gum_called 'Phase: Installation engine'
  ! grep -qE '^(wipefs|sfdisk|mkfs.fat|mkfs.ext4|pacstrap) ' "${DOUBLE_STATE}/calls.log"
  confirm_json_assert "${RUN_DIR}/engine/engine-run.json" "d.outcome === 'blocked' && d.exit_status === 2 && d.completed.length === 0"
  confirm_assert_gum_not_called 'MirrorOS installation stopped'
  confirm_assert_no_canary
}

@test "a real Ctrl+C during the engine is forwarded: the engine cleans up and the run ends failed with 130" {
  : > "${DOUBLE_STATE}/pacstrap-hang"
  approve_script
  CONFIRM_WAIT_FOR="${DOUBLE_STATE}/pacstrap-started"
  CONFIRM_KEYS=('\003')
  confirm_run_pty --output "$RUN_DIR"
  [ "$CONFIRM_STATUS" -eq 130 ]
  confirm_assert_run 130 failed
  confirm_assert_reason engine_interrupted
  confirm_json_assert "${RUN_DIR}/engine/engine-run.json" "d.outcome === 'failed' && d.exit_status === 130 && d.reasons[0].code === 'engine_interrupted'"
  grep -q '^umount ' "${DOUBLE_STATE}/calls.log"
  confirm_assert_gum_called 'MirrorOS installation stopped'
  confirm_assert_no_canary
}
