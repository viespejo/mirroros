import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const capability = resolve(root, 'capabilities/visual/theme');
const images = join(capability, 'default/backgrounds');
const sources = readFileSync(join(capability, 'sources.md'), 'utf8');
const pngSignature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function recorded() {
  const rows = new Map();
  for (const match of sources.matchAll(/^\| `([a-z0-9-]+\.png)` \| `([0-9a-f]{64})` \|/gm)) rows.set(match[1], match[2]);
  return rows;
}

function chunks(bytes) {
  const types = [];
  for (let offset = 8; offset < bytes.length; offset += 12 + bytes.readUInt32BE(offset)) {
    types.push(bytes.toString('latin1', offset + 4, offset + 8));
  }
  return types;
}

test('every delivered image is a PNG recorded with its exact digest', () => {
  const files = readdirSync(images).sort();
  assert.deepEqual(files, [...recorded().keys()].sort());
  for (const [name, digest] of recorded()) {
    const bytes = readFileSync(join(images, name));
    assert.ok(bytes.subarray(0, 8).equals(pngSignature), name);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), digest, name);
  }
});

test('generated images keep their provenance manifest', () => {
  for (const name of readdirSync(images).filter((file) => /^\d+-emerald-/.test(file))) {
    assert.ok(chunks(readFileSync(join(images, name))).includes('caBX'), name);
  }
});

test('numeric prefixes order the backgrounds and include the approved logo default', () => {
  const files = readdirSync(images).sort();
  for (const name of files) assert.match(name, /^\d+-[a-z0-9-]+\.png$/);
  assert.ok(files.includes('2-mirroros-jade.png'));
});
