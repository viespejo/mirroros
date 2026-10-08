import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { normalizeFacts } from '../../../install/discovery/normalize-facts.mjs';
import { loadBaselinePolicy, loadOverride, loadTarget } from '../../../install/discovery/resolve-layers.mjs';

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

export function source(targetId) {
  return {
    run_id: '20261007T120000Z-11111111-2222-4333-8444-555555555555',
    commit: 'a'.repeat(40),
    dirty: false,
    target_id: targetId,
  };
}

export function discover(rawName, { targetId = 'reference-vm', root = targetsRoot, overrideFixture, runtimeNames } = {}) {
  const loaded = loadTarget(root, targetId);
  const loadReasons = [...loaded.reasons];
  let override = {};
  if (overrideFixture !== undefined) {
    override = readFixture(`overrides/${overrideFixture}.json`);
  } else if (loaded.target) {
    const loadedOverride = loadOverride(root, targetId);
    override = loadedOverride.override;
    loadReasons.push(...loadedOverride.reasons);
  }
  return normalizeFacts({
    raw: readFixture(`raw/${rawName}.json`),
    baseline,
    target: loaded.target,
    override,
    loadReasons,
    source: source(targetId),
    runtimeNames,
  });
}

export function codes(items) {
  return items.map(item => item.code);
}
