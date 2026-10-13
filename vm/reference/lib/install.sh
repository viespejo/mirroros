#!/usr/bin/bash

# Installation qualification helpers (Story 2.5). They reuse the Story 1.4 libraries for QEMU launch, the NoCloud
# medium, stopping, cleanup, and the evidence scan, and the Story 2.2 helpers for the disposable disk, the
# development overlay, and the run directories. Requires preconditions.sh, run-resources.sh, nocloud.sh, launch.sh,
# stop-cleanup.sh, outcome.sh, evidence.sh, and discovery.sh to be sourced first.
#
# Every case boots twice when it installs: the ISO runs the real guided installer through a pty, then QEMU is
# stopped and the disk boots alone, where the harness logs in at tty1 through the QEMU monitor and reads the
# result from the serial console. Cases that do not install boot once.

INSTALL_CASE=''
INSTALL_CHOICES=''
INSTALL_FAILURE=0
INSTALL_EXPECTED_EXIT=''
INSTALL_EXPECTED_OUTCOME=''
INSTALL_EXPECTED_FAILED_OPERATION=''
INSTALL_EXPECTED_HIBERNATION='false'
INSTALL_EXPECTED_DISK='any'
INSTALL_BOOT_USERS=()
INSTALL_CANARY=''
INSTALL_COMPARISON='not_run'
INSTALL_VERDICT=''
INSTALL_LOGIN_JSON='null'
INSTALL_ACTUAL_EXIT=''
INSTALL_GUEST_SCRIPT_NAME='install-guest.sh'
INSTALL_MONITOR_NAME='m.sock'
# A private short-lived directory: Unix socket paths are limited to 108 bytes, which run directories can exceed.
INSTALL_MONITOR_DIR=''
INSTALL_DRIVER_MARGIN_SECONDS=300
# Cases whose engine kinds exist in this version. A case that is wired but missing here stays disabled.
INSTALL_ENABLED_CASES=(default limine-nohib ext4 btrfs-rescue failure cancel-password)

install_usage_error() {
  printf 'MirrorOS qualify-install: %s\n' "$1" >&2
  printf '%s\n' \
    'Accepted forms: qualify-install --case default|limine-nohib|ext4|btrfs-rescue|failure|cancel-password [--development-overlay] BUNDLE_DIRECTORY, qualify-install --help.' >&2
  return 2
}

# Case names fix the choices and the expected results; there is no free choice or QEMU option.
install_configure_case() {
  local base='"format_version":3'

  INSTALL_FAILURE=0
  INSTALL_EXPECTED_HIBERNATION='false'
  INSTALL_EXPECTED_DISK='any'
  INSTALL_EXPECTED_FAILED_OPERATION=''
  INSTALL_BOOT_USERS=()
  case "$INSTALL_CASE" in
    default)
      INSTALL_CHOICES="{${base},\"storage_option\":\"btrfs-limine\",\"hibernation\":true,\"root_account\":\"locked\"}"
      INSTALL_EXPECTED_EXIT=0
      INSTALL_EXPECTED_OUTCOME='installed'
      INSTALL_EXPECTED_HIBERNATION='true'
      INSTALL_BOOT_USERS=(mirroros)
      ;;
    limine-nohib)
      INSTALL_CHOICES="{${base},\"storage_option\":\"btrfs-limine\",\"hibernation\":false,\"root_account\":\"locked\"}"
      INSTALL_EXPECTED_EXIT=0
      INSTALL_EXPECTED_OUTCOME='installed'
      INSTALL_BOOT_USERS=(mirroros)
      ;;
    ext4)
      INSTALL_CHOICES="{${base},\"storage_option\":\"ext4-systemd-boot\",\"hibernation\":true,\"root_account\":\"password\"}"
      INSTALL_EXPECTED_EXIT=0
      INSTALL_EXPECTED_OUTCOME='installed'
      INSTALL_EXPECTED_HIBERNATION='true'
      INSTALL_BOOT_USERS=(mirroros root)
      ;;
    btrfs-rescue)
      INSTALL_CHOICES="{${base},\"storage_option\":\"btrfs-rescue\",\"hibernation\":false,\"root_account\":\"locked\"}"
      INSTALL_EXPECTED_EXIT=0
      INSTALL_EXPECTED_OUTCOME='installed'
      INSTALL_BOOT_USERS=(mirroros)
      ;;
    failure)
      INSTALL_CHOICES="{${base},\"storage_option\":\"ext4-systemd-boot\",\"hibernation\":false,\"root_account\":\"locked\"}"
      INSTALL_FAILURE=1
      INSTALL_EXPECTED_EXIT=5
      INSTALL_EXPECTED_OUTCOME='failed'
      INSTALL_EXPECTED_FAILED_OPERATION='install_packages'
      ;;
    cancel-password)
      INSTALL_CHOICES="{${base},\"storage_option\":\"ext4-systemd-boot\",\"hibernation\":false,\"root_account\":\"locked\"}"
      INSTALL_EXPECTED_EXIT=3
      INSTALL_EXPECTED_OUTCOME='cancelled'
      INSTALL_EXPECTED_DISK='identical'
      ;;
    '')
      install_usage_error '--case is required.'
      return 2
      ;;
    *)
      install_usage_error "unknown case: ${INSTALL_CASE}"
      return 2
      ;;
  esac
}

install_case_enabled() {
  local enabled

  for enabled in "${INSTALL_ENABLED_CASES[@]}"; do
    [[ "$enabled" == "$INSTALL_CASE" ]] && return 0
  done
  printf 'MirrorOS qualify-install: the %s case is wired but not enabled in this version of the harness.\n' "$INSTALL_CASE" >&2
  return 2
}

install_parse_arguments() {
  local bundle_argument=''
  local resolved_directory

  INSTALL_CASE=''
  DISCOVERY_OVERLAY=0
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --case)
        [[ "$#" -ge 2 && -z "$INSTALL_CASE" ]] || { install_usage_error '--case requires one value, given once.'; return 2; }
        INSTALL_CASE="$2"
        shift 2
        ;;
      --development-overlay)
        DISCOVERY_OVERLAY=1
        shift
        ;;
      -*)
        install_usage_error "unsupported option: $1"
        return 2
        ;;
      *)
        [[ -z "$bundle_argument" && -n "$1" ]] || { install_usage_error 'exactly one bundle directory is accepted.'; return 2; }
        bundle_argument="$1"
        shift
        ;;
    esac
  done
  install_configure_case || return 2
  install_case_enabled || return 2
  if [[ -z "$bundle_argument" ]]; then
    install_usage_error 'the bundle directory argument is missing.'
    return 2
  fi
  if [[ ! -d "$bundle_argument" ]] || \
    ! resolved_directory="$(cd -- "$bundle_argument" 2>/dev/null && pwd -P)"; then
    printf 'MirrorOS qualify-install: the bundle directory is not an accessible directory: %s\n' \
      "$bundle_argument" >&2
    return 2
  fi
  # The disposable disk and the run directories come from the discovery helpers.
  # shellcheck disable=SC2034 # Read by discovery_prepare_disk.
  DISCOVERY_SCENARIO='empty'
  # shellcheck disable=SC2034 # Read by discovery_run_prepare.
  DISCOVERY_EVIDENCE_BASE_NAME='install'
  # shellcheck disable=SC2034 # Read by the qualification orchestrator after argument parsing.
  QUALIFY_BUNDLE_DIR="$resolved_directory"
}

# Host tools beyond the Story 1.4 set: the monitor driver and the canary scan.
install_check_tools() {
  local tool
  local -a tools=(node grep)

  [[ "$DISCOVERY_OVERLAY" -eq 0 ]] || tools+=(tar base64)
  for tool in "${tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'MirrorOS qualify-install: required tool is missing: %s. Install it and retry; no host remediation is attempted.\n' \
        "$tool" >&2
      return 2
    fi
  done
}

# A random lowercase hexadecimal canary per run: it is the account password of the run and must appear nowhere.
install_new_canary() {
  INSTALL_CANARY="$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')" || return 5
  [[ "$INSTALL_CANARY" =~ ^[0-9a-f]{24}$ ]] || return 5
}

# Builds the guest script that nocloud_prepare wraps: case variables (and overlay), then the trigger.
install_write_guest_script() {
  local build_run_dir="$1"
  local trigger_script="$2"
  local guest_script="${build_run_dir}/${INSTALL_GUEST_SCRIPT_NAME}"

  if [[ ! -f "$trigger_script" || ! -r "$trigger_script" ]]; then
    printf 'MirrorOS qualify-install: incomplete or damaged checkout; the guest trigger is missing: %s\n' \
      "$trigger_script" >&2
    return 6
  fi
  {
    printf '#!/usr/bin/bash\n'
    printf "MIRROROS_INSTALL_CASE='%s'\n" "$INSTALL_CASE"
    printf "MIRROROS_INSTALL_CHOICES='%s'\n" "$INSTALL_CHOICES"
    printf "MIRROROS_INSTALL_CANARY='%s'\n" "$INSTALL_CANARY"
    printf "MIRROROS_INSTALL_FAILURE='%s'\n" "$INSTALL_FAILURE"
    printf "MIRROROS_INSTALL_DRIVER_SECONDS='%s'\n" "$((REFERENCE_VM_INSTALL_DEADLINE_SECONDS - INSTALL_DRIVER_MARGIN_SECONDS))"
    if [[ "$DISCOVERY_OVERLAY" -eq 1 ]]; then
      printf "MIRROROS_INSTALL_OVERLAY_B64='%s'\n" "$DISCOVERY_OVERLAY_B64"
    fi
    tail -n +2 -- "$trigger_script"
  } > "$guest_script" || return 5
  chmod 600 -- "$guest_script"
}

# The deadline is the versioned installation deadline, which must leave room for the guest driver margin; the
# login timings are versioned too.
install_check_configuration() {
  local name

  if [[ ! "${REFERENCE_VM_INSTALL_DEADLINE_SECONDS:-}" =~ ^[0-9]+$ ]] || \
    [[ "$REFERENCE_VM_INSTALL_DEADLINE_SECONDS" -le "$INSTALL_DRIVER_MARGIN_SECONDS" ]]; then
    printf 'MirrorOS qualify-install: the reference VM configuration lacks a usable REFERENCE_VM_INSTALL_DEADLINE_SECONDS (version 2).\n' >&2
    return 6
  fi
  for name in REFERENCE_VM_LOGIN_FIRST_WAIT_SECONDS REFERENCE_VM_LOGIN_INTERVAL_SECONDS; do
    if [[ ! "${!name:-}" =~ ^[0-9]+$ ]]; then
      printf 'MirrorOS qualify-install: the reference VM configuration lacks a usable %s (version 2).\n' "$name" >&2
      return 6
    fi
  done
}

# Compares the disk before and after. Only valid after QEMU exit is confirmed.
install_compare_disks() {
  local build_run_dir="$1"
  local status=0

  qemu-img compare -f "$REFERENCE_VM_DISK_FORMAT" -F "$REFERENCE_VM_DISK_FORMAT" -- \
    "${build_run_dir}/${DISCOVERY_DISK_BEFORE_NAME}" "$LAUNCH_DISK_PATH" >/dev/null 2>&1 || status=$?
  outcome_record_tool_status disk_compare "$status"
  case "$status" in
    0) INSTALL_COMPARISON='identical' ;;
    1) INSTALL_COMPARISON='different' ;;
    *)
      INSTALL_COMPARISON='error'
      return 5
      ;;
  esac
  if [[ "$INSTALL_EXPECTED_DISK" == 'identical' && "$status" -ne 0 ]]; then
    return 1
  fi
  return 0
}

install_remove_extra_files() {
  local build_run_dir="$1"

  rm -f -- "${build_run_dir}/${DISCOVERY_DISK_BEFORE_NAME}" "${build_run_dir}/${INSTALL_GUEST_SCRIPT_NAME}"
  if [[ "$INSTALL_MONITOR_DIR" == */mirroros-monitor.* && -d "$INSTALL_MONITOR_DIR" && ! -L "$INSTALL_MONITOR_DIR" ]]; then
    rm -rf -- "$INSTALL_MONITOR_DIR"
  fi
  INSTALL_MONITOR_DIR=''
}

# Validates the run-bound guest report against the case's expectations and retains the guest evidence under
# install/ and the observations under observation/; selected configuration checks are gating.
# Statuses: 0 expected outcome, 4 unexpected outcome, 5 report missing or inconsistent.
install_evaluate_report() {
  local report_path="$1"
  local run_id="$2"
  local evidence_run_dir="$3"
  local status=0

  case "$LAUNCH_OUTCOME" in
    report) ;;
    deadline)
      printf 'MirrorOS qualify-install: the %s-second installation deadline expired before a guest report arrived; not qualified.\n' \
        "$REFERENCE_VM_INSTALL_DEADLINE_SECONDS" >&2
      return 5
      ;;
    qemu_exited)
      printf 'MirrorOS qualify-install: QEMU exited (status %s) before a guest report arrived; not qualified.\n' \
        "${LAUNCH_QEMU_STATUS:-unknown}" >&2
      return 5
      ;;
    *)
      printf '%s\n' 'MirrorOS qualify-install: internal contract violation: no launch outcome was recorded.' >&2
      return 6
      ;;
  esac

  # shellcheck disable=SC2034 # Read by install_write_result.
  INSTALL_VERDICT="$(node --input-type=module - "$report_path" "$run_id" "$evidence_run_dir" "$INSTALL_CASE" \
    "$INSTALL_EXPECTED_EXIT" "$INSTALL_EXPECTED_OUTCOME" "$INSTALL_EXPECTED_FAILED_OPERATION" \
    "$INSTALL_EXPECTED_HIBERNATION" <<'NODE'
import { readFileSync, writeFileSync, chmodSync, mkdirSync } from 'node:fs';

const [reportPath, runId, evidenceDir, caseName, expectedExitText, expectedOutcome, expectedFailedOperation, hibernationText] = process.argv.slice(2);
const expectedExit = Number(expectedExitText);
const hibernation = hibernationText === 'true';
const errors = [];
let report = null;
try {
  report = JSON.parse(readFileSync(reportPath, 'utf8'));
} catch {
  errors.push('the guest report is not valid JSON');
}
const isRecord = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const verdict = { errors, actual_exit: null, stderr_tail: '' };
if (report !== null) {
  if (!isRecord(report)) errors.push('the guest report must be an object');
  else {
    if (report.schema_version !== 1) errors.push('schema_version must be 1');
    if (report.run_id !== runId) errors.push('the report is not bound to this run');
    if (report.target !== 'reference-vm') errors.push('the report names an unexpected target');
    if (!Number.isInteger(report.exit_status)) errors.push('exit_status must be an integer');
    if (typeof report.stderr_tail !== 'string') errors.push('stderr_tail must be a string');
    if (!isRecord(report.install) || report.install.name !== caseName || !Number.isInteger(report.install.exit_status)
      || !isRecord(report.install.files) || !isRecord(report.install.observation)) {
      errors.push('the installation scenario requires a complete case report');
    }
  }
}
if (errors.length === 0) {
  const install = report.install;
  verdict.actual_exit = install.exit_status;
  verdict.stderr_tail = report.stderr_tail.slice(-2000);
  const files = install.files;
  const parse = name => {
    try { return JSON.parse(files[name]); } catch { return null; }
  };
  const run = parse('install-run.json');
  const approval = parse('approval-record.json');
  const engine = parse('engine/engine-run.json');
  const plan = parse('plans/01/installation-plan.json');
  const hostVendor = /^vendor_id\s*:\s*(\S+)/m.exec(readFileSync('/proc/cpuinfo', 'utf8'))?.[1];
  const microcode = { AuthenticAMD: ['amd-ucode', 'AuthenticAMD.bin'], GenuineIntel: ['intel-ucode', 'GenuineIntel.bin'] }[hostVendor];
  const entries = install.observation['boot-entries.txt'] ?? '';
  const allNames = [...Object.keys(files), ...Object.keys(install.observation)];
  if (allNames.some(name => name.split('/').some(part => !part || part === '.' || part === '..')
    || !/^[a-zA-Z0-9_./-]+$/.test(name))
    || [...Object.values(files), ...Object.values(install.observation)].some(content => typeof content !== 'string')) {
    errors.push('unsafe installation evidence path');
  }
  const engineExpected = expectedOutcome === 'installed' || expectedOutcome === 'failed';
  const required = ['install.log', 'install-run.json', 'approval-record.json', 'discovery/initial/target-facts.json',
    'plans/01/installation-plan.json', ...(engineExpected ? ['engine/engine-run.json', 'engine/engine.log', 'engine/state.json'] : [])];
  const checks = {
    preparation_succeeded: report.exit_status === 0,
    exits_as_expected: install.exit_status === expectedExit && run?.exit_status === expectedExit,
    outcomes_as_expected: run?.outcome === expectedOutcome && approval?.outcome === expectedOutcome,
    records_format_5: run?.format_version === 5 && approval?.format_version === 5,
    plan_format_4: plan?.format_version === 4,
    records_agree: run?.run_id === approval?.run_id && run?.final_digest === approval?.digest,
    evidence_complete: required.every(name => typeof files[name] === 'string'),
    engine_record_as_expected: engineExpected
      ? engine?.format_version === 2 && engine?.outcome === expectedOutcome && engine?.exit_status === expectedExit
        && (expectedOutcome === 'installed'
          ? engine.not_started?.length === 0 && engine.failed_operation === undefined
            && engine.postconditions?.status === 'passed' && engine.postconditions.failed_checks?.length === 0
            && engine.postconditions.checks?.length > 0 && engine.postconditions.checks.every(check => check.status === 'passed')
          : engine.failed_operation?.id === expectedFailedOperation && engine.not_started?.length > 0)
      : !Object.keys(files).some(name => name.startsWith('engine/')),
    resume_as_expected: expectedOutcome !== 'installed'
      || (hibernation
        ? Number.isInteger(engine?.resolved?.resume_offset) && engine.resolved.resume_offset > 0
          && /resume_offset=\d+/.test(entries) && /resume=UUID=/.test(entries)
        : engine?.resolved?.resume_offset === undefined && !/resume/.test(entries)),
    zswap_disabled: expectedOutcome !== 'installed' || /zswap\.enabled=0/.test(entries),
    microcode_as_expected: expectedOutcome !== 'installed' || (microcode !== undefined
      && plan?.hardware_selections?.rule_packages?.some(item => item.name === microcode[0])
      && (install.observation['microcode.txt'] ?? '').split(/\r?\n/).some(line => line.trim() === `kernel/x86/microcode/${microcode[1]}`)),
    private_permissions: install.private_permissions === true,
    plain_logs: ['install.log', 'engine/engine.log'].every(name => typeof files[name] !== 'string' || !files[name].includes('\u001b')),
  };
  verdict.install = {
    name: caseName,
    exit_status: install.exit_status,
    outcome: approval?.outcome ?? null,
    engine_outcome: engine?.outcome ?? null,
    failed_operation: engine?.failed_operation?.id ?? null,
    driver_tail: typeof install.driver_tail === 'string' ? install.driver_tail.slice(-2000) : '',
    ...checks,
    ok: Object.values(checks).every(Boolean),
  };
  if (errors.length === 0) {
    for (const [prefix, content] of [['install', files], ['observation', install.observation]]) {
      for (const [name, text] of Object.entries(content)) {
        const path = `${evidenceDir}/${prefix}/${name}`;
        mkdirSync(path.slice(0, path.lastIndexOf('/')), { recursive: true, mode: 0o700 });
        writeFileSync(path, text, { mode: 0o600 });
        chmodSync(path, 0o600);
      }
    }
  }
}
process.stdout.write(JSON.stringify(verdict));
process.exitCode = errors.length > 0 ? 5 : (verdict.install.ok ? 0 : 4);
NODE
  )" || status=$?
  outcome_record_tool_status guest_report_validation "$status"
  case "$status" in
    0) ;;
    4) printf '%s\n' 'MirrorOS qualify-install: the installation did not end as the case expects; not qualified.' >&2 ;;
    5) printf '%s\n' 'MirrorOS qualify-install: the guest report is incomplete, inconsistent, or not bound to this run; not qualified.' >&2 ;;
    *) printf 'MirrorOS qualify-install: guest report validation failed internally (status %s).\n' "$status" >&2 ;;
  esac
  if [[ -n "$INSTALL_VERDICT" ]]; then
    INSTALL_ACTUAL_EXIT="$(node -e 'const v = JSON.parse(process.argv[1]); process.stdout.write(v.actual_exit === null ? "" : String(v.actual_exit))' "$INSTALL_VERDICT" 2>/dev/null)" || INSTALL_ACTUAL_EXIT=''
  fi
  return "$status"
}

# Builds the QEMU command of the second boot from the fixed first-boot command: the ISO and the NoCloud medium are
# removed, and the monitor becomes a private socket in the run directory for the login driver. Nothing is added.
install_build_disk_boot_command() {
  local iso_path="$1"
  local evidence_dir="$2"
  local socket_path="$3"
  local index=0
  local argument
  local next
  local -a filtered=()

  # shellcheck disable=SC2153 # BUILD_RUN_DIR is set by discovery_run_prepare.
  launch_build_command "$iso_path" "${BUILD_RUN_DIR}/nocloud-seed.iso" "$evidence_dir"
  while [[ "$index" -lt "${#LAUNCH_QEMU_COMMAND[@]}" ]]; do
    argument="${LAUNCH_QEMU_COMMAND[$index]}"
    next="${LAUNCH_QEMU_COMMAND[$((index + 1))]:-}"
    case "${argument} ${next}" in
      '-drive if=none,id=iso,'* | '-drive if=none,id=seed,'* | '-device ide-cd,drive=iso,'* | '-device ide-cd,drive=seed,'*)
        index=$((index + 2))
        continue
        ;;
      '-monitor none')
        filtered+=(-monitor "unix:$(launch_escape_option_value "$socket_path"),server=on,wait=off")
        index=$((index + 2))
        continue
        ;;
    esac
    filtered+=("$argument")
    index=$((index + 1))
  done
  # A virtual display adapter lets the login driver keep a screendump of tty1 as private diagnostics; the guest sees
  # no extra input or storage device.
  filtered+=(-vga std)
  LAUNCH_QEMU_COMMAND=("${filtered[@]}")
}

# Types the user name and the canary at tty1 through the QEMU monitor, then proves the login by making the shell
# write a marker with its own user name to the serial port through sudo. The canary only travels host-side, in the environment of
# this driver and through the monitor; it never reaches the serial console, which only receives the marker.
# Prints one JSON document with one entry per user. Status 0 when every user logged in, 1 otherwise.
install_login_driver() {
  local socket_path="$1"
  local serial_path="$2"
  local qemu_pid="$3"
  local deadline_seconds="$4"
  local nonce="$5"
  local screen_path="$6"
  shift 6

  # shellcheck disable=SC2153 # EVIDENCE_RUN_DIR is assigned by discovery_run_prepare.
  MIRROROS_LOGIN_CANARY="$INSTALL_CANARY" node --input-type=module - "$socket_path" "$serial_path" "$qemu_pid" \
    "$deadline_seconds" "$nonce" "$REFERENCE_VM_LOGIN_FIRST_WAIT_SECONDS" "$REFERENCE_VM_LOGIN_INTERVAL_SECONDS" \
    "$screen_path" "${EVIDENCE_RUN_DIR}/install/plans/01/installation-plan.json" "$@" <<'NODE'
import { connect } from 'node:net';
import { readFileSync, existsSync } from 'node:fs';

const [socketPath, serialPath, pidText, deadlineText, nonce, firstWaitText, intervalText, screenPath, planPath, ...users] = process.argv.slice(2);
const plan = JSON.parse(readFileSync(planPath, 'utf8'));
const sysctlKeys = ['vm.swappiness', 'vm.page-cluster', 'vm.watermark_scale_factor', 'vm.watermark_boost_factor'];
const memory = plan.operations.find(item => item.kind === 'configure_memory_reclaim').parameters;
const zram = plan.operations.find(item => item.kind === 'configure_zram').parameters;
const canary = process.env.MIRROROS_LOGIN_CANARY;
delete process.env.MIRROROS_LOGIN_CANARY;
const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
const keys = { '.': 'dot', '_': 'shift-minus', ' ': 'spc', '-': 'minus', '>': 'shift-dot', '/': 'slash', $: 'shift-4', '(': 'shift-9', ')': 'shift-0', "'": 'apostrophe', '|': 'shift-backslash', ';': 'semicolon' };
const alive = () => { try { process.kill(Number(pidText), 0); return true; } catch { return false; } };
const serial = () => (existsSync(serialPath) ? readFileSync(serialPath, 'utf8') : '');
const deadline = Date.now() + Number(deadlineText) * 1000;

const connectMonitor = async () => {
  while (Date.now() < deadline) {
    const socket = await new Promise(resolve => {
      const candidate = connect(socketPath);
      candidate.once('connect', () => resolve(candidate));
      candidate.once('error', () => resolve(null));
    });
    if (socket !== null) {
      socket.on('data', () => {});
      socket.on('error', () => {});
      return socket;
    }
    await sleep(500);
  }
  return null;
};
const type = async (socket, text) => {
  for (const character of text) {
    const key = /[A-Z]/.test(character) ? `shift-${character.toLowerCase()}` : (keys[character] ?? character);
    socket.write(`sendkey ${key}\n`);
    await sleep(60);
  }
};
const enter = async socket => {
  socket.write('sendkey ret\n');
  await sleep(200);
};

const results = {};
let firstBoot = null;
const socket = await connectMonitor();
if (socket !== null) {
  await sleep(Number(firstWaitText) * 1000);
  for (const user of users) {
    results[user] = false;
    while (Date.now() < deadline && alive() && !results[user]) {
      await enter(socket);
      await type(socket, user);
      await enter(socket);
      await sleep(2000);
      await type(socket, canary);
      await enter(socket);
      await sleep(5000);
      // The serial device is not writable by a normal user, so sudo (which also proves the account may use it)
      // writes the marker; the canary is the sudo password, read from stdin, and only the marker reaches the serial.
      await type(socket, `echo ${canary}|sudo -S sh -c 'echo login-${nonce}-'$(id -un)'>/dev/ttyS0'`);
      await enter(socket);
      await sleep(3000);
      results[user] = serial().includes(`login-${nonce}-${user}`);
      if (results[user]) {
        if (firstBoot === null) {
          await type(socket, `echo ${canary}|sudo -S sh -c '(echo boot-${nonce}-begin; cat /sys/module/zswap/parameters/enabled; sysctl -n ${sysctlKeys.join(' ')}; cat /proc/swaps; echo boot-${nonce}-end)>/dev/ttyS0'`);
          await enter(socket);
          while (Date.now() < deadline && alive() && !serial().includes(`boot-${nonce}-end`)) await sleep(500);
          const block = serial().split(`boot-${nonce}-begin`).at(-1).split(`boot-${nonce}-end`)[0].trim().split(/\r?\n/);
          const swaps = block.slice(6).filter(line => line.trim() !== '').map(line => line.trim().split(/\s+/));
          const swapfile = plan.choices.storage_option.value === 'ext4-systemd-boot' ? '/swapfile' : '/swap/swapfile';
          const hibernation = plan.choices.hibernation.value;
          const checks = {
            zswap_disabled: block[0] === 'N',
            memory_sysctl_as_expected: sysctlKeys.every((key, index) => block[index + 1] === String(memory[key])),
            zram_active: swaps.some(row => row[0] === '/dev/zram0' && row[1] === 'partition' && Number(row[2]) > 0 && Number(row[4]) === zram.swap_priority),
            swap_as_expected: swaps.length === (hibernation ? 2 : 1)
              && swaps.filter(row => row[0] === '/dev/zram0').length === 1
              && (hibernation ? swaps.some(row => row[0] === swapfile && row[1] === 'file' && Number(row[2]) > 0 && row[4] === '0') : true),
          };
          firstBoot = { ...checks, ok: serial().includes(`boot-${nonce}-end`) && Object.values(checks).every(Boolean) };
        }
        socket.write(`screendump ${screenPath}\n`);
        await sleep(1000);
        await type(socket, 'exit');
        await enter(socket);
        await sleep(2000);
      } else {
        // Private diagnostics: the last screen of tty1 after a failed attempt (a typed password is never echoed).
        socket.write(`screendump ${screenPath}\n`);
        await sleep(Number(intervalText) * 1000);
      }
    }
  }
  socket.destroy();
}
process.stdout.write(JSON.stringify({ monitor_connected: socket !== null, qemu_alive: alive(), logins: results, first_boot: firstBoot }));
process.exitCode = users.every(user => results[user] === true) && firstBoot?.ok === true ? 0 : 1;
NODE
}

# Stops the first boot, boots the disk alone, and drives the logins. Sets INSTALL_LOGIN_JSON.
# Statuses: 0 logins and selected first-boot checks passed, 4 a gate failed, 5 the VM could not be handled.
install_run_disk_boot() {
  local iso_path="$1"
  # shellcheck disable=SC2153 # EVIDENCE_RUN_DIR is set by discovery_run_prepare.
  local boot_evidence_dir="${EVIDENCE_RUN_DIR}/disk-boot"
  local socket_path
  local nonce
  local status=0

  if ! stop_cleanup_stop_qemu; then
    return 5
  fi
  LAUNCH_QEMU_PID=''
  LAUNCH_QEMU_STATUS=''
  mkdir -m 700 -- "$boot_evidence_dir" || return 5
  INSTALL_MONITOR_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mirroros-monitor.XXXXXX")" || return 5
  socket_path="${INSTALL_MONITOR_DIR}/${INSTALL_MONITOR_NAME}"
  # shellcheck disable=SC2153 # RUN_ID is set by run_resources_new_id.
  nonce="${RUN_ID: -12}"
  install_build_disk_boot_command "$iso_path" "$boot_evidence_dir" "$socket_path"
  printf 'MirrorOS qualify-install: run %s: booting the installed disk alone.\n' "$RUN_ID" >&2
  launch_start "$boot_evidence_dir" || return 5

  INSTALL_LOGIN_JSON="$(install_login_driver "$socket_path" "$LAUNCH_SERIAL_PATH" "$LAUNCH_QEMU_PID" \
    "$REFERENCE_VM_GLOBAL_DEADLINE_SECONDS" "$nonce" "${boot_evidence_dir}/screen.ppm" "${INSTALL_BOOT_USERS[@]}")" || status=$?
  [[ -n "$INSTALL_LOGIN_JSON" ]] || INSTALL_LOGIN_JSON='null'
  outcome_record_tool_status login_driver "$status"
  if [[ "$status" -ne 0 ]]; then
    printf 'MirrorOS qualify-install: a login or selected first-boot check failed on the installed disk; not qualified.\n' >&2
    return 4
  fi
}

# Scans the retained evidence for the run's canary. Findings keep the run private and yield 2.
install_scan_canary() {
  local evidence_dir="$1"
  local status=0

  grep -rqF -- "$INSTALL_CANARY" "$evidence_dir" >/dev/null 2>&1 || status=$?
  outcome_record_tool_status canary_scan "$status"
  case "$status" in
    1) outcome_set_scan canary passed ;;
    0)
      outcome_set_scan canary findings
      outcome_mark_failure 2 canary-scan
      printf 'MirrorOS qualify-install: the run canary appears in the evidence, which stays private at %s.\n' "$evidence_dir" >&2
      return 2
      ;;
    *)
      outcome_set_scan canary failed
      outcome_mark_failure 5 canary-scan
      return 5
      ;;
  esac
}

install_next_action() {
  case "$OUTCOME_PRIMARY_STATUS" in
    0) ;;
    2) printf '%s' 'Resolve the reported input, prerequisite, canary, or secret-scan finding, then rerun; findings stay private under the run evidence directory.' ;;
    4) printf '%s' 'Inspect result.json, install/, observation/, and the private serial logs, fix the cause, then rerun.' ;;
    5) printf '%s' 'Review qemu-diagnostics.log, the disk comparison, and the cleanup outcome; see docs/procedures/test.md before rerunning.' ;;
    6) printf '%s' 'Restore the checkout from Git or report the internal contract violation.' ;;
    130 | 143) printf '%s' 'The run was interrupted; rerun when ready.' ;;
    *) printf '%s' 'Review the run evidence and docs/procedures/test.md.' ;;
  esac
}

# Writes evidence/reference-vm/install/<run-id>/result.json atomically with mode 0600.
install_write_result() {
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
    "${EVIDENCE_RUN_DIR}/result.json" "$RUN_ID" "$INSTALL_CASE" "$INSTALL_EXPECTED_EXIT" "$INSTALL_EXPECTED_OUTCOME" \
    "$INSTALL_COMPARISON" "$counted" "$DISCOVERY_OVERLAY" "$OUTCOME_PRIMARY_STATUS" "$OUTCOME_FAILED_STAGE" \
    "$(install_next_action)" "$duration" "$OUTCOME_TEST_COMMIT" "$OUTCOME_TEST_DIRTY" "$QUALIFY_BUNDLE_ADMISSION" \
    "$LAUNCH_VM_CONFIGURATION_JSON" "$LAUNCH_QEMU_VERSION" "$LAUNCH_OVMF_VERSION" "$INSTALL_VERDICT" \
    "$INSTALL_LOGIN_JSON" "$OUTCOME_CLEANUP_OUTCOME" "$OUTCOME_CLEANUP_GUIDANCE" "$REFERENCE_VM_INSTALL_DEADLINE_SECONDS" \
    "${#tool_arguments[@]}" "${tool_arguments[@]}" \
    "${#scan_arguments[@]}" "${scan_arguments[@]}" \
    "${#OUTCOME_LEFTOVERS[@]}" "${OUTCOME_LEFTOVERS[@]}" <<'NODE' || generator_status=$?
import { chmodSync, renameSync, writeFileSync } from 'node:fs';

const args = process.argv.slice(2);
const [
  outputPath, runId, caseName, expectedExitText, expectedOutcome, comparison, counted, overlay,
  statusText, failedStage, nextAction, durationText, commit, dirtyText, admissionText,
  vmText, qemuVersion, ovmfVersion, verdictText, loginText, cleanupOutcome, guidance, deadlineText,
] = args;
let cursor = 23;
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
let login = null;
try {
  login = loginText === '' ? null : JSON.parse(loginText);
} catch {
  login = null;
}
const accepted = verdict !== null && Array.isArray(verdict.errors) && verdict.errors.length === 0;
const document = {
  schema_version: 1,
  kind: 'installation_qualification',
  run_id: runId,
  case: caseName,
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
  install_deadline_seconds: Number(deadlineText),
  versions: { qemu: qemuVersion, ovmf: ovmfVersion },
  expected: { exit: Number(expectedExitText), outcome: expectedOutcome },
  install: accepted ? verdict.install : null,
  boot: login,
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
    printf 'MirrorOS qualify-install: could not write a valid result document (status %s).\n' "$generator_status" >&2
    return 5
  fi
}

# Scans for the canary, writes the result, scans the evidence including it, rewrites the result when a scan does
# not pass, and prints a summary derived from the same facts.
install_finalize_evidence() {
  install_scan_canary "$EVIDENCE_RUN_DIR" || true
  outcome_set_scan evidence passed
  outcome_record_tool_status evidence_scan 0
  if ! install_write_result; then
    outcome_mark_failure 5 result-write
    return 5
  fi
  if ! evidence_scan "$EVIDENCE_RUN_DIR"; then
    if ! install_write_result; then
      outcome_mark_failure 5 result-write
      return 5
    fi
  fi
  printf 'MirrorOS qualify-install: case %s, expected exit %s, actual exit %s, disks %s, status %s%s.\n' \
    "$INSTALL_CASE" "$INSTALL_EXPECTED_EXIT" "${INSTALL_ACTUAL_EXIT:-none}" "$INSTALL_COMPARISON" \
    "$OUTCOME_PRIMARY_STATUS" "$(if [[ "$DISCOVERY_OVERLAY" -eq 1 ]]; then printf ', development overlay (not counted)'; fi)"
  printf 'Evidence: %s\n' "$EVIDENCE_RUN_DIR"
}
