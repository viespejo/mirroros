PLAN_TESTS_DIR="${BATS_TEST_DIRNAME}"
PLAN_SOURCE_ROOT="$(cd -- "${PLAN_TESTS_DIR}/../../.." && pwd -P)"
PLAN_CANARY='PLANTED-PLAN-SECRET-0001'

setup() {
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mirroros plan.XXXXXX")"
  CODE_ROOT="${TEST_ROOT}/embedded code"
  DOUBLE_STATE="${TEST_ROOT}/double state"
  DOUBLE_BIN="${TEST_ROOT}/double bin"
  WORK_DIR="${TEST_ROOT}/work directory"
  STDOUT_PATH="${TEST_ROOT}/stdout.log"
  STDERR_PATH="${TEST_ROOT}/stderr.log"
  mkdir -p "$CODE_ROOT/operations/lib" "$DOUBLE_STATE" "$DOUBLE_BIN" "$WORK_DIR"
  cp -p "${PLAN_SOURCE_ROOT}/operations/install" "${CODE_ROOT}/operations/install"
  cp -p "${PLAN_SOURCE_ROOT}/operations/lib/lifecycle-discovery.sh" "${CODE_ROOT}/operations/lib/lifecycle-discovery.sh"
  cp -a "${PLAN_SOURCE_ROOT}/install" "${CODE_ROOT}/install"
  cp -a "${PLAN_SOURCE_ROOT}/targets" "${CODE_ROOT}/targets"
  for tool_name in sudo pkexec doas su; do
    ln -s "${PLAN_SOURCE_ROOT}/tests/install/discovery/doubles/elevation" "${DOUBLE_BIN}/${tool_name}"
  done
  FACTS="${WORK_DIR}/target-facts.json"
  make_facts default "$FACTS"
}

teardown() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" ]]; then
    rm -rf -- "$TEST_ROOT"
  fi
}

# Writes a facts variant: default, unqualified, two-disks, status-invalid, or format-1.
make_facts() {
  node --input-type=module -e '
    import { writeFileSync } from "node:fs";
    import { pathToFileURL } from "node:url";
    const helpers = await import(pathToFileURL(process.argv[1]).href);
    let document = helpers.facts();
    if (process.argv[2] === "unqualified") document = helpers.unqualifiedFacts();
    if (process.argv[2] === "two-disks") document = helpers.secondEligibleDisk(document);
    if (process.argv[2] === "status-invalid") document.validation.status = "invalid";
    if (process.argv[2] === "format-1") document.format_version = 1;
    if (process.argv[2] === "no-memory") document = helpers.withMemory(document, undefined);
    if (process.argv[2] === "memory-80g") document = helpers.withMemory(document, 80 * 1073741824);
    writeFileSync(process.argv[3], `${JSON.stringify(document)}\n`);
  ' "${PLAN_TESTS_DIR}/helpers.mjs" "$1" "$2"
}

run_plan() {
  : > "${DOUBLE_STATE}/elevation.log"
  if (
    cd -- "$WORK_DIR" || exit 125
    PATH="${DOUBLE_BIN}:${PATH}" DOUBLE_STATE="$DOUBLE_STATE" \
      "${CODE_ROOT}/operations/install" plan "$@"
  ) > "$STDOUT_PATH" 2> "$STDERR_PATH"; then
    PLAN_STATUS=0
  else
    PLAN_STATUS=$?
  fi
  [[ ! -s "${DOUBLE_STATE}/elevation.log" ]] || { printf 'elevation invoked: %s\n' "$(< "${DOUBLE_STATE}/elevation.log")" >&2; return 1; }
}

write_choices() {
  printf '%s\n' "$1" > "${WORK_DIR}/choices.json"
}

plan_digest() {
  node -e 'console.log(JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8")).digest.value)' "$1"
}

json_assert() {
  node -e '
    const d = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    if (!eval(process.argv[2])) { console.error("assertion failed: " + process.argv[2]); process.exit(1); }
  ' "$1" "$2"
}

assert_stderr_contains() {
  grep -Fq -- "$1" "$STDERR_PATH" || { printf 'stderr lacks: %s\n%s\n' "$1" "$(< "$STDERR_PATH")" >&2; return 1; }
}

assert_no_canary() {
  if grep -rFq -- "$PLAN_CANARY" "$WORK_DIR" "$STDOUT_PATH" "$STDERR_PATH"; then
    printf '%s\n' 'the planted canary leaked' >&2
    return 1
  fi
}

assert_private_permissions() {
  [[ -z "$(find "$1" -type d ! -perm 700 -print -quit)" ]]
  [[ -z "$(find "$1" -type f ! -perm 600 -print -quit)" ]]
}

@test "plan --help prints its own help on stdout without touching anything" {
  run_plan --help
  [ "$PLAN_STATUS" -eq 0 ]
  [ ! -s "$STDERR_PATH" ]
  grep -Fq 'Usage: install plan --facts <file> [--choices <file>] [--output <dir>]' "$STDOUT_PATH"
  grep -Fq 'Normalized exit outcomes:' "$STDOUT_PATH"
  grep -Fq 'Documentation: docs/procedures/install.md' "$STDOUT_PATH"
  [ ! -e "${WORK_DIR}/evidence" ]
}

@test "plan rejects malformed invocations before any work" {
  run_plan
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains '--facts is required.'

  run_plan --bogus
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains 'unsupported argument: --bogus'

  run_plan --facts
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains '--facts requires a file.'

  run_plan --facts "$FACTS" --facts "$FACTS"
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains '--facts may be given only once.'

  run_plan --help --facts "$FACTS"
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains 'unsupported argument: --help'
  [ ! -e "${WORK_DIR}/evidence" ]
}

@test "plan with valid facts writes the plan, the render, and the run metadata privately" {
  local before after
  before="$(sha256sum "$FACTS")"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  after="$(sha256sum "$FACTS")"
  [ "$before" == "$after" ]
  [ "$(find "${WORK_DIR}/out" -type f | wc -l)" -eq 3 ]
  for name in installation-plan.json installation-plan.txt plan-run.json; do
    [ -f "${WORK_DIR}/out/${name}" ]
  done
  assert_private_permissions "${WORK_DIR}/out"
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.target.disk.by_id === 'virtio-SYNTH-VDA-0001'"
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.choices.hostname.value === 'mirroros-ref' && d.choices.hostname.source === 'override'"
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.choices.target_disk.provenance === 'hardware_detection'"
  json_assert "${WORK_DIR}/out/plan-run.json" "d.exit_status === 0 && d.digest.value === '$(plan_digest "${WORK_DIR}/out/installation-plan.json")'"
  [ ! -s "$STDERR_PATH" ]
}

@test "plan prints the summary and ends with the review notice" {
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  grep -Fq 'Profile: matched reference-vm' "$STDOUT_PATH"
  grep -Fq 'Disk: virtio-SYNTH-VDA-0001' "$STDOUT_PATH"
  grep -Fq 'Storage option: btrfs-limine (default)' "$STDOUT_PATH"
  grep -Fq 'Destructive operations: ' "$STDOUT_PATH"
  grep -Fq 'Secrets required: account_password' "$STDOUT_PATH"
  grep -Fq "Digest: sha256 $(plan_digest "${WORK_DIR}/out/installation-plan.json")" "$STDOUT_PATH"
  grep -Fq "Plan: ${WORK_DIR}/out/installation-plan.json" "$STDOUT_PATH"
  [ "$(tail -n 1 "$STDOUT_PATH")" == 'Review installation-plan.txt; approval is not part of this stage.' ]
}

@test "plan uses a new run directory under evidence/install by default" {
  run_plan --facts "$FACTS"
  [ "$PLAN_STATUS" -eq 0 ]
  [ "$(find "${WORK_DIR}/evidence/install" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ]
  [ -f "$(find "${WORK_DIR}/evidence/install" -name installation-plan.json)" ]
  assert_private_permissions "${WORK_DIR}/evidence"
}

@test "an edited regeneration is a new plan and leaves the original untouched" {
  local first_sum first_digest second_digest
  run_plan --facts "$FACTS" --output "${WORK_DIR}/first"
  [ "$PLAN_STATUS" -eq 0 ]
  first_sum="$(sha256sum "${WORK_DIR}"/first/*)"
  first_digest="$(plan_digest "${WORK_DIR}/first/installation-plan.json")"

  write_choices '{"format_version":3,"hostname":"edited-host","storage_option":"btrfs-rescue"}'
  run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/second"
  [ "$PLAN_STATUS" -eq 0 ]
  second_digest="$(plan_digest "${WORK_DIR}/second/installation-plan.json")"
  [ "$first_digest" != "$second_digest" ]
  json_assert "${WORK_DIR}/second/installation-plan.json" "d.choices.hostname.value === 'edited-host' && d.choices.hostname.source === 'choice'"
  json_assert "${WORK_DIR}/second/installation-plan.json" "d.choices.storage_option.value === 'btrfs-rescue' && d.choices.storage_option.tier === 'supported'"
  grep -Fq 'edited-host' "${WORK_DIR}/second/installation-plan.txt"
  [ "$first_sum" == "$(sha256sum "${WORK_DIR}"/first/*)" ]
}

@test "disabled hibernation plans zram without a swapfile, @swap, or resume parameters" {
  write_choices '{"format_version":3,"hibernation":false}'
  run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.choices.hibernation.value === false && !('swapfile_size' in d.choices)"
  json_assert "${WORK_DIR}/out/installation-plan.json" "!d.operations.some(o => o.kind === 'create_swapfile') && d.operations.some(o => o.kind === 'configure_zram')"
  json_assert "${WORK_DIR}/out/installation-plan.json" "!JSON.stringify(d).includes('resume=') && !JSON.stringify(d).includes('@swap') && !d.operations.some(o => JSON.stringify(o.resolved_at_apply ?? []).includes('resume_offset'))"
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.choices.kernel_cmdline.value.includes('zswap.enabled=0')"
  grep -Fq 'no swapfile will be created' "${WORK_DIR}/out/installation-plan.txt"
}

@test "disabled hibernation with an explicit swapfile size is rejected, not ignored" {
  write_choices '{"format_version":3,"hibernation":false,"swapfile_size":2048}'
  run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  [ ! -e "${WORK_DIR}/out/installation-plan.json" ]
  json_assert "${WORK_DIR}/out/plan-run.json" "d.reasons.some(r => r.code === 'choices_conflict')"
}

@test "a swapfile below detected memory warns and a default that exceeds the disk is refused, not shrunk" {
  write_choices '{"format_version":3,"swapfile_size":2048}'
  run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.choices.swapfile_size.value === 2048 && d.warnings.some(w => w.code === 'swapfile_below_ram')"
  rm -rf -- "${WORK_DIR}/out"
  make_facts memory-80g "$FACTS"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  json_assert "${WORK_DIR}/out/plan-run.json" "d.reasons.some(r => r.code === 'plan_size_does_not_fit')"
}

@test "missing detected memory exits 2 asking for repeated discovery" {
  make_facts no-memory "$FACTS"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  [ ! -e "${WORK_DIR}/out/installation-plan.json" ]
  json_assert "${WORK_DIR}/out/plan-run.json" "d.reasons.some(r => r.code === 'memory_unavailable')"
}

@test "choices of version 2 are rejected with regeneration guidance and are not migrated" {
  write_choices '{"format_version":2,"hostname":"edited"}'
  run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  [ ! -e "${WORK_DIR}/out/installation-plan.json" ]
  assert_stderr_contains 'not migrated'
}

@test "the same inputs yield the same digest" {
  run_plan --facts "$FACTS" --output "${WORK_DIR}/one"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/two"
  [ "$(plan_digest "${WORK_DIR}/one/installation-plan.json")" == "$(plan_digest "${WORK_DIR}/two/installation-plan.json")" ]
}

@test "a supported storage option is accepted with its tier and no experimental warning" {
  write_choices '{"format_version":3,"storage_option":"ext4-systemd-boot"}'
  run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.choices.storage_option.tier === 'supported'"
  json_assert "${WORK_DIR}/out/installation-plan.json" "!d.warnings.some(w => w.code === 'storage_option_experimental')"
}

@test "root_account password adds the root consumer to the single account_password requirement" {
  write_choices '{"format_version":3,"root_account":"password"}'
  run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.secret_requirements.length === 1 && d.secret_requirements[0].name === 'account_password'"
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.secret_requirements[0].required_by.join() === 'create_user,configure_root_account'"
  grep -Fq 'Secrets required: account_password' "$STDOUT_PATH"
  ! grep -Eq 'root_password|user_password' "${WORK_DIR}/out/installation-plan.json"
}

@test "a locked root account names only the user operation as consumer" {
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.secret_requirements[0].required_by.join() === 'create_user'"
}

@test "an unqualified machine produces a plan with its warning and no profile bindings" {
  make_facts unqualified "$FACTS"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.target.profile.status === 'unqualified' && !('profile_id' in d.target.profile)"
  json_assert "${WORK_DIR}/out/installation-plan.json" "!('profile_definition_sha256' in d.policy_binding) && !('override_sha256' in d.policy_binding)"
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.target.machine.dmi.sys_vendor === 'Synthetic Vendor' && d.choices.hostname.source === 'policy'"
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.warnings.map(w => w.code).join() === 'machine_unqualified'"
  assert_stderr_contains 'matches no known profile'
  grep -Fq 'Profile: unqualified' "$STDOUT_PATH"
}

@test "a recognized machine binds its profile definition and override" {
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.target.profile.status === 'matched' && d.target.profile.profile_id === 'reference-vm'"
  json_assert "${WORK_DIR}/out/installation-plan.json" "/^[0-9a-f]{64}\$/.test(d.policy_binding.profile_definition_sha256) && /^[0-9a-f]{64}\$/.test(d.policy_binding.override_sha256)"
}

@test "a matched profile that the checkout does not define is rejected as invalid facts" {
  rm -rf -- "${CODE_ROOT}/targets/reference-vm"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  json_assert "${WORK_DIR}/out/plan-run.json" "d.reasons[0].code === 'facts_invalid'"
  [ ! -e "${WORK_DIR}/out/installation-plan.json" ]
}

@test "plan rejects invalid choices without writing a plan and records the reasons" {
  local body
  for body in \
    '{"format_version":3,"bogus_key":"x"}' \
    '{"format_version":3,"root_minimum_bytes":1}' \
    '{"format_version":3,"locales":["en_US.UTF-8"]}' \
    '{"format_version":3,"locale_categories":{}}' \
    '{"format_version":3,"lang":"de_DE.UTF-8"}' \
    '{"format_version":3,"storage_option":"zfs"}' \
    '{"format_version":3,"hostname":"-bad-"}' \
    '{"format_version":3,"target_disk":"/dev/nowhere"}' \
    '{"format_version":1,"hostname":"edited"}' \
    '{"hostname":"edited"}' \
    'not json'; do
    write_choices "$body"
    rm -rf -- "${WORK_DIR}/out"
    run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/out"
    [ "$PLAN_STATUS" -eq 2 ]
    [ ! -e "${WORK_DIR}/out/installation-plan.json" ]
    [ ! -e "${WORK_DIR}/out/installation-plan.txt" ]
    json_assert "${WORK_DIR}/out/plan-run.json" "d.exit_status === 2 && d.reasons.length > 0 && !('digest' in d)"
    [ -s "$STDERR_PATH" ]
    [ ! -s "$STDOUT_PATH" ]
  done
}

@test "a secret-like choice is refused and its value never appears anywhere" {
  local key
  for key in password user_password root_password account_password; do
    write_choices "{\"format_version\":3,\"${key}\":\"${PLAN_CANARY}\"}"
    rm -rf -- "${WORK_DIR}/out"
    run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/out"
    [ "$PLAN_STATUS" -eq 2 ]
    json_assert "${WORK_DIR}/out/plan-run.json" "d.reasons.some(r => r.code === 'choices_secret_key')"
    [ ! -e "${WORK_DIR}/out/installation-plan.json" ]
    rm -f -- "${WORK_DIR}/choices.json"
    assert_no_canary
  done
}

@test "a secret canary in an editable value is not echoed by any output" {
  write_choices "{\"format_version\":3,\"hostname\":\"${PLAN_CANARY}\",\"user_name\":\"${PLAN_CANARY}\"}"
  run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  rm -f -- "${WORK_DIR}/choices.json"
  assert_no_canary
}

@test "a canary never reaches a successful plan, its render, or the console" {
  write_choices '{"format_version":3,"root_account":"password"}'
  run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  assert_no_canary
}

@test "several eligible disks exit 2 listing the candidates" {
  make_facts two-disks "$FACTS"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains 'virtio-SYNTH-VDA-0001'
  assert_stderr_contains 'virtio-SYNTH-VDB-0002'
  [ ! -e "${WORK_DIR}/out/installation-plan.json" ]
  json_assert "${WORK_DIR}/out/plan-run.json" "d.exit_status === 2"

  write_choices '{"format_version":3,"target_disk":"virtio-SYNTH-VDB-0002"}'
  rm -rf -- "${WORK_DIR}/out"
  run_plan --facts "$FACTS" --choices "${WORK_DIR}/choices.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "${WORK_DIR}/out/installation-plan.json" "d.target.disk.by_id === 'virtio-SYNTH-VDB-0002' && d.choices.target_disk.source === 'choice'"
}

@test "plan rejects unreadable, malformed, unknown-format, and invalid facts with exit 2" {
  run_plan --facts "${WORK_DIR}/absent.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  json_assert "${WORK_DIR}/out/plan-run.json" "d.reasons[0].code === 'facts_invalid'"

  printf '%s\n' 'not json' > "${WORK_DIR}/bad.json"
  rm -rf -- "${WORK_DIR}/out"
  run_plan --facts "${WORK_DIR}/bad.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]

  make_facts format-1 "${WORK_DIR}/format1.json"
  rm -rf -- "${WORK_DIR}/out"
  run_plan --facts "${WORK_DIR}/format1.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  json_assert "${WORK_DIR}/out/plan-run.json" "d.reasons[0].code === 'facts_format_unknown'"

  make_facts status-invalid "${WORK_DIR}/invalid.json"
  rm -rf -- "${WORK_DIR}/out"
  run_plan --facts "${WORK_DIR}/invalid.json" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  [ ! -e "${WORK_DIR}/out/installation-plan.json" ]
}

@test "preview-choices prints the defaults, options, and derived localization and writes nothing" {
  local before
  before="$(find "$WORK_DIR" | sort)"
  run_plan preview-choices --facts "$FACTS"
  [ "$PLAN_STATUS" -eq 0 ]
  [ ! -s "$STDERR_PATH" ]
  json_assert "$STDOUT_PATH" "d.format_version === 3 && d.choices.hostname.source === 'override' && d.choices.target_disk.source === 'detected'"
  json_assert "$STDOUT_PATH" "d.derived.locales.join() === 'en_US.UTF-8' && !('LC_ALL' in d.derived.locale_categories)"
  json_assert "$STDOUT_PATH" "d.options.storage_option.length === 3 && d.options.regional_format.join() === 'follow_language,en_US.UTF-8,es_ES.UTF-8'"
  [ ! -e "${WORK_DIR}/evidence" ]
  [ "$before" == "$(find "$WORK_DIR" | sort)" ]
}

@test "preview-choices follows the choices file and leaves the disk pending among several" {
  write_choices '{"format_version":3,"lang":"es_ES.UTF-8"}'
  run_plan preview-choices --facts "$FACTS" --choices "${WORK_DIR}/choices.json"
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "$STDOUT_PATH" "d.derived.locales.join() === 'es_ES.UTF-8' && d.choices.lang.source === 'choice'"

  make_facts two-disks "$FACTS"
  run_plan preview-choices --facts "$FACTS"
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "$STDOUT_PATH" "!('target_disk' in d.choices) && d.options.target_disk.length === 2"
}

@test "preview-choices reports an unqualified machine and rejects invalid inputs with exit 2" {
  make_facts unqualified "$FACTS"
  run_plan preview-choices --facts "$FACTS"
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "$STDOUT_PATH" "d.warnings.map(w => w.code).join() === 'machine_unqualified' && d.choices.hostname.source === 'policy'"

  write_choices '{"format_version":1,"hostname":"x"}'
  run_plan preview-choices --facts "$FACTS" --choices "${WORK_DIR}/choices.json"
  [ "$PLAN_STATUS" -eq 2 ]
  [ ! -s "$STDOUT_PATH" ]
  assert_stderr_contains 'format_version 3'

  run_plan preview-choices --facts "${WORK_DIR}/absent.json"
  [ "$PLAN_STATUS" -eq 2 ]
  [ ! -e "${WORK_DIR}/evidence" ]
}

@test "validate-choice accepts a valid value and reports the derived localization" {
  run_plan validate-choice --facts "$FACTS" --key lang --value es_ES.UTF-8
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "$STDOUT_PATH" "d.valid === true && d.key === 'lang' && d.derived.locales.join() === 'es_ES.UTF-8'"

  run_plan validate-choice --facts "$FACTS" --key swapfile_size --value 2048
  [ "$PLAN_STATUS" -eq 0 ]
  json_assert "$STDOUT_PATH" "d.valid === true && d.value === 2048 && !('derived' in d)"
  [ ! -e "${WORK_DIR}/evidence" ]
}

@test "validate-choice rejects invalid, fixed, derived, unknown, and secret-like keys with exit 2" {
  local key value code
  while read -r key value code; do
    run_plan validate-choice --facts "$FACTS" --key "$key" --value "$value"
    [ "$PLAN_STATUS" -eq 2 ]
    json_assert "$STDOUT_PATH" "d.valid === false && d.reasons.length === 1 && d.reasons[0].code === '${code}'"
  done <<EOF
swapfile_size abc choices_invalid_value
swapfile_size 100 choices_invalid_value
hostname -bad- choices_invalid_value
lang de_DE.UTF-8 choices_invalid_value
kernel linux choices_not_editable
locales en_US.UTF-8 choices_not_editable
bogus x choices_unknown_key
account_password ${PLAN_CANARY} choices_secret_key
target_disk /dev/sr0 disk_ineligible
EOF
  assert_no_canary
}

@test "validate-choice reports an empty value as invalid instead of a usage error" {
  run_plan validate-choice --facts "$FACTS" --key hostname --value ''
  [ "$PLAN_STATUS" -eq 2 ]
  json_assert "$STDOUT_PATH" "d.valid === false && d.reasons[0].code === 'choices_invalid_value'"
}

@test "the choice helpers reject malformed invocations before any work" {
  run_plan validate-choice --facts "$FACTS" --key lang
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains 'validate-choice requires --key and --value.'

  run_plan validate-choice --facts "$FACTS" --value x
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains 'validate-choice requires --key and --value.'

  run_plan validate-choice --facts "$FACTS" --key lang --key lang --value x
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains '--key may be given only once.'

  run_plan preview-choices --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains '--output is not accepted by preview-choices.'

  run_plan preview-choices --facts "$FACTS" --key lang
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains 'accepted only by validate-choice'

  run_plan --facts "$FACTS" --key lang --value x
  [ "$PLAN_STATUS" -eq 2 ]

  run_plan preview-choices
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains '--facts is required.'
  [ ! -e "${WORK_DIR}/evidence" ]
}

@test "plan refuses an output directory that already holds a plan without writing" {
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  local before
  before="$(find "${WORK_DIR}/out" -type f -exec sha256sum {} + | sort)"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 2 ]
  assert_stderr_contains 'already contains an installation plan'
  [ "$before" == "$(find "${WORK_DIR}/out" -type f -exec sha256sum {} + | sort)" ]
}

@test "plan never invokes an elevation mechanism" {
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 0 ]
  [ ! -s "${DOUBLE_STATE}/elevation.log" ]
}

@test "plan reports damaged embedded code with exit 6" {
  rm -f -- "${CODE_ROOT}/install/plan/render-plan.mjs"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 6 ]
  assert_stderr_contains 'incomplete or damaged'
  assert_stderr_contains 'render-plan.mjs'

  rm -f -- "${CODE_ROOT}/install/plan/plan"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 6 ]
  assert_stderr_contains 'plan orchestrator could not be found'
}

@test "plan reports a damaged policy as an internal failure with exit 6" {
  printf '%s\n' '{"format_version":1}' > "${CODE_ROOT}/install/plan/policy.json"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 6 ]
  assert_stderr_contains 'internal contract check failed'
  [ ! -e "${WORK_DIR}/out/installation-plan.json" ]
}

@test "plan reports an unexpected tool failure with exit 5" {
  printf '%s\n' '#!/usr/bin/bash' 'exit 1' > "${DOUBLE_BIN}/node"
  chmod +x "${DOUBLE_BIN}/node"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/out"
  [ "$PLAN_STATUS" -eq 5 ]
  assert_stderr_contains 'Node.js failed unexpectedly'

  rm -f -- "${DOUBLE_BIN}/node"
  mkdir -p "${WORK_DIR}/locked"
  chmod 500 "${WORK_DIR}/locked"
  run_plan --facts "$FACTS" --output "${WORK_DIR}/locked/out"
  chmod 700 "${WORK_DIR}/locked"
  if [[ "$(id -u)" -ne 0 ]]; then
    [ "$PLAN_STATUS" -eq 5 ]
    assert_stderr_contains 'unexpected failure'
  fi
}

@test "plan works when invoked through a symlink as on the live medium" {
  ln -s "${CODE_ROOT}/operations/install" "${TEST_ROOT}/mirroros-install"
  run "${TEST_ROOT}/mirroros-install" plan --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'Usage: install plan'* ]]
}
