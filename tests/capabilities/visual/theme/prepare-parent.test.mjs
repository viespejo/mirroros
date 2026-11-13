import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, existsSync, mkdirSync, mkdtempSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const helper = resolve(root, 'capabilities/visual/theme/prepare-parent');

test('shared product parent creation does not create a selectable theme or runtime', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-shared-parent-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const target = join(dir, 'root');
  mkdirSync(target);
  const run = () => spawnSync('bash', [helper, target, String(process.getuid()), String(process.getgid()), 'mirroros'], { encoding: 'utf8' });
  assert.equal(run().status, 0);
  assert.ok(existsSync(join(target, 'usr/share/mirroros')));
  assert.equal(existsSync(join(target, 'usr/share/mirroros/gtk4')), false);
  assert.equal(existsSync(join(target, 'usr/share/mirroros/themes')), false);
  assert.equal(run().status, 0);
  chmodSync(join(target, 'usr/share/mirroros'), 0o777);
  assert.equal(run().status, 4);
});

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

test('the native GTK theme lookup parent is prepared outside the product tree and rejects untrusted directories', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-system-themes-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const target = join(dir, 'root');
  mkdirSync(target);
  const run = () => spawnSync('bash', [helper, target, String(process.getuid()), String(process.getgid()), 'system-themes'], { encoding: 'utf8' });
  assert.equal(run().status, 0);
  assert.ok(existsSync(join(target, 'usr/share/themes')));
  assert.equal(existsSync(join(target, 'usr/share/mirroros')), false);
  assert.equal(run().status, 0);
  chmodSync(join(target, 'usr/share/themes'), 0o777);
  assert.equal(run().status, 4);
  rmSync(join(target, 'usr/share/themes'), { recursive: true });
  const other = join(dir, 'other');
  mkdirSync(other);
  symlinkSync(other, join(target, 'usr/share/themes'));
  assert.equal(run().status, 4);
});

test('the native icon theme lookup parent is prepared outside the product tree and rejects untrusted directories', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-system-icons-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const target = join(dir, 'root');
  mkdirSync(target);
  const run = () => spawnSync('bash', [helper, target, String(process.getuid()), String(process.getgid()), 'system-icons'], { encoding: 'utf8' });
  assert.equal(run().status, 0);
  assert.ok(existsSync(join(target, 'usr/share/icons')));
  assert.equal(existsSync(join(target, 'usr/share/mirroros')), false);
  assert.equal(existsSync(join(target, 'usr/share/themes')), false);
  assert.equal(run().status, 0);
  chmodSync(join(target, 'usr/share/icons'), 0o777);
  assert.equal(run().status, 4);
  rmSync(join(target, 'usr/share/icons'), { recursive: true });
  const other = join(dir, 'other');
  mkdirSync(other);
  symlinkSync(other, join(target, 'usr/share/icons'));
  assert.equal(run().status, 4);
});
