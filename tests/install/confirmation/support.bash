# shellcheck disable=SC2034 # State variables are read by the Bats files that load this helper.
CONFIRM_SUPPORT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIRM_SOURCE_ROOT="$(cd -- "${CONFIRM_SUPPORT_DIR}/../../.." && pwd -P)"
CONFIRM_DISCOVERY_SUPPORT="${CONFIRM_SOURCE_ROOT}/tests/install/discovery"
CONFIRM_FIXTURES="${CONFIRM_SOURCE_ROOT}/tests/fixtures/discovery/raw"
CONFIRM_CANARY='PLANTED-CONFIRM-SECRET-0001'
# The password the scripted Gum double answers with; it is the canary, so every scan for it covers the password.
CONFIRM_PASSWORD="$CONFIRM_CANARY"
CONFIRM_ENGINE_SUPPORT="${CONFIRM_SOURCE_ROOT}/tests/install/engine"
# The engine helpers provide the embedded Limine packages that the default btrfs-limine plan installs.
# shellcheck source=tests/install/engine/support.bash
source "${CONFIRM_ENGINE_SUPPORT}/support.bash"
# The external tools of the installation engine, answered by the engine double (it also answers systemctl for the
# keyring wait and for a chosen restart or power off, which it only records).
CONFIRM_ENGINE_TOOLS=(wipefs sfdisk blockdev partprobe udevadm mkfs.fat mkfs.ext4 mkfs.btrfs btrfs blkid mount umount mountpoint
  swapoff genfstab mkswap filefrag systemctl pacstrap arch-chroot findmnt pacman lsinitcpio lsattr)

# Keys sent through the pty, one at a time, and extra environment words for the command under test. When
# CONFIRM_WAIT_FOR names a file, the keys are sent only after a double or hook has created it.
CONFIRM_KEYS=()
CONFIRM_ENV=()
CONFIRM_WAIT_FOR=''
CONFIRM_STEP=0.6
CONFIRM_STATUS=''

confirm_setup() {
  local tool_name

  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mirroros confirm.XXXXXX")"
  CODE_ROOT="${TEST_ROOT}/embedded code"
  FIXTURE_ROOT="${TEST_ROOT}/fixture root"
  DOUBLE_STATE="${TEST_ROOT}/double state"
  DOUBLE_BIN="${TEST_ROOT}/double bin"
  WORK_DIR="${TEST_ROOT}/work directory"
  RUN_ROOT="${TEST_ROOT}/run root"
  RUN_DIR="${TEST_ROOT}/run directory"
  TYPESCRIPT="${TEST_ROOT}/typescript.log"
  STDOUT_PATH="${TEST_ROOT}/stdout.log"
  STDERR_PATH="${TEST_ROOT}/stderr.log"
  mkdir -p "${CODE_ROOT}/operations/lib" "$FIXTURE_ROOT" "${DOUBLE_STATE}/out" "$DOUBLE_BIN" "$WORK_DIR" "$RUN_ROOT"

  cp -p "${CONFIRM_SOURCE_ROOT}/operations/install" "${CODE_ROOT}/operations/install"
  cp -p "${CONFIRM_SOURCE_ROOT}/operations/lib/lifecycle-discovery.sh" "${CODE_ROOT}/operations/lib/lifecycle-discovery.sh"
  cp -a "${CONFIRM_SOURCE_ROOT}/install" "${CODE_ROOT}/install"
  mkdir -p "${CODE_ROOT}/hardware"
  cp -a "${CONFIRM_SOURCE_ROOT}/hardware/discovery" "${CODE_ROOT}/hardware/discovery"
  cp -a "${CONFIRM_SOURCE_ROOT}/hardware/rules" "${CODE_ROOT}/hardware/rules"
  cp -a "${CONFIRM_SOURCE_ROOT}/targets" "${CODE_ROOT}/targets"
  printf '{\n  "commit": "%s",\n  "dirty": false\n}\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' > "${CODE_ROOT}/identity.json"
  engine_make_packages

  for tool_name in lsblk ip getent curl uname systemd-detect-virt bootctl; do
    ln -s "${CONFIRM_DISCOVERY_SUPPORT}/doubles/${tool_name}" "${DOUBLE_BIN}/${tool_name}"
  done
  for tool_name in sudo pkexec doas su; do
    ln -s "${CONFIRM_DISCOVERY_SUPPORT}/doubles/elevation" "${DOUBLE_BIN}/${tool_name}"
  done
  for tool_name in "${CONFIRM_ENGINE_TOOLS[@]}"; do
    ln -s "${CONFIRM_ENGINE_SUPPORT}/doubles/engine-double" "${DOUBLE_BIN}/${tool_name}"
  done
  for tool_name in gum timedatectl sleep loadkeys; do
    ln -s "${CONFIRM_SUPPORT_DIR}/doubles/${tool_name}" "${DOUBLE_BIN}/${tool_name}"
  done
  : > "${DOUBLE_STATE}/gum-calls.log"
  : > "${DOUBLE_STATE}/elevation.log"
  : > "${DOUBLE_STATE}/calls.log"
  CONFIRM_KEYS=()
  CONFIRM_ENV=()
  CONFIRM_WAIT_FOR=''
}

confirm_teardown() {
  pkill -KILL -f "${TEST_ROOT:-/nonexistent}" 2> /dev/null || true
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" ]]; then
    rm -rf -- "$TEST_ROOT"
  fi
}

# The live mirrorlist that the engine double copies into the target.
confirm_seed_mirrorlist() {
  mkdir -p "${FIXTURE_ROOT}/etc/pacman.d"
  # shellcheck disable=SC2016 # Pacman expands these literal mirrorlist placeholders, not Bash.
  printf 'Server = https://mirror.example.invalid/$repo/os/$arch\n' > "${FIXTURE_ROOT}/etc/pacman.d/mirrorlist"
}

# Builds the fake system root and the double state from a raw discovery fixture, replacing any earlier one.
confirm_scenario() {
  find "$FIXTURE_ROOT" -mindepth 1 -delete
  node "${CONFIRM_DISCOVERY_SUPPORT}/build-root.mjs" "${CONFIRM_FIXTURES}/${1}.json" "$FIXTURE_ROOT" "$DOUBLE_STATE"
  confirm_seed_mirrorlist
}

# Like confirm_scenario with reference-vm-empty plus a second eligible disk (vdb).
confirm_scenario_two_disks() {
  local raw="${TEST_ROOT}/two-disks.json"

  node -e '
    const fs = require("node:fs");
    const raw = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const second = JSON.parse(JSON.stringify(raw.storage.blockdevices.find(device => device.path === "/dev/vda")));
    Object.assign(second, { path: "/dev/vdb", kname: "vdb", serial: "SYNTH-VDB-0001" });
    raw.storage.blockdevices.push(second);
    fs.writeFileSync(process.argv[2], JSON.stringify(raw));
  ' "${CONFIRM_FIXTURES}/reference-vm-empty.json" "$raw"
  find "$FIXTURE_ROOT" -mindepth 1 -delete
  node "${CONFIRM_DISCOVERY_SUPPORT}/build-root.mjs" "$raw" "$FIXTURE_ROOT" "$DOUBLE_STATE"
  confirm_seed_mirrorlist
}

# Like confirm_scenario with reference-vm-empty, but with the given detected memory in KiB (absent when empty).
confirm_scenario_memory() {
  local raw="${TEST_ROOT}/memory.json"

  node -e '
    const fs = require("node:fs");
    const raw = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    if (process.argv[3] === "") delete raw.hardware.memory_total_kib;
    else raw.hardware.memory_total_kib = Number(process.argv[3]);
    fs.writeFileSync(process.argv[2], JSON.stringify(raw));
  ' "${CONFIRM_FIXTURES}/reference-vm-empty.json" "$raw" "$1"
  find "$FIXTURE_ROOT" -mindepth 1 -delete
  node "${CONFIRM_DISCOVERY_SUPPORT}/build-root.mjs" "$raw" "$FIXTURE_ROOT" "$DOUBLE_STATE"
  confirm_seed_mirrorlist
}

# Like confirm_scenario with reference-vm-empty, but with the given graphics PCI vendor id and CPU vendor id.
confirm_scenario_hardware() {
  local raw="${TEST_ROOT}/hardware.json"

  node -e '
    const fs = require("node:fs");
    const raw = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    raw.hardware.display_devices[0].vendor_id = process.argv[3];
    raw.hardware.cpu.vendor_id = process.argv[4];
    fs.writeFileSync(process.argv[2], JSON.stringify(raw));
  ' "${CONFIRM_FIXTURES}/reference-vm-empty.json" "$raw" "$1" "$2"
  find "$FIXTURE_ROOT" -mindepth 1 -delete
  node "${CONFIRM_DISCOVERY_SUPPORT}/build-root.mjs" "$raw" "$FIXTURE_ROOT" "$DOUBLE_STATE"
  confirm_seed_mirrorlist
}

# Like confirm_scenario with reference-vm-empty, but with a DMI vendor that no defined profile declares: a valid
# machine that matches no profile.
confirm_scenario_unqualified() {
  local raw="${TEST_ROOT}/unqualified.json"

  node -e '
    const fs = require("node:fs");
    const raw = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    raw.firmware.dmi.sys_vendor = "Synthetic Vendor";
    fs.writeFileSync(process.argv[2], JSON.stringify(raw));
  ' "${CONFIRM_FIXTURES}/reference-vm-empty.json" "$raw"
  find "$FIXTURE_ROOT" -mindepth 1 -delete
  node "${CONFIRM_DISCOVERY_SUPPORT}/build-root.mjs" "$raw" "$FIXTURE_ROOT" "$DOUBLE_STATE"
  confirm_seed_mirrorlist
}

# Appends scripted answers to the queue of one gum subcommand.
confirm_queue() {
  local subcommand="$1"

  shift
  printf '%s\n' "$@" >> "${DOUBLE_STATE}/${subcommand}.queue"
}

confirm_hook() {
  printf '%s\n' "$2" > "${DOUBLE_STATE}/${1}.hook"
}

# Runs a command before the answer to the n-th call (1-based) of one gum subcommand.
confirm_hook_call() {
  printf '%s\n' "$3" > "${DOUBLE_STATE}/${1}.hook.${2}"
}

confirm_environment() {
  printf 'PATH=%q DOUBLE_STATE=%q MIRROROS_DISCOVERY_ROOT=%q MIRROROS_ENGINE_RUN_ROOT=%q TERM=linux' "${DOUBLE_BIN}:${PATH}" "$DOUBLE_STATE" "$FIXTURE_ROOT" "$RUN_ROOT"
}

# Runs `operations/install <arguments>` under a real pseudo-terminal so Gum, the TTY checks, and signals
# behave as on the console. There is deliberately no environment variable that fakes a terminal.
confirm_run_pty() {
  local command=''
  local word
  local key

  for word in "${CONFIRM_ENV[@]}"; do
    command+=" $(printf '%q' "$word")"
  done
  command="cd $(printf '%q' "$WORK_DIR") && exec env -u NO_COLOR $(confirm_environment)${command} $(printf '%q' "${CODE_ROOT}/operations/install")"
  for word in "$@"; do
    command+=" $(printf '%q' "$word")"
  done
  : > "${DOUBLE_STATE}/elevation.log"
  CONFIRM_STATUS=0
  {
    sleep 0.5
    if [[ -n "$CONFIRM_WAIT_FOR" ]]; then
      for _ in $(seq 1 300); do
        [[ ! -e "$CONFIRM_WAIT_FOR" ]] || break
        sleep 0.1
      done
      sleep 0.3
    fi
    for key in "${CONFIRM_KEYS[@]}"; do
      printf '%b' "$key"
      sleep "$CONFIRM_STEP"
    done
  } | SHELL=/bin/bash timeout 40 script -qefc "stty cols 100 rows 30; ${command}" "$TYPESCRIPT" > /dev/null || CONFIRM_STATUS="${PIPESTATUS[1]}"
  tr -d '\r' < "$TYPESCRIPT" > "$STDOUT_PATH"
  [[ ! -s "${DOUBLE_STATE}/elevation.log" ]] || { printf 'elevation invoked: %s\n' "$(< "${DOUBLE_STATE}/elevation.log")" >&2; return 1; }
}

# Runs `operations/install <arguments>` without a terminal, as a script or pipe would.
confirm_run_plain() {
  local arguments=''

  if [[ "$#" -gt 0 ]]; then arguments="$(printf '%q ' "$@")"; fi
  : > "${DOUBLE_STATE}/elevation.log"
  if (
    cd -- "$WORK_DIR" || exit 125
    # shellcheck disable=SC2046 # The environment words are quoted by printf %q.
    eval "env $(confirm_environment) $(printf '%q' "${CODE_ROOT}/operations/install") ${arguments}" < /dev/null
  ) > "$STDOUT_PATH" 2> "$STDERR_PATH"; then
    CONFIRM_STATUS=0
  else
    CONFIRM_STATUS=$?
  fi
  [[ ! -s "${DOUBLE_STATE}/elevation.log" ]] || { printf 'elevation invoked: %s\n' "$(< "${DOUBLE_STATE}/elevation.log")" >&2; return 1; }
}

# Generates a plan with the real discover and plan commands from the current fixture root.
confirm_make_plan() {
  local discovery="${TEST_ROOT}/plan-discovery"
  local directory="${TEST_ROOT}/plan-output"

  rm -rf -- "$discovery" "$directory"
  (
    cd -- "$WORK_DIR" || exit 125
    eval "env $(confirm_environment) $(printf '%q' "${CODE_ROOT}/operations/install") discover --target reference-vm --output $(printf '%q' "$discovery")" > /dev/null 2>&1
    eval "env $(confirm_environment) $(printf '%q' "${CODE_ROOT}/operations/install") plan --facts $(printf '%q' "${discovery}/target-facts.json") --output $(printf '%q' "$directory")" > /dev/null 2>&1
  )
  PLAN_FILE="${directory}/installation-plan.json"
  [[ -f "$PLAN_FILE" ]]
}

# Evaluates a JavaScript expression against a parsed JSON file; "d" is the document.
confirm_json_assert() {
  node -e '
    const d = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    if (!eval(process.argv[2])) { console.error("assertion failed: " + process.argv[2]); process.exit(1); }
  ' "$1" "$2"
}

confirm_assert_run() {
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.exit_status === $1 && d.outcome === '$2'"
  confirm_json_assert "${RUN_DIR}/approval-record.json" "d.outcome === '$2'"
}

confirm_assert_reason() {
  confirm_json_assert "${RUN_DIR}/install-run.json" "d.reasons.some(r => r.code === '$1')"
}

confirm_assert_private() {
  [[ -z "$(find "$RUN_DIR" -type d ! -perm 700 -print -quit)" ]]
  [[ -z "$(find "$RUN_DIR" -type f ! -perm 600 -print -quit)" ]]
}

confirm_assert_log_plain() {
  [[ -s "${RUN_DIR}/install.log" ]]
  ! LC_ALL=C grep -aqP '\x1b' "${RUN_DIR}/install.log"
}

confirm_assert_no_canary() {
  ! grep -rFq -- "$CONFIRM_CANARY" "$RUN_DIR" "$STDOUT_PATH" "$TYPESCRIPT"
}

confirm_assert_gum_called() {
  grep -qF -- "$1" "${DOUBLE_STATE}/gum-calls.log"
}

confirm_assert_gum_not_called() {
  ! grep -qE -- "$1" "${DOUBLE_STATE}/gum-calls.log"
}

confirm_assert_output_contains() {
  grep -aqF -- "$1" "$STDOUT_PATH"
}

# The fixture system root must be byte-identical before and after a run that may not touch the target.
confirm_root_manifest() {
  (
    cd -- "$FIXTURE_ROOT" || exit 1
    find . -printf '%p %y %m %s\n'
    find . -type f -exec sha256sum {} +
  ) | LC_ALL=C sort
}
