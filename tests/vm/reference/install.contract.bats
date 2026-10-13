load discovery-support

# Contract tests for qualify-install (Story 2.5) with doubles for QEMU, xorriso, qemu-img, and Gitleaks.
# REFERENCE_INSTALL_CASE: the case whose guest report the QEMU double emits (default, limine-nohib, ext4, failure, cancel-password).
# REFERENCE_INSTALL_BAD: wrong-exit | missing-engine | canary-leak | no-resume makes the report wrong in one way.
# REFERENCE_INSTALL_LOGIN: ok (default) | none; none makes the second boot never log in.
# REFERENCE_COMPARE_STATUS: qemu-img compare status (0 identical, 1 different, 2 error).

setup() {
  reference_setup
  reference_prepare_e2e
  reference_install_install_doubles
  cp -a -- "${REFERENCE_TEST_SOURCE_ROOT}/install" "${REFERENCE_TEST_SOURCE_ROOT}/hardware" \
    "${REFERENCE_TEST_SOURCE_ROOT}/targets" "${REFERENCE_REPOSITORY_ROOT}/"
  # The login timings are versioned configuration; the copy shortens them so that the suite stays fast.
  sed -i -e 's/^REFERENCE_VM_LOGIN_FIRST_WAIT_SECONDS=.*/REFERENCE_VM_LOGIN_FIRST_WAIT_SECONDS=0/' \
    -e 's/^REFERENCE_VM_LOGIN_INTERVAL_SECONDS=.*/REFERENCE_VM_LOGIN_INTERVAL_SECONDS=1/' \
    -e 's/^REFERENCE_VM_GLOBAL_DEADLINE_SECONDS=.*/REFERENCE_VM_GLOBAL_DEADLINE_SECONDS=40/' \
    "${REFERENCE_REPOSITORY_ROOT}/vm/reference/reference-vm.conf"
  git -C "$REFERENCE_REPOSITORY_ROOT" add -A
  git -C "$REFERENCE_REPOSITORY_ROOT" -c user.name=Test -c user.email=test@example.invalid \
    -c commit.gpgsign=false commit -q -m embedded
  REFERENCE_HEAD="$(git -C "$REFERENCE_REPOSITORY_ROOT" rev-parse HEAD)"
  REFERENCE_CANARY_FILE="${REFERENCE_TEST_ROOT}/canary.txt"
  REFERENCE_TYPED_FILE="${REFERENCE_TEST_ROOT}/typed.txt"
  export REFERENCE_CANARY_FILE REFERENCE_TYPED_FILE
}

teardown() {
  pkill -f -- "sleep 31" 2>/dev/null || true
  reference_teardown
}

use_matching_bundle() {
  reference_set_bundle_build "$REFERENCE_BUNDLE_DIR" "$REFERENCE_HEAD" false
}

# Replaces the doubles with ones that emulate the guest installer report and the installed disk.
reference_install_install_doubles() {
  rm -f -- "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" "${REFERENCE_DOUBLE_DIR}/qemu-img" \
    "${REFERENCE_DOUBLE_DIR}/xorriso"

  cat > "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" <<'EOF'
#!/usr/bin/bash
printf 'qemu-system-x86_64 %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
if [[ "${1:-}" == '--version' ]]; then
  echo 'QEMU emulator version 9.9.9'
  exit 0
fi
serial=''
monitor=''
previous=''
for argument in "$@"; do
  [[ "$previous" == '-monitor' ]] && monitor="$argument"
  previous="$argument"
  [[ "$argument" == '-S' ]] && exit 0
  [[ "$argument" == file:*guest-serial.log ]] && serial="${argument#file:}"
done
if [[ "$monitor" == unix:* ]]; then
  # Second boot: a monitor server that decodes the typed keys and answers on the serial file like a logged-in shell.
  socket="${monitor#unix:}"
  socket="${socket%%,*}"
  exec node - "$socket" "$serial" "${REFERENCE_INSTALL_LOGIN:-ok}" <<'JS'
const { createServer } = require('node:net');
const { appendFileSync } = require('node:fs');
const [socketPath, serialPath, mode] = process.argv.slice(2);
const names = { dot: '.', 'shift-minus': '_', semicolon: ';', spc: ' ', minus: '-', 'shift-dot': '>', slash: '/', 'shift-4': '$', 'shift-9': '(', 'shift-0': ')', apostrophe: "'", 'shift-backslash': '|' };
let line = '';
const lines = [];
createServer(socket => {
  socket.on('data', chunk => {
    for (const command of chunk.toString().split('\n')) {
      const match = /^sendkey (\S+)$/.exec(command);
      if (match === null) continue;
      if (match[1] !== 'ret') {
        // QEMU has no uppercase key names; a capital letter arrives as shift-<letter>.
        const upper = /^shift-([a-z])$/.exec(match[1]);
        line += upper === null ? (names[match[1]] ?? match[1]) : upper[1].toUpperCase();
        continue;
      }
      // A logged-in shell leaves its session on exit; the next lines start a new login.
      if (line === 'exit') lines.length = 0;
      else if (line !== '') lines.push(line);
      line = '';
      if (lines.length === 1 && lines[0].includes('boot-')) {
        const command = lines.pop();
        const nonce = /echo boot-([0-9a-f]+)-begin/.exec(command)?.[1];
        const bad = process.env.REFERENCE_INSTALL_BOOT_BAD;
        if (nonce !== undefined && bad !== 'missing'
          && command.includes('sysctl -n vm.swappiness vm.page-cluster vm.watermark_scale_factor vm.watermark_boost_factor;')
          && command.endsWith(")>/dev/ttyS0'")) {
          const hibernation = ['default', 'ext4'].includes(process.env.REFERENCE_INSTALL_CASE);
          const swapfile = process.env.REFERENCE_INSTALL_CASE === 'ext4' ? '/swapfile' : '/swap/swapfile';
          appendFileSync(serialPath, `boot-${nonce}-begin\n${bad === 'zswap' ? 'Y' : 'N'}\n${bad === 'sysctl' ? '60' : '180'}\n0\n125\n0\nFilename Type Size Used Priority\n${bad === 'zram' ? '' : '/dev/zram0 partition 2097148 0 100\n'}${hibernation && bad !== 'swap' ? `${swapfile} file 4194300 0 0\n` : ''}boot-${nonce}-end\n`);
        }
        continue;
      }
      if (lines.length === 3) {
        const [user, password, typed] = lines.splice(0, 3);
        // The marker command must go through sudo with the password on stdin, as a normal user cannot write the port.
        const nonce = /\|sudo -S sh -c 'echo login-([0-9a-f]+)-'\$\(id -un\)'>\/dev\/ttyS0'$/.exec(typed)?.[1];
        appendFileSync(process.env.REFERENCE_TYPED_FILE, `${user} ${password}\n`);
        if (mode === 'ok' && nonce !== undefined) appendFileSync(serialPath, `login-${nonce}-${user}\r\n`);
      }
    }
  });
}).listen(socketPath);
JS
fi
run_id="$(basename "$(dirname "$serial")")"
printf 'SERIAL-NOISE-MARKER\r\n' >> "$serial"
case "${REFERENCE_QEMU_MODE:-pass}" in
  exit) exit 3 ;;
  hang) ;;
  pass)
    canary="$(cat "${REFERENCE_CANARY_FILE:?}")"
    # shellcheck disable=SC2016 # Literal Node program with explicit arguments.
    report="$(node -e '
      const [runId, name, bad, canary] = process.argv.slice(1);
      const digest = "a".repeat(64);
      const expected = {
        default: [0, "installed"], "limine-nohib": [0, "installed"], ext4: [0, "installed"], "btrfs-rescue": [0, "installed"], failure: [5, "failed"], "cancel-password": [3, "cancelled"],
      }[name];
      const exit = bad === "wrong-exit" ? 1 : expected[0];
      const common = { format_version: bad === "old-record" ? 4 : 5, run_id: "install-run", outcome: expected[1] };
      const vendor = /^vendor_id\s*:\s*(\S+)/m.exec(require("node:fs").readFileSync("/proc/cpuinfo", "utf8"))?.[1];
      const microcode = vendor === "AuthenticAMD" ? ["amd-ucode", "AuthenticAMD.bin"] : ["intel-ucode", "GenuineIntel.bin"];
      const plan = { format_version: 4, choices: { storage_option: { value: name === "ext4" ? "ext4-systemd-boot" : "btrfs-limine" }, hibernation: { value: name === "default" || name === "ext4" } },
        hardware_selections: { rule_packages: [{ name: microcode[0] }] }, operations: [
          { kind: "configure_zram", parameters: { swap_priority: 100 } },
          { kind: "configure_memory_reclaim", parameters: { "vm.swappiness": 180, "vm.page-cluster": 0, "vm.watermark_scale_factor": 125, "vm.watermark_boost_factor": 0 } },
        ] };
      const files = {
        "install-run.json": JSON.stringify({ ...common, exit_status: exit, final_digest: digest }),
        "approval-record.json": JSON.stringify({ ...common, digest }),
        "install.log": bad === "canary-leak" ? `password was ${canary}\n` : "plain log\n",
        "discovery/initial/target-facts.json": "{}",
        "plans/01/installation-plan.json": JSON.stringify(plan),
      };
      if (expected[1] !== "cancelled" && bad !== "missing-engine") {
        const engine = { format_version: 2, postconditions: { status: bad === "postconditions" ? "failed" : "passed", failed_checks: [], checks: [{ id: "kernel_installed", status: "passed" }] }, outcome: expected[1], exit_status: exit, reasons: [], completed: [], not_started: [] };
        const hibernating = name === "ext4" || name === "default";
        if (hibernating) engine.resolved = { resume_offset: bad === "no-resume" ? undefined : 1234 };
        if (name === "failure") { engine.failed_operation = { id: "install_packages", command: ["pacstrap"] }; engine.not_started = ["generate_fstab"]; }
        files["engine/engine-run.json"] = JSON.stringify(engine);
        files["engine/engine.log"] = "engine output\n";
        files["engine/state.json"] = "{}";
      }
      const hibernation = name === "ext4" || name === "default";
      const observation = hibernation && bad !== "no-resume"
        ? { "boot-entries.txt": "options root=UUID=x rw zswap.enabled=0 resume=UUID=x resume_offset=1234\n" }
        : name === "failure" || name === "cancel-password" ? {} : { "boot-entries.txt": "options root=UUID=x rw zswap.enabled=0\n" };
      if (expected[1] === "installed") observation["microcode.txt"] = bad === "microcode" ? "" : `kernel/x86/microcode/${microcode[1]}\n`;
      process.stdout.write(JSON.stringify({
        schema_version: 1, run_id: runId, target: "reference-vm", exit_status: 0, facts: null, error: null, stderr_tail: "",
        install: { name, exit_status: exit, files, observation, private_permissions: true, driver_tail: "" },
      }));
    ' "$run_id" "${REFERENCE_INSTALL_CASE:?}" "${REFERENCE_INSTALL_BAD:-}" "$canary")"
    printf 'MIRROROS-REPORT-BEGIN %s\r\n%s\r\nMIRROROS-REPORT-END %s\r\n' "$run_id" "$report" "$run_id" >> "$serial"
    ;;
esac
exec sleep 31
EOF
  cat > "${REFERENCE_DOUBLE_DIR}/qemu-img" <<'EOF'
#!/usr/bin/bash
printf 'qemu-img %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
case "$1" in
  create) : > "$5" ;;
  compare) exit "${REFERENCE_COMPARE_STATUS:-0}" ;;
esac
EOF
  cat > "${REFERENCE_DOUBLE_DIR}/xorriso" <<'EOF'
#!/usr/bin/bash
printf 'xorriso %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
for argument in "$@"; do
  if [[ "$argument" == user-data=* ]]; then
    sed -n "s/^MIRROROS_INSTALL_CANARY='\\(.*\\)'\$/\\1/p" "${argument#user-data=}" > "${REFERENCE_CANARY_FILE:?}"
  fi
done
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == '-output' ]]; then printf 'seed' > "$2"; fi
  shift
done
EOF
  chmod 755 "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" "${REFERENCE_DOUBLE_DIR}/qemu-img" "${REFERENCE_DOUBLE_DIR}/xorriso"
}

reference_invoke_install() {
  local command_path="${REFERENCE_REPOSITORY_ROOT}/vm/reference/qualify-install"

  : > "$REFERENCE_CALL_LOG"
  if (
    cd -- "$REFERENCE_OUTSIDE_DIR" || exit 125
    PATH="${REFERENCE_DOUBLE_DIR}:${PATH}" \
      REFERENCE_CALL_LOG="$REFERENCE_CALL_LOG" \
      "$command_path" "$@"
  ) > "$REFERENCE_STDOUT_PATH" 2> "$REFERENCE_STDERR_PATH"; then
    REFERENCE_COMMAND_STATUS=0
  else
    # shellcheck disable=SC2034 # Read by the tests.
    REFERENCE_COMMAND_STATUS=$?
  fi
}

install_evidence_dir() {
  local -a runs=("${REFERENCE_REPOSITORY_ROOT}"/evidence/reference-vm/install/*/)

  [[ "${#runs[@]}" -eq 1 && -d "${runs[0]}" ]] || return 1
  printf '%s' "${runs[0]%/}"
}

install_result_field() {
  node -e '
    const result = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    const value = process.argv[2].split(".").reduce((node, key) => node?.[key], result);
    process.stdout.write(String(value));
  ' "$(install_evidence_dir)/result.json" "$1"
}

@test "--help prints help and exits 0 without invoking any domain tool" {
  run "${REFERENCE_REPOSITORY_ROOT}/vm/reference/qualify-install" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'qualify-install'* ]]
  [[ "$output" == *'cancel-password'* ]]
  [ ! -s "$REFERENCE_CALL_LOG" ]
}

@test "missing, unknown, or malformed arguments exit 2 before any run resource exists" {
  local -a invalid=(
    ''
    '--case'
    '--case unknown BUNDLE'
    '--case ext4'
    '--case ext4 BUNDLE EXTRA'
    '--unknown --case ext4 BUNDLE'
    '--case ext4 --case failure BUNDLE'
  )
  local arguments

  for arguments in "${invalid[@]}"; do
    # shellcheck disable=SC2086 # Word splitting builds the argument vector.
    reference_invoke_install ${arguments//BUNDLE/$REFERENCE_BUNDLE_DIR}
    [ "$REFERENCE_COMMAND_STATUS" -eq 2 ]
  done
  [ ! -e "${REFERENCE_REPOSITORY_ROOT}/evidence" ]
  [ ! -e "${REFERENCE_REPOSITORY_ROOT}/build" ]
}

@test "the default and limine-nohib cases are enabled, log in as the user, and expect resume only with hibernation" {
  use_matching_bundle
  local case_name

  for case_name in default limine-nohib btrfs-rescue; do
    rm -rf -- "${REFERENCE_REPOSITORY_ROOT}/evidence" "${REFERENCE_REPOSITORY_ROOT}/build"
    export REFERENCE_INSTALL_CASE="$case_name"
    reference_invoke_install --case "$case_name" "$REFERENCE_BUNDLE_DIR"
    [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
    [ "$(install_result_field boot.logins.mirroros)" == 'true' ]
    [ "$(install_result_field counted)" == 'true' ]
    [ "$(install_result_field install.resume_as_expected)" == 'true' ]
    [ "$(install_result_field install.microcode_as_expected)" == 'true' ]
    [ "$(install_result_field boot.first_boot.ok)" == 'true' ]
  done
}

@test "the reference VM configuration is version 2 and carries the installation deadline and login timings" {
  local config="${REFERENCE_TEST_SOURCE_ROOT}/vm/reference/reference-vm.conf"

  grep -qx 'REFERENCE_VM_CONFIG_VERSION=2' "$config"
  grep -qx 'REFERENCE_VM_INSTALL_DEADLINE_SECONDS=2700' "$config"
  grep -q '^REFERENCE_VM_LOGIN_FIRST_WAIT_SECONDS=[0-9]\+$' "$config"
  grep -q '^REFERENCE_VM_LOGIN_INTERVAL_SECONDS=[0-9]\+$' "$config"
}

@test "a configuration without a usable installation deadline exits 6 before any run resource exists" {
  use_matching_bundle
  sed -i '/^REFERENCE_VM_INSTALL_DEADLINE_SECONDS=/d' "${REFERENCE_REPOSITORY_ROOT}/vm/reference/reference-vm.conf"

  reference_invoke_install --case failure "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 6 ]
  [ ! -e "${REFERENCE_REPOSITORY_ROOT}/build" ]
}

@test "the failure case expects failed/5 at install_packages and records a counted run without a second boot" {
  use_matching_bundle
  export REFERENCE_INSTALL_CASE=failure

  reference_invoke_install --case failure "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
  local evidence
  evidence="$(install_evidence_dir)"
  [ "$(install_result_field kind)" == 'installation_qualification' ]
  [ "$(install_result_field case)" == 'failure' ]
  [ "$(install_result_field install.failed_operation)" == 'install_packages' ]
  [ "$(install_result_field install.ok)" == 'true' ]
  [ "$(install_result_field counted)" == 'true' ]
  [ "$(install_result_field scans.canary)" == 'passed' ]
  [ "$(install_result_field scans.evidence)" == 'passed' ]
  [ "$(install_result_field boot)" == 'null' ]
  [ ! -e "${evidence}/disk-boot" ]
  [ "$(grep -c '^qemu-system-x86_64 .*-serial file:' "$REFERENCE_CALL_LOG")" -eq 1 ]
  [ "$(stat -c '%a' "$evidence")" == '700' ]
  [ "$(stat -c '%a' "${evidence}/result.json")" == '600' ]
  [ -z "$(find "$evidence" -perm /077)" ]
  [ -f "${evidence}/install/engine/engine-run.json" ]
  [ ! -e "${REFERENCE_REPOSITORY_ROOT}/build/reference-vm/${evidence##*/}" ]
}

@test "cancel-password expects exit 3 and an identical disk, and a changed disk fails with 4" {
  use_matching_bundle
  export REFERENCE_INSTALL_CASE=cancel-password

  reference_invoke_install --case cancel-password "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
  [ "$(install_result_field disk_identity.comparison)" == 'identical' ]
  [ "$(install_result_field install.outcome)" == 'cancelled' ]
  [ ! -e "$(install_evidence_dir)/install/engine" ]

  rm -rf -- "${REFERENCE_REPOSITORY_ROOT}/evidence" "${REFERENCE_REPOSITORY_ROOT}/build"
  export REFERENCE_COMPARE_STATUS=1
  reference_invoke_install --case cancel-password "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 4 ]
  [ "$(install_result_field failed_stage)" == 'disk-identity' ]
  [ "$(install_result_field counted)" == 'false' ]
}

@test "a comparison tool failure yields 5 and is never reported as identical" {
  use_matching_bundle
  export REFERENCE_INSTALL_CASE=cancel-password REFERENCE_COMPARE_STATUS=2

  reference_invoke_install --case cancel-password "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 5 ]
  [ "$(install_result_field disk_identity.comparison)" == 'error' ]
}

@test "the ext4 case boots the disk alone, logs in as the user and root, and records a counted run" {
  use_matching_bundle
  export REFERENCE_INSTALL_CASE=ext4

  reference_invoke_install --case ext4 "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
  local evidence canary
  evidence="$(install_evidence_dir)"
  canary="$(cat "$REFERENCE_CANARY_FILE")"
  [[ "$canary" =~ ^[0-9a-f]{24}$ ]]
  [ "$(install_result_field boot.logins.mirroros)" == 'true' ]
  [ "$(install_result_field boot.logins.root)" == 'true' ]
  [ "$(install_result_field counted)" == 'true' ]
  [ "$(install_result_field install.resume_as_expected)" == 'true' ]
  # Both logins typed the run canary and nothing else.
  [ "$(cat "$REFERENCE_TYPED_FILE")" == "$(printf 'mirroros %s\nroot %s' "$canary" "$canary")" ]
  # The second boot has neither the ISO nor the NoCloud medium, and a private monitor socket.
  local boot_command
  boot_command="$(grep '^qemu-system-x86_64 .*-serial file:' "$REFERENCE_CALL_LOG" | tail -n 1)"
  [[ "$boot_command" != *'id=iso'* ]]
  [[ "$boot_command" != *'id=seed'* ]]
  [[ "$boot_command" == *'-monitor unix:'* ]]
  [[ "$boot_command" == *"disk-boot/guest-serial.log"* ]]
  [ "$(grep -c '^qemu-system-x86_64 .*-serial file:' "$REFERENCE_CALL_LOG")" -eq 2 ]
  [ -d "${evidence}/disk-boot" ]
  ! grep -rqF -- "$canary" "$evidence"
}

@test "a failed login on the installed disk fails with 4 and is never counted" {
  use_matching_bundle
  export REFERENCE_INSTALL_CASE=ext4 REFERENCE_INSTALL_LOGIN=none

  reference_invoke_install --case ext4 "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 4 ]
  [ "$(install_result_field failed_stage)" == 'disk-boot-login' ]
  [ "$(install_result_field boot.logins.mirroros)" == 'false' ]
  [ "$(install_result_field counted)" == 'false' ]
}

@test "a report with the wrong exit, a missing engine record, or no resume offset fails with 4" {
  use_matching_bundle
  local bad

  for bad in wrong-exit missing-engine; do
    rm -rf -- "${REFERENCE_REPOSITORY_ROOT}/evidence" "${REFERENCE_REPOSITORY_ROOT}/build"
    export REFERENCE_INSTALL_CASE=failure REFERENCE_INSTALL_BAD="$bad"
    reference_invoke_install --case failure "$REFERENCE_BUNDLE_DIR"
    [ "$REFERENCE_COMMAND_STATUS" -eq 4 ]
    [ "$(install_result_field failed_stage)" == 'installation-outcome' ]
    [ "$(install_result_field counted)" == 'false' ]
  done
  rm -rf -- "${REFERENCE_REPOSITORY_ROOT}/evidence" "${REFERENCE_REPOSITORY_ROOT}/build"
  export REFERENCE_INSTALL_CASE=ext4 REFERENCE_INSTALL_BAD=no-resume
  reference_invoke_install --case ext4 "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 4 ]
  [ "$(install_result_field install.resume_as_expected)" == 'false' ]
}

@test "old records, failed postconditions, or missing host microcode prevent qualification" {
  use_matching_bundle
  local bad
  for bad in old-record postconditions microcode; do
    rm -rf -- "${REFERENCE_REPOSITORY_ROOT}/evidence" "${REFERENCE_REPOSITORY_ROOT}/build"
    export REFERENCE_INSTALL_CASE=ext4 REFERENCE_INSTALL_BAD="$bad"
    reference_invoke_install --case ext4 "$REFERENCE_BUNDLE_DIR"
    [ "$REFERENCE_COMMAND_STATUS" -eq 4 ]
    [ "$(install_result_field counted)" == 'false' ]
    [ "$(install_result_field failed_stage)" == 'installation-outcome' ]
  done
}

@test "each selected first-boot observation is gating, including a missing report" {
  use_matching_bundle
  local bad
  for bad in zswap sysctl zram swap missing; do
    rm -rf -- "${REFERENCE_REPOSITORY_ROOT}/evidence" "${REFERENCE_REPOSITORY_ROOT}/build"
    export REFERENCE_INSTALL_CASE=ext4 REFERENCE_INSTALL_BOOT_BAD="$bad"
    reference_invoke_install --case ext4 "$REFERENCE_BUNDLE_DIR"
    [ "$REFERENCE_COMMAND_STATUS" -eq 4 ]
    [ "$(install_result_field counted)" == 'false' ]
    [ "$(install_result_field failed_stage)" == 'disk-boot-login' ]
    [ "$(install_result_field boot.first_boot.ok)" == 'false' ]
  done
}

@test "a run canary found in the guest evidence keeps the run private and yields 2" {
  use_matching_bundle
  export REFERENCE_INSTALL_CASE=failure REFERENCE_INSTALL_BAD=canary-leak

  reference_invoke_install --case failure "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 2 ]
  [ "$(install_result_field scans.canary)" == 'findings' ]
  [ "$(install_result_field counted)" == 'false' ]
  [ -z "$(find "$(install_evidence_dir)" -perm /077)" ]
}

@test "QEMU exiting before a report fails with 5 and the disk is still compared" {
  use_matching_bundle
  export REFERENCE_INSTALL_CASE=failure REFERENCE_QEMU_MODE=exit

  reference_invoke_install --case failure "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 5 ]
  [ "$(install_result_field failed_stage)" == 'qemu-exit' ]
  grep -Fq 'qemu-img compare' "$REFERENCE_CALL_LOG"
}

@test "the development overlay forces counted false" {
  use_matching_bundle
  export REFERENCE_INSTALL_CASE=failure

  reference_invoke_install --case failure --development-overlay "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
  [ "$(install_result_field development_overlay)" == 'true' ]
  [ "$(install_result_field counted)" == 'false' ]
}

@test "a dirty bundle is never counted" {
  export REFERENCE_INSTALL_CASE=failure

  reference_set_bundle_build "$REFERENCE_BUNDLE_DIR" "$REFERENCE_HEAD" true
  reference_invoke_install --case failure "$REFERENCE_BUNDLE_DIR"
  [ "$REFERENCE_COMMAND_STATUS" -eq 0 ]
  [ "$(install_result_field counted)" == 'false' ]
}

@test "the guest trigger and the library never put the canary in a command line" {
  local trigger="${REFERENCE_TEST_SOURCE_ROOT}/vm/reference/guest/install-trigger.sh"
  local library="${REFERENCE_TEST_SOURCE_ROOT}/vm/reference/lib/install.sh"

  # The canary reaches the drivers only through environment variables of the two Node processes.
  grep -q 'MIRROROS_INSTALL_CANARY="\$MIRROROS_INSTALL_CANARY" node' "$trigger"
  grep -q 'MIRROROS_LOGIN_CANARY="\$INSTALL_CANARY" node' "$library"
  ! grep -n 'set -x' "$trigger" "$library"
}

@test "qualify-install never elevates privileges on the host" {
  # The only sudo in the library is the text typed into the guest at tty1 to write the login marker.
  run bash -c "grep -nE '(^|[;&|(])[[:space:]]*(sudo|pkexec|doas)[[:space:]]' \
    '${REFERENCE_TEST_SOURCE_ROOT}/vm/reference/qualify-install' '${REFERENCE_TEST_SOURCE_ROOT}/vm/reference/lib/install.sh' \
    | grep -v 'await type('"
  [ "$status" -eq 1 ]
}
