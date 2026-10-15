#!/usr/bin/bash
# Guest-side installation trigger, delivered through the temporary NoCloud medium.
# qualify-install prepends these variables: MIRROROS_RUN_ID, MIRROROS_HTTPS_URL, MIRROROS_HTTPS_TIMEOUT_SECONDS,
# MIRROROS_INSTALL_CASE, MIRROROS_INSTALL_CHOICES (a JSON choices document without single quotes),
# MIRROROS_INSTALL_CANARY (the account password of this run, a random test canary), MIRROROS_INSTALL_FAILURE
# (1 makes the live mirrorlist unreachable before the run), MIRROROS_INSTALL_DRIVER_SECONDS, and, for development
# runs only, MIRROROS_INSTALL_OVERLAY_B64 (a base64 tar of the working-tree embedded subtrees).
# The case runs the real guided installer in a pty with TERM=linux and real Gum on the disposable /dev/vda disk.
# The canary is typed only into the protected password fields. After a successful installation the target is
# mounted read-only to collect observations, including the gating microcode archive listing. Evidence is written
# to tmpfs. The only output is one JSON report on the serial console, wrapped in run-bound marker lines.
set -u
umask 077

: "${MIRROROS_RUN_ID:?}" "${MIRROROS_INSTALL_CASE:?}" "${MIRROROS_INSTALL_CHOICES:?}" "${MIRROROS_INSTALL_CANARY:?}"

NETWORK_WAIT_SECONDS=60
SERIAL_DEVICE=/dev/ttyS0
CODE_ROOT=/usr/local/lib/mirroros
WORK_DIR=/run/mirroros-install-qualification
FACTS_DIR="${WORK_DIR}/discovery"
PLAN_DIR="${WORK_DIR}/plan"
OBSERVE_DIR="${WORK_DIR}/observation"
OBSERVE_MOUNT=/run/mirroros-observe

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

wait_for has_default_route
wait_for resolves_archlinux

mkdir -m 700 -- "$WORK_DIR" "$OBSERVE_DIR"

if [[ -n "${MIRROROS_INSTALL_OVERLAY_B64:-}" ]]; then
  base64 -d <<< "$MIRROROS_INSTALL_OVERLAY_B64" | tar -x -C "$CODE_ROOT" 2>"${WORK_DIR}/overlay.stderr" || true
fi

# Discovery and plan generation write nothing to the disk. The plan carries the case's choices.
prepare_status=0
/usr/local/bin/mirroros-install discover --output "$FACTS_DIR" \
  > "${WORK_DIR}/discover.stdout" 2> "${WORK_DIR}/prepare.stderr" || prepare_status=$?
if [[ "$prepare_status" -eq 0 ]]; then
  printf '%s\n' "$MIRROROS_INSTALL_CHOICES" > "${WORK_DIR}/choices.json"
  /usr/local/bin/mirroros-install plan --facts "${FACTS_DIR}/target-facts.json" --choices "${WORK_DIR}/choices.json" \
    --output "$PLAN_DIR" > "${WORK_DIR}/plan.stdout" 2>> "${WORK_DIR}/prepare.stderr" || prepare_status=$?
fi

# Approved fixture write: the live mirror list points at an unreachable address so that the package
# installation fails. Nothing else is changed, and the network probe of the assistant does not use it.
if [[ "${MIRROROS_INSTALL_FAILURE:-0}" == 1 ]]; then
  systemctl stop reflector.service >/dev/null 2>&1 || true
  # shellcheck disable=SC2016 # The mirror list keeps the literal pacman variables.
  printf 'Server = http://127.0.0.1:9/$repo/os/$arch\n' > /etc/pacman.d/mirrorlist
fi

printf '%s' '-1' > "${WORK_DIR}/install.status"
if [[ "$prepare_status" -eq 0 ]]; then
  # The guided route runs in a real pty. Each rule fires only when its strings are on screen after the output has
  # gone quiet, so the order of the screens is not assumed. The canary is typed only into the protected fields.
  MIRROROS_INSTALL_CANARY="$MIRROROS_INSTALL_CANARY" node --input-type=module - "$WORK_DIR" "$MIRROROS_INSTALL_CASE" "${MIRROROS_INSTALL_DRIVER_SECONDS:-2400}" <<'NODE'
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
const [dir, name, driverSeconds] = process.argv.slice(2);
const canary = process.env.MIRROROS_INSTALL_CANARY;
const command = `stty rows 50 cols 100; /usr/local/bin/mirroros-install --plan ${dir}/plan/installation-plan.json --output ${dir}/install`;
const { NO_COLOR: ignored, MIRROROS_INSTALL_CANARY: hidden, ...baseEnvironment } = process.env;
const child = spawn('script', ['-qefc', command, '/dev/null'], {
  env: { ...baseEnvironment, TERM: 'linux' }, stdio: ['pipe', 'pipe', 'pipe'],
});
const strip = text => text.replace(/\u001b\[[0-?]*[ -/]*[@-~]/g, '').replace(/\u001b\][^\u0007]*(?:\u0007|\u001b\\)/g, '');
let output = '';
let transcript = '';
let timedOut = false;
let quiet = null;
const down = '\u001b[B';
// Order matters: the first rule whose strings are all on screen fires. Later screens come first.
const rules = [
  { expect: ['Base system installed and verified;', 'View configure log', 'Return to shell'], keys: () => '\r' },
  { expect: ['Installed MirrorOS in', 'Return to shell'], keys: () => `${down}\r` },
  { expect: ['MirrorOS installation stopped', 'Return to shell'], keys: () => '\r' },
  { expect: ['MirrorOS installation could not be verified', 'Return to shell'], keys: () => '\r' },
  { expect: ['Confirm>'], keys: () => `${canary}\r` },
  { expect: ['Password>'], keys: () => (name === 'cancel-password' ? '\u0003' : `${canary}\r`) },
  { expect: ['Device name>'], keys: plain => `${/Type the device name \(([^)\s]+)\)/.exec(plain)?.[1] ?? 'vda'}\r` },
  { expect: ['Yes, erase'], keys: () => 'y' },
  { expect: ['Review navigation'], keys: () => '\r' },
  { expect: ['Change installation keyboard layout'], keys: () => '\r' },
  { expect: ['Recognized machine', 'Cancel'], keys: () => '\r' },
];
const advance = () => {
  quiet = null;
  const plain = strip(output);
  const rule = rules.find(candidate => candidate.expect.every(text => plain.includes(text)));
  if (rule === undefined) return;
  const keys = rule.keys(plain);
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
const deadline = setTimeout(() => { timedOut = true; child.kill('SIGTERM'); }, Number(driverSeconds) * 1000);
child.on('error', () => writeFileSync(`${dir}/install.status`, '5', { mode: 0o600 }));
child.on('close', status => {
  clearTimeout(deadline);
  if (quiet !== null) clearTimeout(quiet);
  writeFileSync(`${dir}/install.status`, String(timedOut ? 5 : (status ?? 5)), { mode: 0o600 });
  writeFileSync(`${dir}/driver.txt`, strip(transcript).slice(-4000), { mode: 0o600 });
});
NODE
fi

# Read-only observations of the installed disk: partition table, filesystems, fstab, boot entries, microcode, and
# Btrfs subvolumes when present. Microcode and selected boot parameters are gating; the rest is informational.
observe_target() {
  local filesystem options=ro

  sfdisk -d /dev/vda > "${OBSERVE_DIR}/partition-table.txt" 2>&1 || true
  lsblk -no NAME,FSTYPE,SIZE,PARTLABEL /dev/vda > "${OBSERVE_DIR}/filesystems.txt" 2>&1 || true
  filesystem="$(lsblk -no FSTYPE /dev/vda2 2>/dev/null | head -n 1)"
  [[ "$filesystem" != btrfs ]] || options=ro,subvol=@
  mkdir -p -- "$OBSERVE_MOUNT"
  if mount -o "$options" /dev/vda2 "$OBSERVE_MOUNT" 2>/dev/null; then
    if mount -o ro /dev/vda1 "${OBSERVE_MOUNT}/boot" 2>/dev/null; then
      cp -- "${OBSERVE_MOUNT}/etc/fstab" "${OBSERVE_DIR}/fstab" 2>/dev/null || true
      find "${OBSERVE_MOUNT}/boot" -maxdepth 3 -type f 2>/dev/null | sed "s#^${OBSERVE_MOUNT}##" | sort \
        > "${OBSERVE_DIR}/boot-files.txt"
      for entry in "${OBSERVE_MOUNT}"/boot/loader/loader.conf "${OBSERVE_MOUNT}"/boot/loader/entries/*.conf \
        "${OBSERVE_MOUNT}"/boot/limine.conf; do
        [[ -f "$entry" ]] || continue
        { printf '## %s\n' "${entry#"$OBSERVE_MOUNT"}"; cat -- "$entry"; } >> "${OBSERVE_DIR}/boot-entries.txt"
      done
      lsinitcpio --early --nocolor -l "${OBSERVE_MOUNT}/boot/initramfs-linux.img" > "${OBSERVE_DIR}/microcode.txt" 2>/dev/null \
        || lsinitcpio --nocolor -l "${OBSERVE_MOUNT}/boot/initramfs-linux.img" > "${OBSERVE_DIR}/microcode.txt" 2>/dev/null || true
      umount "${OBSERVE_MOUNT}/boot" 2>/dev/null || true
    fi
    if [[ "$filesystem" == btrfs ]]; then
      btrfs subvolume list "$OBSERVE_MOUNT" > "${OBSERVE_DIR}/subvolumes.txt" 2>&1 || true
    fi
    ls -A "${OBSERVE_MOUNT}/swap" > "${OBSERVE_DIR}/swap-directory.txt" 2>&1 || true
    ls -A "$OBSERVE_MOUNT" > "${OBSERVE_DIR}/root-entries.txt" 2>&1 || true
    umount "$OBSERVE_MOUNT" 2>/dev/null || true
  fi
}

if [[ "$(cat -- "${WORK_DIR}/install.status")" == 0 ]]; then
  observe_target
fi

emit_report() {
  local body

  # shellcheck disable=SC2016 # The Node program is a literal; its arguments are passed explicitly.
  if ! body="$(node -e '
    const { readFileSync, existsSync, readdirSync, statSync } = require("node:fs");
    const [workDir, runId, installCase, prepareStatus, observeDir] = process.argv.slice(1);
    const text = path => (existsSync(path) ? readFileSync(path, "utf8") : null);
    const tail = path => (text(path) ?? "").slice(-2000);
    const files = {};
    let privatePermissions = true;
    const collect = (directory, target, prefix = "") => {
      if (!existsSync(directory)) return;
      if ((statSync(directory).mode & 0o777) !== 0o700) privatePermissions = false;
      for (const entry of readdirSync(directory, { withFileTypes: true })) {
        const path = `${directory}/${entry.name}`;
        const name = `${prefix}${entry.name}`;
        if (entry.isDirectory()) collect(path, target, `${name}/`);
        else if (entry.isFile()) {
          if ((statSync(path).mode & 0o777) !== 0o600) privatePermissions = false;
          target[name] = readFileSync(path, "utf8").slice(-200000);
        } else privatePermissions = false;
      }
    };
    const observation = {};
    collect(`${workDir}/install`, files);
    const observed = {};
    if (existsSync(observeDir)) {
      for (const entry of readdirSync(observeDir, { withFileTypes: true })) {
        if (entry.isFile()) observed[entry.name] = readFileSync(`${observeDir}/${entry.name}`, "utf8");
      }
    }
    const installStatus = Number(text(`${workDir}/install.status`));
    process.stdout.write(JSON.stringify({
      schema_version: 1,
      run_id: runId,
      target: "reference-vm",
      exit_status: Number(prepareStatus),
      facts: null,
      error: null,
      stderr_tail: tail(`${workDir}/prepare.stderr`),
      install: {
        name: installCase,
        exit_status: installStatus,
        files,
        observation: observed,
        private_permissions: privatePermissions,
        driver_tail: tail(`${workDir}/driver.txt`),
      },
    }));
  ' "$WORK_DIR" "$MIRROROS_RUN_ID" "$MIRROROS_INSTALL_CASE" "$prepare_status" "$OBSERVE_DIR" 2>/dev/null)"; then
    body="{\"schema_version\":1,\"run_id\":\"${MIRROROS_RUN_ID}\",\"target\":\"reference-vm\",\"exit_status\":${prepare_status},\"facts\":null,\"error\":null,\"stderr_tail\":\"report assembly failed\"}"
  fi

  {
    printf '\nMIRROROS-REPORT-BEGIN %s\n' "$MIRROROS_RUN_ID"
    printf '%s\n' "$body"
    printf 'MIRROROS-REPORT-END %s\n' "$MIRROROS_RUN_ID"
  } > "$SERIAL_DEVICE"
}

emit_report
