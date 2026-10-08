load discovery-support

setup() {
  reference_setup
  reference_prepare_e2e
  reference_install_discovery_doubles
  cp -a -- "${REFERENCE_TEST_SOURCE_ROOT}/install" "${REFERENCE_TEST_SOURCE_ROOT}/hardware" \
    "${REFERENCE_TEST_SOURCE_ROOT}/targets" "${REFERENCE_REPOSITORY_ROOT}/"
  git -C "$REFERENCE_REPOSITORY_ROOT" add -A
  git -C "$REFERENCE_REPOSITORY_ROOT" -c user.name=Test -c user.email=test@example.invalid \
    -c commit.gpgsign=false commit -q -m embedded
  REFERENCE_HEAD="$(git -C "$REFERENCE_REPOSITORY_ROOT" rev-parse HEAD)"
  export REFERENCE_DISCOVERY_TARGET='reference-vm'
}

teardown() {
  reference_teardown
}

# The synthetic bundle is clean and built at the same commit as the test checkout.
use_matching_bundle() {
  reference_set_bundle_build "$REFERENCE_BUNDLE_DIR" "$REFERENCE_HEAD" false
}

@test "--help prints help and exits 0 without invoking any domain tool" {
  run "${REFERENCE_REPOSITORY_ROOT}/vm/reference/qualify-discovery" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'qualify-discovery'* ]]
  [[ "$output" == *'framework-target'* ]]
  [ ! -s "$REFERENCE_CALL_LOG" ]
}

@test "missing, unknown, or malformed arguments exit 2 before any run resource exists" {
  local -a invalid=(
    ''
    '--scenario'
    '--scenario unknown BUNDLE'
    '--scenario empty'
    '--scenario empty BUNDLE EXTRA'
    '--unknown --scenario empty BUNDLE'
    '--scenario empty --scenario layout BUNDLE'
  )
  local arguments

  for arguments in "${invalid[@]}"; do
    # shellcheck disable=SC2086 # Word splitting builds the argument vector.
    reference_invoke_discovery ${arguments//BUNDLE/$REFERENCE_BUNDLE_DIR}
    [ "$REFERENCE_COMMAND_STATUS" -eq 2 ]
  done
  [ ! -e "${REFERENCE_REPOSITORY_ROOT}/evidence" ]
  [ ! -e "${REFERENCE_REPOSITORY_ROOT}/build" ]
}

@test "the empty scenario qualifies, keeps private evidence, and records a counted run" {
  use_matching_bundle

  reference_invoke_discovery --scenario empty "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]

  local evidence
  evidence="$(reference_discovery_evidence_dir)"
  [ "$(reference_result_field status)" == '0' ]
  [ "$(reference_result_field scenario)" == 'empty' ]
  [ "$(reference_result_field target)" == 'reference-vm' ]
  [ "$(reference_result_field discovery.expected_exit)" == '0' ]
  [ "$(reference_result_field discovery.actual_exit)" == '0' ]
  [ "$(reference_result_field disk_identity.comparison)" == 'identical' ]
  [ "$(reference_result_field test_code.dirty)" == 'false' ]
  [ "$(reference_result_field test_code.commit)" == "$REFERENCE_HEAD" ]
  [ "$(reference_result_field development_overlay)" == 'false' ]
  [ "$(reference_result_field counted)" == 'true' ]
  [ "$(reference_result_field scans.nocloud)" == 'passed' ]
  [ "$(reference_result_field scans.evidence)" == 'passed' ]
  [ "$(stat -c '%a' "$evidence")" == '700' ]
  [ "$(stat -c '%a' "${evidence}/result.json")" == '600' ]
  [ "$(stat -c '%a' "${evidence}/target-facts.json")" == '600' ]
  [ -z "$(find "$evidence" -perm /077)" ]
  [ ! -e "${REFERENCE_REPOSITORY_ROOT}/build/reference-vm/${evidence##*/}" ]
  [[ "$(<"$REFERENCE_STDOUT_PATH")" == *'Evidence: '* ]]
  grep -Fq 'qemu-img compare' "$REFERENCE_CALL_LOG"
}

@test "the layout scenario builds a two-partition GPT without root and still qualifies" {
  use_matching_bundle

  reference_invoke_discovery --scenario layout "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
  [ "$(reference_result_field scenario)" == 'layout' ]
  [ "$(reference_result_field disk_identity.comparison)" == 'identical' ]
  grep -Fq 'sfdisk --quiet' "$REFERENCE_CALL_LOG"
  grep -Fq 'qemu-img convert -f raw -O qcow2' "$REFERENCE_CALL_LOG"
  [ "$(grep -c 'name="mirroros-' "${REFERENCE_CALL_LOG}.sfdisk-input")" -eq 2 ]
  grep -Fq 'label: gpt' "${REFERENCE_CALL_LOG}.sfdisk-input"
  ! grep -Eq '^(sudo|pkexec) ' "$REFERENCE_CALL_LOG"
  [ -z "$(find "${REFERENCE_REPOSITORY_ROOT}/build/reference-vm" -mindepth 1 -print 2>/dev/null)" ]
}

@test "the framework-target scenario expects exit 2 with invalid facts" {
  use_matching_bundle
  export REFERENCE_DISCOVERY_TARGET='framework-13-pro-amd' REFERENCE_DISCOVERY_EXIT=2

  reference_invoke_discovery --scenario framework-target "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
  [ "$(reference_result_field target)" == 'framework-13-pro-amd' ]
  [ "$(reference_result_field discovery.expected_exit)" == '2' ]
  [ "$(reference_result_field discovery.actual_exit)" == '2' ]
  [ "$(reference_result_field discovery.facts_validation)" == 'invalid' ]
  [ "$(reference_result_field discovery.reason_codes)" == 'identity_pending_capture' ]
  [ "$(reference_result_field counted)" == 'true' ]
}

@test "the plan scenario records both plans, the checks, private plan evidence, and a counted run" {
  use_matching_bundle
  export REFERENCE_PLAN_REPORT=1

  reference_invoke_discovery --scenario plan "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]

  local evidence
  evidence="$(reference_discovery_evidence_dir)"
  [ "$(reference_result_field scenario)" == 'plan' ]
  [ "$(reference_result_field plan.exits)" == '0,0,0,2' ]
  [ "$(reference_result_field plan.digests_differ)" == 'true' ]
  [ "$(reference_result_field plan.first_plan_identical)" == 'true' ]
  [ "$(reference_result_field plan.ok)" == 'true' ]
  [ "$(reference_result_field disk_identity.comparison)" == 'identical' ]
  [ "$(reference_result_field counted)" == 'true' ]
  [ -f "${evidence}/plan-default/installation-plan.json" ]
  [ -f "${evidence}/plan-edited/installation-plan.txt" ]
  [ -f "${evidence}/plan-invalid/plan-run.json" ]
  [ ! -e "${evidence}/plan-invalid/installation-plan.json" ]
  [ "$(stat -c '%a' "${evidence}/plan-default")" == '700' ]
  [ -z "$(find "$evidence" -perm /077)" ]
}

@test "the plan scenario fails with 4 when digests match, the first plan changes, or the invalid run succeeds" {
  use_matching_bundle
  export REFERENCE_PLAN_REPORT=1
  local variable

  local -A failed_check=(
    [REFERENCE_PLAN_SAME_DIGEST=1]='digests_differ'
    [REFERENCE_PLAN_TAMPER=1]='first_plan_identical'
    [REFERENCE_PLAN_INVALID_EXIT=0]='exits_as_expected'
  )

  for variable in 'REFERENCE_PLAN_SAME_DIGEST=1' 'REFERENCE_PLAN_TAMPER=1' 'REFERENCE_PLAN_INVALID_EXIT=0'; do
    rm -rf -- "${REFERENCE_REPOSITORY_ROOT}/evidence"
    export "$variable"
    reference_invoke_discovery --scenario plan "$REFERENCE_BUNDLE_DIR"
    unset "${variable%%=*}"
    [ "$REFERENCE_COMMAND_STATUS" -eq 4 ]
    [ "$(reference_result_field plan.ok)" == 'false' ]
    [ "$(reference_result_field "plan.${failed_check[$variable]}")" == 'false' ]
    [ "$(reference_result_field counted)" == 'false' ]
  done
}

@test "the plan scenario without a plan section in the report fails with 5" {
  use_matching_bundle

  reference_invoke_discovery --scenario plan "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 5 ]
  [ "$(reference_result_field counted)" == 'false' ]
}

@test "an unexpected discovery exit fails with 4 and is never counted" {
  use_matching_bundle
  export REFERENCE_DISCOVERY_TARGET='framework-13-pro-amd' REFERENCE_DISCOVERY_EXIT=0

  reference_invoke_discovery --scenario framework-target "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 4 ]
  [ "$(reference_result_field failed_stage)" == 'discovery-exit' ]
  [ "$(reference_result_field counted)" == 'false' ]
}

@test "a changed disk fails with 4 even when discovery met its expected exit" {
  use_matching_bundle
  export REFERENCE_COMPARE_STATUS=1

  reference_invoke_discovery --scenario empty "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 4 ]
  [ "$(reference_result_field failed_stage)" == 'disk-identity' ]
  [ "$(reference_result_field disk_identity.comparison)" == 'different' ]
  [ "$(reference_result_field counted)" == 'false' ]
}

@test "a comparison tool failure yields 5 and is never reported as identical" {
  use_matching_bundle
  export REFERENCE_COMPARE_STATUS=2

  reference_invoke_discovery --scenario empty "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 5 ]
  [ "$(reference_result_field disk_identity.comparison)" == 'error' ]
  [ "$(reference_result_field original_tool_statuses.disk_compare)" == '2' ]
}

@test "QEMU exiting before a report fails with 5 and the disk is still compared" {
  use_matching_bundle
  export REFERENCE_QEMU_MODE=exit

  reference_invoke_discovery --scenario empty "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 5 ]
  [ "$(reference_result_field failed_stage)" == 'qemu-exit' ]
  [ "$(reference_result_field discovery.actual_exit)" == 'null' ]
  [ "$(reference_result_field counted)" == 'false' ]
}

@test "the development overlay delivers the working tree and forces counted false" {
  use_matching_bundle

  reference_invoke_discovery --scenario empty --development-overlay "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
  [ "$(reference_result_field development_overlay)" == 'true' ]
  [ "$(reference_result_field counted)" == 'false' ]
  [[ "$(<"$REFERENCE_STDOUT_PATH")" == *'development overlay (not counted)'* ]]
}

@test "a dirty test checkout or a dirty or mismatched bundle is never counted" {
  use_matching_bundle
  printf 'untracked' > "${REFERENCE_REPOSITORY_ROOT}/untracked-file"
  reference_invoke_discovery --scenario empty "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
  [ "$(reference_result_field test_code.dirty)" == 'true' ]
  [ "$(reference_result_field counted)" == 'false' ]

  rm -rf -- "${REFERENCE_REPOSITORY_ROOT}/evidence" "${REFERENCE_REPOSITORY_ROOT}/untracked-file"
  reference_set_bundle_build "$REFERENCE_BUNDLE_DIR" "$REFERENCE_HEAD" true
  reference_invoke_discovery --scenario empty "$REFERENCE_BUNDLE_DIR"
  [ "$(reference_result_field artifact.build_dirty)" == 'true' ]
  [ "$(reference_result_field counted)" == 'false' ]

  rm -rf -- "${REFERENCE_REPOSITORY_ROOT}/evidence"
  reference_set_bundle_build "$REFERENCE_BUNDLE_DIR" "$(printf 'd%.0s' {1..40})" false
  reference_invoke_discovery --scenario empty "$REFERENCE_BUNDLE_DIR"
  [ "$(reference_result_field counted)" == 'false' ]
}

@test "evidence scan findings keep the run private and yield 2" {
  use_matching_bundle
  export REFERENCE_GITLEAKS_FAIL_ON='/evidence/'

  reference_invoke_discovery --scenario empty "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 2 ]
  [ "$(reference_result_field scans.evidence)" == 'findings' ]
  [ "$(reference_result_field counted)" == 'false' ]
}

@test "qualify-discovery never elevates privileges and leaves qualify-bootstrap untouched" {
  use_matching_bundle

  reference_invoke_discovery --scenario empty "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
  ! grep -Eq '^(sudo|pkexec) ' "$REFERENCE_CALL_LOG"
  cmp -- "${REFERENCE_TEST_SOURCE_ROOT}/vm/reference/qualify-bootstrap" \
    "${REFERENCE_REPOSITORY_ROOT}/vm/reference/qualify-bootstrap"
}
