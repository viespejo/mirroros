import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { loadPlanOverride, loadProfileDefinition } from '../../../install/plan/resolve-choices.mjs';
import { discover } from '../discovery/helpers.mjs';
import { generate, targetsRoot } from '../plan/helpers.mjs';

const here = dirname(fileURLToPath(import.meta.url));
export const sourceRoot = resolve(here, '../../..');
export const loadPlanPath = join(sourceRoot, 'install/engine/load-plan.mjs');
export const engineRecordPath = join(sourceRoot, 'install/engine/engine-record.mjs');
export const IDENTITY_COMMIT = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

export function planText(kind, name) {
  return readFileSync(join(sourceRoot, 'tests/fixtures/plan', kind, `${name}.json`), 'utf8');
}

export function parseStream(output) {
  const fields = output.split('\0');
  fields.pop();
  return fields;
}

export function runNode(script, args, input) {
  const result = spawnSync('node', [script, ...args], { input, encoding: 'utf8' });
  return { status: result.status, stdout: result.stdout, stderr: result.stderr };
}

export function verify(text, { digest, commit = IDENTITY_COMMIT, dirty = 'false' } = {}) {
  const wanted = digest ?? JSON.parse(text).digest?.value ?? 'missing';
  const result = runNode(loadPlanPath, ['verify', '--digest', wanted, '--commit', commit, '--dirty', dirty], text);
  return { ...result, fields: parseStream(result.stdout) };
}

// The operations of a successful stream: id, description, and a parameter map each.
export function streamOperations(fields) {
  const operations = [];
  let index = 8;
  while (index < fields.length) {
    const [marker, id, description, count] = fields.slice(index, index + 4);
    if (marker !== 'op') throw new Error(`unexpected field ${marker}`);
    index += 4;
    const parameters = {};
    for (let item = 0; item < Number(count); item += 1) {
      parameters[fields[index]] = fields[index + 1];
      index += 2;
    }
    operations.push({ id, description, parameters });
  }
  return operations;
}

// A matched T14s with the reference disk layout used by the engine's native-command doubles.
export function hibernateModePlan(hibernation = true) {
  const targetId = 'thinkpad-t14s-gen1-amd';
  const factsDocument = discover('reference-vm-layout', {
    targetId: null,
    mutateRaw: raw => {
      raw.firmware.dmi = { sys_vendor: 'LENOVO', product_name: '20UJ001RMX' };
      raw.hardware.virtualization = 'none';
    },
  });
  return generate({
    factsDocument,
    choices: { storage_option: 'ext4-systemd-boot', hibernation },
    override: loadPlanOverride(targetsRoot, targetId),
    profileDefinition: loadProfileDefinition(targetsRoot, targetId),
  }).plan;
}

export function rawStorage(name = 'reference-vm-layout') {
  return JSON.parse(readFileSync(join(sourceRoot, 'tests/fixtures/discovery/raw', `${name}.json`), 'utf8')).storage;
}
