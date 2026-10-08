import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { loadPlanOverride, loadPlanPolicy } from '../../../install/plan/resolve-choices.mjs';
import { generatePlan } from '../../../install/plan/generate-plan.mjs';
import { discover, repository, targetsRoot } from '../discovery/helpers.mjs';

export { repository, targetsRoot };
export const CANARY = 'PLANTED-PLAN-SECRET-0001';
export const policyPath = join(repository, 'install/plan/policy.json');
export const policy = loadPlanPolicy(policyPath);

export function facts(name = 'reference-vm-layout') {
  return discover(name);
}

export function referenceOverride() {
  return loadPlanOverride(targetsRoot, 'reference-vm');
}

export function generate({ choices = {}, override = referenceOverride(), factsDocument = facts(), policyOverride = policy } = {}) {
  return generatePlan({ facts: factsDocument, policy: policyOverride, choices: { values: choices }, override });
}

export function secondEligibleDisk(document) {
  const copy = structuredClone(document);
  const [first] = copy.layers.detected.storage.disks;
  const second = structuredClone(first);
  second.identity = { path: '/dev/vdb', by_id: 'virtio-SYNTH-VDB-0002', serial: 'SYNTH-VDB-0002', size_bytes: 68719476736 };
  second.layout = { partitions: [] };
  copy.layers.detected.storage.disks.push(second);
  copy.effective['storage.disks'].value = copy.layers.detected.storage.disks;
  return copy;
}

export function temporaryDirectory() {
  return mkdtempSync(join(tmpdir(), 'mirroros-plan-'));
}

export function removeDirectory(path) {
  rmSync(path, { recursive: true, force: true });
}

export function writeJson(directory, name, value) {
  const path = join(directory, name);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, typeof value === 'string' ? value : `${JSON.stringify(value)}\n`);
  return path;
}

// A reference-data root with just enough zoneinfo, keymaps, and locales for the allowlist checks.
export function referenceRoot() {
  const root = temporaryDirectory();
  for (const zone of ['UTC', 'Europe/Madrid', 'Europe/London', 'America/New_York']) {
    writeJson(root, `usr/share/zoneinfo/${zone}`, 'TZif');
  }
  for (const keymap of ['i386/qwerty/us.map.gz', 'i386/qwerty/es.map.gz', 'i386/dvorak/dvorak.map.gz']) {
    writeJson(root, `usr/share/kbd/keymaps/${keymap}`, 'keymap');
  }
  writeJson(root, 'usr/share/i18n/SUPPORTED', [
    'en_US.UTF-8 UTF-8',
    'en_US ISO-8859-1',
    'es_ES.UTF-8 UTF-8',
    'de_DE.UTF-8 UTF-8',
    '',
  ].join('\n'));
  return root;
}
