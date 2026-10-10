import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { normalizeFacts } from '../../../install/discovery/normalize-facts.mjs';
import { loadAllTargets, loadBaselinePolicy, loadOverride, loadTarget } from '../../../install/discovery/resolve-layers.mjs';

export const repository = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
export const fixturesRoot = join(repository, 'tests/fixtures/discovery');
export const targetsRoot = join(repository, 'targets');
export const baseline = loadBaselinePolicy(join(repository, 'install/discovery/policy.json'));

export const PLANTED_VALUES = [
  'PLANTED-SSID-7f3a',
  'PLANTED-IWD-STATE',
  'PLANTED-DMI-SERIAL-0001',
  '00000000-0000-4000-8000-00000000dead',
  'PLANTED-BOARD-SERIAL-0001',
  'PLANTED-CHASSIS-SERIAL-0001',
  'PLANTED-BATTERY-SERIAL-0001',
  'aa:bb:cc:dd:ee:ff',
];

export function readFixture(relativePath) {
  return JSON.parse(readFileSync(join(fixturesRoot, relativePath), 'utf8'));
}

export function source(requestedProfileId) {
  return {
    run_id: '20261007T120000Z-11111111-2222-4333-8444-555555555555',
    commit: 'a'.repeat(40),
    dirty: false,
    requested_profile_id: requestedProfileId,
  };
}

// A string targetId is an explicit --target assertion (reference-vm by default); null runs the automatic
// identification over every profile under root.
export function discover(rawName, { targetId = 'reference-vm', root = targetsRoot, overrideFixture, runtimeNames, mutateRaw } = {}) {
  const requested = targetId === null ? null : loadTarget(root, targetId);
  const raw = readFixture(`raw/${rawName}.json`);
  if (mutateRaw !== undefined) mutateRaw(raw);
  return normalizeFacts({
    raw,
    baseline,
    targets: requested === null ? loadAllTargets(root) : [],
    requested,
    loadOverride: id => (overrideFixture !== undefined
      ? { override: readFixture(`overrides/${overrideFixture}.json`), reasons: [] }
      : loadOverride(root, id)),
    source: source(targetId ?? undefined),
    runtimeNames,
  });
}

export function codes(items) {
  return items.map(item => item.code);
}
