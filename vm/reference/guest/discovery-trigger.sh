#!/usr/bin/bash
# Guest-side discovery trigger, delivered through the temporary NoCloud medium.
# qualify-discovery prepends these variables: MIRROROS_RUN_ID, MIRROROS_HTTPS_URL,
# MIRROROS_HTTPS_TIMEOUT_SECONDS, MIRROROS_DISCOVERY_TARGET, MIRROROS_DISCOVERY_SCENARIO, MIRROROS_DISCOVERY_AUTOMATIC
# (1 for the confirmation scenarios: discovery runs without --target), MIRROROS_EXPECTED_PROFILE, and, for development
# runs only, MIRROROS_DISCOVERY_OVERLAY_B64 (a base64 tar of the working-tree embedded subtrees).
# Read-only on the target except confirmation/layout-change: only that case writes a GPT with
# sgdisk on the disposable /dev/vda fixture after confirmation and before final revalidation. The installer
# itself never writes to the disk.
# Evidence is written to tmpfs. The only output is one JSON report on the serial console, wrapped
# in run-bound marker lines. MIRROROS_CONFIRMATION_CASE selects one isolated confirmation case.
set -u
umask 077

: "${MIRROROS_RUN_ID:?}" "${MIRROROS_DISCOVERY_TARGET:?}"

NETWORK_WAIT_SECONDS=60
SERIAL_DEVICE=/dev/ttyS0
CODE_ROOT=/usr/local/lib/mirroros
WORK_DIR=/run/mirroros-discovery
OUTPUT_DIR="${WORK_DIR}/out"
PLAN_DIR="${WORK_DIR}/plan"

wait_for() {
  local deadline=$((SECONDS + NETWORK_WAIT_SECONDS))

  while ! "$@" >/dev/null 2>&1; do
    [[ "$SECONDS" -lt "$deadline" ]] || return 1
    sleep 2
  done
}

has_default_route() {
  [[ -n "$(ip -4 route show default 2>/dev/null)" ]]
}

resolves_archlinux() {
  [[ -n "$(getent ahostsv4 archlinux.org 2>/dev/null)" ]]
}

# Discovery reports an unready network as invalid facts, so give the live medium time to configure it.
wait_for has_default_route
wait_for resolves_archlinux

mkdir -m 700 -- "$WORK_DIR"

if [[ -n "${MIRROROS_DISCOVERY_OVERLAY_B64:-}" ]]; then
  base64 -d <<< "$MIRROROS_DISCOVERY_OVERLAY_B64" | tar -x -C "$CODE_ROOT" 2>"${WORK_DIR}/overlay.stderr" || true
fi

discover_status=0
discover_arguments=(discover --output "$OUTPUT_DIR")
[[ "${MIRROROS_DISCOVERY_AUTOMATIC:-0}" == 1 ]] || discover_arguments+=(--target "$MIRROROS_DISCOVERY_TARGET")
/usr/local/bin/mirroros-install "${discover_arguments[@]}" \
  > "${WORK_DIR}/discover.stdout" 2> "${WORK_DIR}/discover.stderr" || discover_status=$?

# Plan scenario: after a successful discovery, plan with defaults, with a valid choices file, and with an
# invalid choices file. The first plan is checksummed right after it is written and again after the last run.
run_plan() {
  local name="$1"
  local choices="$2"
  local plan_status=0
  local -a plan_arguments=(plan --facts "${OUTPUT_DIR}/target-facts.json" --output "${PLAN_DIR}/${name}")

  [[ -z "$choices" ]] || plan_arguments+=(--choices "$choices")
  mkdir -m 700 -- "${PLAN_DIR}/${name}"
  /usr/local/bin/mirroros-install "${plan_arguments[@]}" \
    > "${PLAN_DIR}/${name}.stdout" 2> "${PLAN_DIR}/${name}.stderr" || plan_status=$?
  printf '%s' "$plan_status" > "${PLAN_DIR}/${name}.status"
}

if [[ "${MIRROROS_DISCOVERY_SCENARIO:-}" == 'plan' && "$discover_status" -eq 0 ]]; then
  mkdir -m 700 -- "$PLAN_DIR"
  printf '%s\n' '{"format_version":3,"hostname":"mirroros-edit","storage_option":"btrfs-rescue"}' > "${PLAN_DIR}/choices-valid.json"
  printf '%s\n' '{"format_version":3,"unknown_key":"value"}' > "${PLAN_DIR}/choices-invalid.json"
  run_plan default ''
  sha256sum -- "${PLAN_DIR}/default/installation-plan.json" 2>/dev/null | cut -d' ' -f1 > "${PLAN_DIR}/sha-before" || true
  run_plan edited "${PLAN_DIR}/choices-valid.json"
  run_plan invalid "${PLAN_DIR}/choices-invalid.json"
  sha256sum -- "${PLAN_DIR}/default/installation-plan.json" 2>/dev/null | cut -d' ' -f1 > "${PLAN_DIR}/sha-after" || true
fi

if [[ "${MIRROROS_DISCOVERY_SCENARIO:-}" == confirmation* && "$discover_status" -eq 0 ]]; then
  printf '%s' '-1' > "${WORK_DIR}/layout.status"
  # The full guided route runs in a real pty with TERM=linux and real Gum. Each answer is sent only after its
  # widget has been drawn and the output has gone quiet; the TTY gate is never bypassed. Only layout-change
  # writes to the disposable disk, after the confirmation and before the final revalidation.
  node --input-type=module - "$WORK_DIR" "${MIRROROS_CONFIRMATION_CASE:?}" "${MIRROROS_EXPECTED_PROFILE:?}" <<'NODE'
import { spawn, spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
const [dir, name, profile] = process.argv.slice(2);
const command = `stty rows 50 cols 100; /usr/local/bin/mirroros-install --output ${dir}/install`;
const { NO_COLOR: ignored, ...baseEnvironment } = process.env;
const child = spawn('script', ['-qefc', command, '/dev/null'], {
  env: { ...baseEnvironment, TERM: 'linux' }, stdio: ['pipe', 'pipe', 'pipe'],
});
const machineMarker = profile === 'matched' ? 'Recognized machine' : 'Experimental: this machine matches';
const strip = text => text.replace(/\u001b\[[0-?]*[ -/]*[@-~]/g, '').replace(/\u001b\][^\u0007]*(?:\u0007|\u001b\\)/g, '');
let output = '';
let transcript = '';
let step = 0;
let timedOut = false;
let quiet = null;
const layoutWrite = () => {
  const result = spawnSync('sgdisk', ['--clear', '--new=1:2048:+1G', '--typecode=1:8300', '/dev/vda'], { encoding: 'utf8' });
  spawnSync('udevadm', ['settle']);
  writeFileSync(`${dir}/layout.status`, String(result.status ?? 5), { mode: 0o600 });
};
// Each step lists strings that must all be on screen, then the keys to send. The gum headers and prompts are
// unique to their widgets; screen titles use different capitalization or wording.
const steps = [
  { expect: ['Change installation keyboard layout'], keys: () => '\r' },
  { expect: [machineMarker, 'Cancel'], keys: () => '\r' },
  { expect: ['Select install disk'], keys: () => '\r' },
  { expect: ['Select storage layout'], keys: () => '\r' },
  { expect: ['Hibernation', 'Enabled', 'Disabled'], keys: () => '\r' },
  { expect: ['Swapfile size (MiB)>'], keys: () => '\r' },
  { expect: ['Timezone'], keys: () => '\r' },
  { expect: ['System language'], keys: () => '\r' },
  { expect: ['Regional formats'], keys: () => '\r' },
  { expect: ['Select keyboard layout'], keys: () => '\r' },
  { expect: ['Hostname>'], keys: () => '\r' },
  { expect: ['Username>'], keys: () => '\r' },
  { expect: ['Root account'], keys: () => '\r' },
  { expect: ['Review navigation'], keys: () => '\r' },
  // No is focused: Enter declines (cancel); y accepts.
  { expect: ['Yes, erase'], keys: () => (name === 'cancel' ? '\r' : 'y') },
  { expect: ['Device name>'], keys: plain => {
    const typed = /Type the device name \(([^)\s]+)\)/.exec(plain)?.[1] ?? 'vda';
    return `${name === 'mismatch' ? 'wrong-device' : typed}\r`;
  } },
  { expect: ['No password is collected in this version'], keys: () => {
    if (name === 'layout-change') layoutWrite();
    return '\r';
  } },
];
const advance = () => {
  quiet = null;
  const plain = strip(output);
  if (step >= steps.length || !steps[step].expect.every(text => plain.includes(text))) return;
  const keys = steps[step].keys(plain);
  step += 1;
  output = '';
  child.stdin.write(keys);
};
child.stdout.on('data', chunk => {
  const text = chunk.toString();
  transcript = (transcript + text).slice(-20000);
  if (text.includes('\u001b[6n')) child.stdin.write('\u001b[1;1R');
  if (text.includes('\u001b]11;?')) child.stdin.write('\u001b]11;rgb:0000/0000/0000\u0007');
  output += text;
  if (quiet !== null) clearTimeout(quiet);
  quiet = setTimeout(advance, 250);
});
child.stderr.resume();
const deadline = setTimeout(() => { timedOut = true; child.kill('SIGTERM'); }, 200000);
child.on('error', () => writeFileSync(`${dir}/install.status`, '5', { mode: 0o600 }));
child.on('close', status => {
  clearTimeout(deadline);
  if (quiet !== null) clearTimeout(quiet);
  writeFileSync(`${dir}/install.status`, String(timedOut ? 5 : (status ?? 5)), { mode: 0o600 });
  writeFileSync(`${dir}/driver.txt`, strip(transcript).slice(-4000), { mode: 0o600 });
});
NODE
fi

emit_report() {
  local body

  # shellcheck disable=SC2016 # The Node program is a literal; its arguments are passed explicitly.
  if ! body="$(node -e '
    const { readFileSync, existsSync, readdirSync, statSync } = require("node:fs");
    const [dir, runId, target, status, stderrPath, planDir, workDir, confirmationCase] = process.argv.slice(1);
    const read = name => {
      const path = `${dir}/${name}`;
      return existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : null;
    };
    const text = path => (existsSync(path) ? readFileSync(path, "utf8") : null);
    const tail = path => (text(path) ?? "").slice(-2000);
    const plan = existsSync(`${planDir}/sha-after`) ? {
      runs: ["default", "edited", "invalid"].map(name => ({
        name,
        exit_status: Number(text(`${planDir}/${name}.status`)),
        plan: text(`${planDir}/${name}/installation-plan.json`),
        plan_text: text(`${planDir}/${name}/installation-plan.txt`),
        plan_run: text(`${planDir}/${name}/plan-run.json`),
        stdout_tail: tail(`${planDir}/${name}.stdout`),
        stderr_tail: tail(`${planDir}/${name}.stderr`),
      })),
      sha256_before: (text(`${planDir}/sha-before`) ?? "").trim(),
      sha256_after: (text(`${planDir}/sha-after`) ?? "").trim(),
    } : null;
    const files = {};
    let privatePermissions = true;
    const collect = (directory, prefix = "") => {
      if (!existsSync(directory)) return;
      if ((statSync(directory).mode & 0o777) !== 0o700) privatePermissions = false;
      for (const entry of readdirSync(directory, { withFileTypes: true })) {
        const path = `${directory}/${entry.name}`;
        const name = `${prefix}${entry.name}`;
        if (entry.isDirectory()) collect(path, `${name}/`);
        else if (entry.isFile()) {
          if ((statSync(path).mode & 0o777) !== 0o600) privatePermissions = false;
          files[name] = readFileSync(path, "utf8");
        } else privatePermissions = false;
      }
    };
    const confirmation = existsSync(`${workDir}/install.status`) ? {
      name: confirmationCase,
      exit_status: Number(text(`${workDir}/install.status`)),
      layout_write_status: Number(text(`${workDir}/layout.status`)),
      driver_tail: tail(`${workDir}/driver.txt`),
    } : null;
    if (confirmation !== null) {
      collect(`${workDir}/install`);
      confirmation.files = files;
      confirmation.private_permissions = privatePermissions;
    }
    const stderr = existsSync(stderrPath) ? readFileSync(stderrPath, "utf8").slice(-2000) : "";
    process.stdout.write(JSON.stringify({
      schema_version: 1,
      run_id: runId,
      target,
      exit_status: Number(status),
      facts: read("target-facts.json"),
      error: read("error.json"),
      stderr_tail: stderr,
      ...(plan === null ? {} : { plan }),
      ...(confirmation === null ? {} : { confirmation }),
    }));
  ' "$OUTPUT_DIR" "$MIRROROS_RUN_ID" "$MIRROROS_DISCOVERY_TARGET" "$discover_status" "${WORK_DIR}/discover.stderr" "$PLAN_DIR" "$WORK_DIR" "${MIRROROS_CONFIRMATION_CASE:-}" 2>/dev/null)"; then
    body="{\"schema_version\":1,\"run_id\":\"${MIRROROS_RUN_ID}\",\"target\":\"${MIRROROS_DISCOVERY_TARGET}\",\"exit_status\":${discover_status},\"facts\":null,\"error\":null,\"stderr_tail\":\"report assembly failed\"}"
  fi

  {
    printf '\nMIRROROS-REPORT-BEGIN %s\n' "$MIRROROS_RUN_ID"
    printf '%s\n' "$body"
    printf 'MIRROROS-REPORT-END %s\n' "$MIRROROS_RUN_ID"
  } > "$SERIAL_DEVICE"
}

emit_report
