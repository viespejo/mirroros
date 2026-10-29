import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const checker = resolve(root, 'capabilities/visual/theme/check-trusted-path');

test('trusted paths require safe components, ownership, and permissions', (t) => {
  const anchor = mkdtempSync(join(tmpdir(), 'mirroros-trust-'));
  t.after(() => rmSync(anchor, { recursive: true, force: true }));
  const dir = join(anchor, 'theme');
  const file = join(dir, 'neovim.lua');
  mkdirSync(dir, { mode: 0o755 });
  writeFileSync(file, '-- reviewed\n', { mode: 0o644 });
  const run = (path = 'theme/neovim.lua', uid = String(process.getuid())) =>
    spawnSync('bash', [checker, anchor, path, uid], { encoding: 'utf8' });

  assert.equal(run().status, 0);
  assert.equal(run('theme/missing.lua').status, 4);
  assert.equal(run('../neovim.lua').status, 6);
  assert.equal(run('theme//neovim.lua').status, 6);
  assert.equal(run('theme/neovim.lua', String(process.getuid() + 1)).status, 4);
  chmodSync(file, 0o664);
  assert.equal(run().status, 4);
  chmodSync(file, 0o644);
  chmodSync(dir, 0o777);
  assert.equal(run().status, 4);
  chmodSync(dir, 0o755);
  symlinkSync('neovim.lua', join(dir, 'link.lua'));
  assert.equal(run('theme/link.lua').status, 4);
  symlinkSync('theme', join(anchor, 'link'));
  assert.equal(run('link/neovim.lua').status, 4);
  assert.equal(run().status, 0);
});
