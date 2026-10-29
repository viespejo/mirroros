import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, existsSync, mkdirSync, mkdtempSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const helper = resolve(root, 'capabilities/visual/theme/prepare-parent');

test('theme parent creation is idempotent and rejects untrusted directories', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-parent-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const target = join(dir, 'root');
  mkdirSync(target);
  const run = () => spawnSync('bash', [helper, target, String(process.getuid()), String(process.getgid())], { encoding: 'utf8' });
  assert.equal(run().status, 0);
  assert.ok(existsSync(join(target, 'usr/share/mirroros/themes')));
  assert.equal(run().status, 0);
  chmodSync(join(target, 'usr/share'), 0o777);
  assert.equal(run().status, 4);
  chmodSync(join(target, 'usr/share'), 0o755);
  rmSync(join(target, 'usr/share/mirroros/themes'), { recursive: true });
  const other = join(dir, 'other');
  mkdirSync(other);
  symlinkSync(other, join(target, 'usr/share/mirroros/themes'));
  assert.equal(run().status, 4);
  assert.ok(existsSync(other));
});
