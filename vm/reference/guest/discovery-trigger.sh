#!/usr/bin/bash
# Guest-side discovery trigger, delivered through the temporary NoCloud medium.
# qualify-discovery prepends these variables: MIRROROS_RUN_ID, MIRROROS_HTTPS_URL,
# MIRROROS_HTTPS_TIMEOUT_SECONDS, MIRROROS_DISCOVERY_TARGET, MIRROROS_DISCOVERY_SCENARIO, and, for development runs only,
# MIRROROS_DISCOVERY_OVERLAY_B64 (a base64 tar of the working-tree embedded subtrees).
# Read-only on the target except confirmation/layout-change: only that case writes a GPT with
# sgdisk on the disposable /dev/vda fixture after planning. apply itself never writes to the disk.
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
/usr/local/bin/mirroros-install discover --target "$MIRROROS_DISCOVERY_TARGET" --output "$OUTPUT_DIR" \
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
  printf '%s\n' '{"format_version":1,"hostname":"mirroros-edit","storage_option":"btrfs-rescue"}' > "${PLAN_DIR}/choices-valid.json"
  printf '%s\n' '{"format_version":1,"unknown_key":"value"}' > "${PLAN_DIR}/choices-invalid.json"
  run_plan default ''
  sha256sum -- "${PLAN_DIR}/default/installation-plan.json" 2>/dev/null | cut -d' ' -f1 > "${PLAN_DIR}/sha-before" || true
  run_plan edited "${PLAN_DIR}/choices-valid.json"
  run_plan invalid "${PLAN_DIR}/choices-invalid.json"
  sha256sum -- "${PLAN_DIR}/default/installation-plan.json" 2>/dev/null | cut -d' ' -f1 > "${PLAN_DIR}/sha-after" || true
fi

if [[ "${MIRROROS_DISCOVERY_SCENARIO:-}" == 'confirmation' && "$discover_status" -eq 0 ]]; then
  mkdir -m 700 -- "$PLAN_DIR"
  run_plan default ''
  layout_write_status=-1
  if [[ "${MIRROROS_CONFIRMATION_CASE:-}" == 'layout-change' ]]; then
    layout_write_status=0
    sgdisk --clear --new=1:2048:+1G --typecode=1:8300 /dev/vda \
      > "${WORK_DIR}/layout.stdout" 2> "${WORK_DIR}/layout.stderr" || layout_write_status=$?
    udevadm settle
  fi
  printf '%s' "$layout_write_status" > "${WORK_DIR}/layout.status"
  # The child has a real pty; keystrokes wait for each widget, never bypassing the TTY gate.
  node --input-type=module - "$WORK_DIR" "${MIRROROS_CONFIRMATION_CASE:?}" <<'NODE'
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
const [dir, name] = process.argv.slice(2);
const command = `stty rows 25 cols 80; /usr/local/bin/mirroros-install apply --plan ${dir}/plan/default/installation-plan.json --output ${dir}/apply`;
const child = spawn('script', ['-qefc', command, '/dev/null'], {
  env: { ...process.env, TERM: 'linux', NO_COLOR: '1' }, stdio: ['pipe', 'pipe', 'pipe'],
});
let output = '';
let step = 0;
let pending = false;
let timedOut = false;
let transcript = '';
const prompts = ['Continue to confirmation', 'Yes, apply', 'Type the device name'];
const keys = [name === 'cancel' ? '\r' : '\u001b[B\u001b[B\r', '\u001b[B\r', `${name === 'mismatch' ? 'wrong-device' : 'vda'}\r`];
child.stdout.on('data', chunk => {
  const text = chunk.toString();
  transcript = (transcript + text).slice(-20000);
  if (text.includes('\u001b[6n')) child.stdin.write('\u001b[1;1R');
  if (text.includes('\u001b]11;?')) child.stdin.write('\u001b]11;rgb:0000/0000/0000\u0007');
  output += text;
  const plain = output.replace(/\u001b\[[0-?]*[ -/]*[@-~]/g, '');
  if (!pending && step < prompts.length && plain.includes(prompts[step])) {
    pending = true;
    setTimeout(() => {
      child.stdin.write(keys[step++]);
      output = '';
      pending = false;
    }, 500);
  }
});
child.stderr.resume();
const deadline = setTimeout(() => { timedOut = true; child.kill('SIGTERM'); }, 90000);
child.on('error', () => writeFileSync(`${dir}/apply.status`, '5', { mode: 0o600 }));
child.on('close', status => {
  clearTimeout(deadline);
  writeFileSync(`${dir}/apply.status`, String(timedOut ? 5 : (status ?? 5)), { mode: 0o600 });
  writeFileSync(`${dir}/driver.txt`, transcript.replace(/\u001b\[[0-?]*[ -/]*[@-~]/g, '').replace(/\u001b\][^\u0007]*(?:\u0007|\u001b\\)/g, '').slice(-4000), { mode: 0o600 });
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
    const confirmation = existsSync(`${workDir}/apply.status`) ? {
      name: confirmationCase,
      exit_status: Number(text(`${workDir}/apply.status`)),
      layout_write_status: Number(text(`${workDir}/layout.status`)),
      driver_tail: tail(`${workDir}/driver.txt`),
    } : null;
    if (confirmation !== null) {
      collect(`${workDir}/apply`);
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
