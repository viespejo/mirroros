#!/usr/bin/bash

# Discovery qualification helpers (Story 2.2). They reuse the Story 1.4 libraries for QEMU launch,
# the NoCloud medium, stopping, cleanup, and the evidence scan; the bootstrap result schema is not
# touched. Requires preconditions.sh, run-resources.sh, launch.sh, outcome.sh, and evidence.sh.

DISCOVERY_SCENARIO=''
DISCOVERY_TARGET=''
DISCOVERY_EXPECTED_EXIT=''
DISCOVERY_OVERLAY=0
DISCOVERY_OVERLAY_B64=''
DISCOVERY_COMPARISON='not_run'
DISCOVERY_VERDICT=''
DISCOVERY_ACTUAL_EXIT=''
DISCOVERY_GUEST_SCRIPT_NAME='discovery-guest.sh'
DISCOVERY_DISK_BEFORE_NAME='disk-before.qcow2'
DISCOVERY_LAYOUT_RAW_NAME='layout.raw'
DISCOVERY_EVIDENCE_BASE_NAME='discovery'
DISCOVERY_OVERLAY_PATHS=(
  'operations/install'
  'operations/lib/lifecycle-discovery.sh'
  'install'
  'hardware/discovery'
  'targets'
)

discovery_usage_error() {
  printf 'MirrorOS qualify-discovery: %s\n' "$1" >&2
  printf '%s\n' \
    'Accepted forms: qualify-discovery --scenario empty|layout|framework-target [--development-overlay] BUNDLE_DIRECTORY, qualify-discovery --help.' >&2
  return 2
}

# Scenario names fix the target and the expected discovery exit; there is no free target option.
discovery_parse_arguments() {
  local bundle_argument=''
  local resolved_directory

  DISCOVERY_SCENARIO=''
  DISCOVERY_OVERLAY=0
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --scenario)
        [[ "$#" -ge 2 && -z "$DISCOVERY_SCENARIO" ]] || { discovery_usage_error '--scenario requires one value, given once.'; return 2; }
        DISCOVERY_SCENARIO="$2"
        shift 2
        ;;
      --development-overlay)
        DISCOVERY_OVERLAY=1
        shift
        ;;
      -*)
        discovery_usage_error "unsupported option: $1"
        return 2
        ;;
      *)
        [[ -z "$bundle_argument" && -n "$1" ]] || { discovery_usage_error 'exactly one bundle directory is accepted.'; return 2; }
        bundle_argument="$1"
        shift
        ;;
    esac
  done

  case "$DISCOVERY_SCENARIO" in
    empty | layout)
      DISCOVERY_TARGET='reference-vm'
      DISCOVERY_EXPECTED_EXIT=0
      ;;
    framework-target)
      DISCOVERY_TARGET='framework-13-pro-amd'
      DISCOVERY_EXPECTED_EXIT=2
      ;;
    '')
      discovery_usage_error '--scenario is required.'
      return 2
      ;;
    *)
      discovery_usage_error "unknown scenario: ${DISCOVERY_SCENARIO}"
      return 2
      ;;
  esac
  if [[ -z "$bundle_argument" ]]; then
    discovery_usage_error 'the bundle directory argument is missing.'
    return 2
  fi
  if [[ ! -d "$bundle_argument" ]] || \
    ! resolved_directory="$(cd -- "$bundle_argument" 2>/dev/null && pwd -P)"; then
    printf 'MirrorOS qualify-discovery: the bundle directory is not an accessible directory: %s\n' \
      "$bundle_argument" >&2
    return 2
  fi
  # shellcheck disable=SC2034 # Read by the qualification orchestrator after argument parsing.
  QUALIFY_BUNDLE_DIR="$resolved_directory"
}

# Host tools beyond the Story 1.4 set: the layout disk and the overlay are built without root.
discovery_check_tools() {
  local tool
  local -a tools=()

  [[ "$DISCOVERY_SCENARIO" != 'layout' ]] || tools+=(sfdisk truncate)
  [[ "$DISCOVERY_OVERLAY" -eq 0 ]] || tools+=(tar base64)
  for tool in "${tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'MirrorOS qualify-discovery: required tool is missing: %s. Install it and retry; no host remediation is attempted.\n' \
        "$tool" >&2
      return 2
    fi
  done
}

# Same layout as run_resources_prepare, but evidence goes to evidence/reference-vm/discovery/<run-id>/.
discovery_run_prepare() {
  local repository_root="$1"
  local requested_run_id="$2"
  local evidence_base="${repository_root}/evidence/reference-vm/${DISCOVERY_EVIDENCE_BASE_NAME}"
  local reserved_path
  local index
  local -a directories=(
    "${repository_root}/build"
    "${repository_root}/build/reference-vm"
    "${repository_root}/evidence"
    "${repository_root}/evidence/reference-vm"
    "$evidence_base"
  )
  local -a labels=('build base' 'build work base' 'evidence base' 'reference VM evidence base' 'discovery evidence base')

  if [[ ! "$requested_run_id" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    printf 'MirrorOS qualify-discovery: invalid run ID: %s\n' "$requested_run_id" >&2
    return 2
  fi
  for index in "${!directories[@]}"; do
    run_resources_check_directory "${directories[$index]}" "${labels[$index]}" || return 2
  done
  for reserved_path in \
    "${repository_root}/build/reference-vm/${requested_run_id}" \
    "${evidence_base}/${requested_run_id}"; do
    if [[ -e "$reserved_path" || -L "$reserved_path" ]]; then
      printf 'MirrorOS qualify-discovery: refusing existing reserved run path: %s\n' "$reserved_path" >&2
      return 2
    fi
  done
  for index in "${!directories[@]}"; do
    run_resources_ensure_directory "${directories[$index]}" "${labels[$index]}" || return 2
  done

  RUN_ID="$requested_run_id"
  BUILD_RUN_DIR="${repository_root}/build/reference-vm/${RUN_ID}"
  EVIDENCE_RUN_DIR="${evidence_base}/${RUN_ID}"
  if ! mkdir -m 700 -- "$BUILD_RUN_DIR" || ! mkdir -m 700 -- "$EVIDENCE_RUN_DIR"; then
    printf 'MirrorOS qualify-discovery: could not create private run directories for %s.\n' "$RUN_ID" >&2
    return 2
  fi
}

# Archives the working-tree embedded subtrees (non-ignored files) for the development overlay.
discovery_build_overlay() {
  local repository_root="$1"

  if ! DISCOVERY_OVERLAY_B64="$(
    set -o pipefail
    git -C "$repository_root" ls-files -z --cached --others --exclude-standard -- "${DISCOVERY_OVERLAY_PATHS[@]}" | \
      tar -C "$repository_root" --null -T - -c --owner=0 --group=0 | base64 -w0
  )" || [[ -z "$DISCOVERY_OVERLAY_B64" ]]; then
    printf '%s\n' 'MirrorOS qualify-discovery: could not archive the working-tree embedded code for the overlay.' >&2
    return 5
  fi
}

# Builds the guest script that nocloud_prepare wraps: target (and overlay) variables, then the trigger.
# The file lives in the build run directory only until the NoCloud medium is built.
discovery_write_guest_script() {
  local build_run_dir="$1"
  local trigger_script="$2"
  local guest_script="${build_run_dir}/${DISCOVERY_GUEST_SCRIPT_NAME}"

  if [[ ! -f "$trigger_script" || ! -r "$trigger_script" ]]; then
    printf 'MirrorOS qualify-discovery: incomplete or damaged checkout; the guest trigger is missing: %s\n' \
      "$trigger_script" >&2
    return 6
  fi
  {
    printf '#!/usr/bin/bash\n'
    printf "MIRROROS_DISCOVERY_TARGET='%s'\n" "$DISCOVERY_TARGET"
    if [[ "$DISCOVERY_OVERLAY" -eq 1 ]]; then
      printf "MIRROROS_DISCOVERY_OVERLAY_B64='%s'\n" "$DISCOVERY_OVERLAY_B64"
    fi
    tail -n +2 -- "$trigger_script"
  } > "$guest_script" || return 5
  chmod 600 -- "$guest_script"
}

# Creates the scenario disk and keeps a private pristine copy for the before/after comparison.
# empty: the fresh qcow2 of the reference VM. layout: a GPT with two labeled partitions, built without
# root by sfdisk on a raw file and converted to qcow2.
discovery_prepare_disk() {
  local build_run_dir="$1"
  local raw_path="${build_run_dir}/${DISCOVERY_LAYOUT_RAW_NAME}"
  local converted_path="${build_run_dir}/disk-layout.qcow2"
  local linux_type='0FC63DAF-8483-4772-8E79-3D69D8477DE4'

  launch_prepare_disk "$build_run_dir" || return 5
  if [[ "$DISCOVERY_SCENARIO" == 'layout' ]]; then
    if ! truncate -s "$REFERENCE_VM_DISK_SIZE" -- "$raw_path" || \
      ! printf 'label: gpt\nsize=1GiB, type=%s, name="mirroros-a"\nsize=2GiB, type=%s, name="mirroros-b"\n' \
        "$linux_type" "$linux_type" | sfdisk --quiet -- "$raw_path" || \
      ! qemu-img convert -f raw -O "$REFERENCE_VM_DISK_FORMAT" -- "$raw_path" "$converted_path" || \
      ! mv -f -- "$converted_path" "$LAUNCH_DISK_PATH"; then
      rm -f -- "$raw_path" "$converted_path"
      printf '%s\n' 'MirrorOS qualify-discovery: building the pre-existing layout disk failed.' >&2
      return 5
    fi
    rm -f -- "$raw_path"
    chmod 600 -- "$LAUNCH_DISK_PATH"
  fi
  if ! cp --no-preserve=mode -- "$LAUNCH_DISK_PATH" "${build_run_dir}/${DISCOVERY_DISK_BEFORE_NAME}"; then
    printf '%s\n' 'MirrorOS qualify-discovery: keeping the pristine disk copy failed.' >&2
    return 5
  fi
  chmod 600 -- "${build_run_dir}/${DISCOVERY_DISK_BEFORE_NAME}"
}

# Compares the disk before and after the guest ran. Only valid after QEMU exit is confirmed.
discovery_compare_disks() {
  local build_run_dir="$1"
  local status=0

  qemu-img compare -f "$REFERENCE_VM_DISK_FORMAT" -F "$REFERENCE_VM_DISK_FORMAT" -- \
    "${build_run_dir}/${DISCOVERY_DISK_BEFORE_NAME}" "$LAUNCH_DISK_PATH" >/dev/null 2>&1 || status=$?
  outcome_record_tool_status disk_compare "$status"
  case "$status" in
    0) DISCOVERY_COMPARISON='identical' ;;
    1) DISCOVERY_COMPARISON='different' ;;
    *)
      DISCOVERY_COMPARISON='error'
      return 5
      ;;
  esac
  return "$status"
}

# Removes the extra run files that stop_cleanup_remove_resources does not know about.
discovery_remove_extra_files() {
  local build_run_dir="$1"

  rm -f -- "${build_run_dir}/${DISCOVERY_DISK_BEFORE_NAME}" "${build_run_dir}/${DISCOVERY_GUEST_SCRIPT_NAME}" \
    "${build_run_dir}/${DISCOVERY_LAYOUT_RAW_NAME}" "${build_run_dir}/disk-layout.qcow2"
}

# Validates the run-bound guest report, retains target-facts.json and error.json, and compares the
# discovery exit with the scenario's expected exit.
# Statuses: 0 expected outcome, 4 unexpected discovery outcome, 5 report missing or inconsistent.
discovery_evaluate_report() {
  local report_path="$1"
  local run_id="$2"
  local evidence_run_dir="$3"
  local status=0

  case "$LAUNCH_OUTCOME" in
    report) ;;
    deadline)
      printf 'MirrorOS qualify-discovery: the %s-second global deadline expired before a guest report arrived; not qualified.\n' \
        "$REFERENCE_VM_GLOBAL_DEADLINE_SECONDS" >&2
      return 5
      ;;
    qemu_exited)
      printf 'MirrorOS qualify-discovery: QEMU exited (status %s) before a guest report arrived; not qualified.\n' \
        "${LAUNCH_QEMU_STATUS:-unknown}" >&2
      return 5
      ;;
    *)
      printf '%s\n' 'MirrorOS qualify-discovery: internal contract violation: no launch outcome was recorded.' >&2
      return 6
      ;;
  esac

  # shellcheck disable=SC2034 # Read by discovery_write_result.
  DISCOVERY_VERDICT="$(node --input-type=module - "$report_path" "$run_id" "$evidence_run_dir" \
    "$DISCOVERY_TARGET" "$DISCOVERY_EXPECTED_EXIT" <<'NODE'
import { readFileSync, writeFileSync, chmodSync } from 'node:fs';

const [reportPath, runId, evidenceDir, target, expectedText] = process.argv.slice(2);
const errors = [];
let report = null;
try {
  report = JSON.parse(readFileSync(reportPath, 'utf8'));
} catch {
  errors.push('the guest report is not valid JSON');
}
const isRecord = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const verdict = { errors, actual_exit: null, facts_validation: null, reason_codes: [], stderr_tail: '' };
if (report !== null) {
  if (!isRecord(report)) errors.push('the guest report must be an object');
  else {
    if (report.schema_version !== 1) errors.push('schema_version must be 1');
    if (report.run_id !== runId) errors.push('the report is not bound to this run');
    if (report.target !== target) errors.push('the report names an unexpected target');
    if (!Number.isInteger(report.exit_status)) errors.push('exit_status must be an integer');
    if (typeof report.stderr_tail !== 'string') errors.push('stderr_tail must be a string');
    if (report.facts !== null && !isRecord(report.facts)) errors.push('facts must be an object or null');
    if (report.error !== null && !isRecord(report.error)) errors.push('error must be an object or null');
  }
}
if (errors.length === 0) {
  verdict.actual_exit = report.exit_status;
  verdict.stderr_tail = report.stderr_tail.slice(-2000);
  if (report.facts !== null) {
    const validation = report.facts.validation;
    if (!isRecord(validation) || !['valid', 'invalid'].includes(validation.status)) {
      errors.push('facts.validation.status must be valid or invalid');
    } else {
      verdict.facts_validation = validation.status;
      verdict.reason_codes = (Array.isArray(validation.reasons) ? validation.reasons : [])
        .map(reason => (isRecord(reason) && typeof reason.code === 'string' ? reason.code : 'unknown'));
      if (report.exit_status === 2 && validation.status !== 'invalid') errors.push('exit status 2 requires invalid facts');
      if (report.exit_status === 0 && validation.status !== 'valid') errors.push('exit status 0 requires valid facts');
    }
  } else if (report.exit_status === 0 || report.exit_status === 2) {
    errors.push('exit status 0 or 2 requires target-facts.json');
  }
}
if (errors.length === 0) {
  for (const [name, content] of [['target-facts.json', report.facts], ['error.json', report.error]]) {
    if (content === null) continue;
    const path = `${evidenceDir}/${name}`;
    writeFileSync(path, `${JSON.stringify(content, null, 2)}\n`, { mode: 0o600 });
    chmodSync(path, 0o600);
  }
}
process.stdout.write(JSON.stringify(verdict));
process.exitCode = errors.length > 0 ? 5 : (verdict.actual_exit === Number(expectedText) ? 0 : 4);
NODE
  )" || status=$?
  outcome_record_tool_status guest_report_validation "$status"
  case "$status" in
    0) ;;
    4) printf '%s\n' 'MirrorOS qualify-discovery: discovery exited differently from the expected status; not qualified.' >&2 ;;
    5) printf '%s\n' 'MirrorOS qualify-discovery: the guest report is incomplete, inconsistent, or not bound to this run; not qualified.' >&2 ;;
    *) printf 'MirrorOS qualify-discovery: guest report validation failed internally (status %s).\n' "$status" >&2 ;;
  esac
  if [[ -n "$DISCOVERY_VERDICT" ]]; then
    DISCOVERY_ACTUAL_EXIT="$(node -e 'const v = JSON.parse(process.argv[1]); process.stdout.write(v.actual_exit === null ? "" : String(v.actual_exit))' "$DISCOVERY_VERDICT" 2>/dev/null)" || DISCOVERY_ACTUAL_EXIT=''
  fi
  return "$status"
}

discovery_next_action() {
  case "$OUTCOME_PRIMARY_STATUS" in
    0) ;;
    2) printf '%s' 'Resolve the reported input, prerequisite, or secret-scan finding, then rerun; findings stay private under the run evidence directory.' ;;
    4) printf '%s' 'Inspect result.json, target-facts.json, and the private guest-serial.log, fix the cause, then rerun.' ;;
    5) printf '%s' 'Review qemu-diagnostics.log, the disk comparison, and the cleanup outcome; see docs/procedures/test.md before rerunning.' ;;
    6) printf '%s' 'Restore the checkout from Git or report the internal contract violation.' ;;
    130 | 143) printf '%s' 'The run was interrupted; rerun when ready.' ;;
    *) printf '%s' 'Review the run evidence and docs/procedures/test.md.' ;;
  esac
}

# A run is counted only when it is a clean, overlay-free run at one commit that met every expectation.
discovery_is_counted() {
  local admission_dirty
  local admission_commit

  [[ "$OUTCOME_PRIMARY_STATUS" -eq 0 && "$DISCOVERY_OVERLAY" -eq 0 && "$OUTCOME_TEST_DIRTY" == 'false' ]] || return 1
  admission_dirty="$(node -e 'process.stdout.write(String(JSON.parse(process.argv[1]).build_dirty))' "$QUALIFY_BUNDLE_ADMISSION" 2>/dev/null)" || return 1
  admission_commit="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).build_commit)' "$QUALIFY_BUNDLE_ADMISSION" 2>/dev/null)" || return 1
  [[ "$admission_dirty" == 'false' && "$admission_commit" == "$OUTCOME_TEST_COMMIT" ]]
}

# Writes evidence/reference-vm/discovery/<run-id>/result.json atomically with mode 0600.
discovery_write_result() {
  local end_epoch
  local duration
  local counted='false'
  local stage
  local scan
  local generator_status=0
  local -a tool_arguments=()
  local -a scan_arguments=()

  end_epoch="$(date -u +%s)" || return 5
  duration=$((end_epoch - OUTCOME_STARTED_EPOCH))
  if [[ "$duration" -lt 0 ]]; then duration=0; fi
  if discovery_is_counted; then counted='true'; fi
  for stage in "${!OUTCOME_TOOL_STATUSES[@]}"; do
    tool_arguments+=("${stage}=${OUTCOME_TOOL_STATUSES[$stage]}")
  done
  for scan in "${!OUTCOME_SCANS[@]}"; do
    scan_arguments+=("${scan}=${OUTCOME_SCANS[$scan]}")
  done

  node --input-type=module - \
    "${EVIDENCE_RUN_DIR}/result.json" "$RUN_ID" "$DISCOVERY_SCENARIO" "$DISCOVERY_TARGET" \
    "$DISCOVERY_EXPECTED_EXIT" "$DISCOVERY_COMPARISON" "$counted" "$DISCOVERY_OVERLAY" \
    "$OUTCOME_PRIMARY_STATUS" "$OUTCOME_FAILED_STAGE" "$(discovery_next_action)" "$duration" \
    "$OUTCOME_TEST_COMMIT" "$OUTCOME_TEST_DIRTY" "$QUALIFY_BUNDLE_ADMISSION" \
    "$LAUNCH_VM_CONFIGURATION_JSON" "$LAUNCH_QEMU_VERSION" "$LAUNCH_OVMF_VERSION" \
    "$DISCOVERY_VERDICT" "$OUTCOME_CLEANUP_OUTCOME" "$OUTCOME_CLEANUP_GUIDANCE" \
    "${#tool_arguments[@]}" "${tool_arguments[@]}" \
    "${#scan_arguments[@]}" "${scan_arguments[@]}" \
    "${#OUTCOME_LEFTOVERS[@]}" "${OUTCOME_LEFTOVERS[@]}" <<'NODE' || generator_status=$?
import { chmodSync, renameSync, writeFileSync } from 'node:fs';

const args = process.argv.slice(2);
const [
  outputPath, runId, scenario, target, expectedText, comparison, counted, overlay,
  statusText, failedStage, nextAction, durationText, commit, dirtyText, admissionText,
  vmText, qemuVersion, ovmfVersion, verdictText, cleanupOutcome, guidance,
] = args;
let cursor = 21;
const take = () => {
  const count = Number(args[cursor++]);
  const items = args.slice(cursor, cursor + count);
  cursor += count;
  return items;
};
const toolEntries = take();
const scanEntries = take();
const leftovers = take();
const pairs = entries => Object.fromEntries(entries.map(entry => {
  const separator = entry.indexOf('=');
  return [entry.slice(0, separator), entry.slice(separator + 1)];
}));

const admission = JSON.parse(admissionText);
let verdict = null;
try {
  verdict = verdictText === '' ? null : JSON.parse(verdictText);
} catch {
  verdict = null;
}
const accepted = verdict !== null && Array.isArray(verdict.errors) && verdict.errors.length === 0;
const document = {
  schema_version: 1,
  kind: 'discovery_qualification',
  run_id: runId,
  scenario,
  target,
  artifact: {
    iso_name: admission.iso_name,
    iso_sha256: admission.iso_sha256,
    build_commit: admission.build_commit,
    build_run_id: admission.build_run_id,
    build_dirty: admission.build_dirty,
  },
  test_code: { commit, dirty: dirtyText === 'true' },
  development_overlay: overlay === '1',
  counted: counted === 'true',
  vm_configuration: JSON.parse(vmText),
  versions: { qemu: qemuVersion, ovmf: ovmfVersion },
  discovery: {
    expected_exit: Number(expectedText),
    actual_exit: accepted ? verdict.actual_exit : null,
    facts_validation: accepted ? verdict.facts_validation : null,
    reason_codes: accepted ? verdict.reason_codes : [],
    stderr_tail: accepted ? verdict.stderr_tail : '',
  },
  disk_identity: { method: 'qemu-img compare', comparison },
  duration_seconds: Number(durationText),
  failed_stage: failedStage || null,
  next_action: nextAction || null,
  status: Number(statusText),
  original_tool_statuses: Object.fromEntries(Object.entries(pairs(toolEntries)).map(([key, value]) => [key, Number(value)])),
  scans: pairs(scanEntries),
  cleanup: {
    outcome: cleanupOutcome,
    leftover_resources: leftovers,
    recovery_guidance: guidance || null,
  },
};
const failures = [];
if (!Number.isInteger(document.status)) failures.push('status must be an integer');
if (!['identical', 'different', 'error', 'not_run'].includes(document.disk_identity.comparison)) failures.push('invalid comparison');
if (document.counted && (document.development_overlay || document.test_code.dirty || document.artifact.build_dirty !== false
  || document.artifact.build_commit !== document.test_code.commit || document.status !== 0)) {
  failures.push('a counted run must be clean, overlay-free, at one commit, and successful');
}
if (failures.length > 0) {
  process.stderr.write(`${failures.join('\n')}\n`);
  process.exit(6);
}
const temporary = `${outputPath}.tmp`;
writeFileSync(temporary, `${JSON.stringify(document, null, 2)}\n`, { mode: 0o600 });
chmodSync(temporary, 0o600);
renameSync(temporary, outputPath);
NODE
  if [[ "$generator_status" -ne 0 ]]; then
    printf 'MirrorOS qualify-discovery: could not write a valid result document (status %s).\n' "$generator_status" >&2
    return 5
  fi
}

# Writes the result, scans the evidence including it, rewrites the result when the scan does not
# pass, and prints a summary derived from the same facts.
discovery_finalize_evidence() {
  outcome_set_scan evidence passed
  outcome_record_tool_status evidence_scan 0
  if ! discovery_write_result; then
    outcome_mark_failure 5 result-write
    return 5
  fi
  if ! evidence_scan "$EVIDENCE_RUN_DIR"; then
    if ! discovery_write_result; then
      outcome_mark_failure 5 result-write
      return 5
    fi
  fi
  printf 'MirrorOS qualify-discovery: scenario %s, expected exit %s, actual exit %s, disks %s, status %s%s.\n' \
    "$DISCOVERY_SCENARIO" "$DISCOVERY_EXPECTED_EXIT" "${DISCOVERY_ACTUAL_EXIT:-none}" "$DISCOVERY_COMPARISON" \
    "$OUTCOME_PRIMARY_STATUS" "$(if [[ "$DISCOVERY_OVERLAY" -eq 1 ]]; then printf ', development overlay (not counted)'; fi)"
  printf 'Evidence: %s\n' "$EVIDENCE_RUN_DIR"
}
