import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

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

export function rawStorage(name = 'reference-vm-layout') {
  return JSON.parse(readFileSync(join(sourceRoot, 'tests/fixtures/discovery/raw', `${name}.json`), 'utf8')).storage;
}
