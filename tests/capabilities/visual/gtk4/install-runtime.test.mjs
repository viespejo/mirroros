import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const publisher = resolve(root, 'capabilities/visual/gtk4/install-runtime');

test('GTK4 runtime publication is idempotent, updates intact trees, and rejects conflicts', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-theme-test-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const source = join(dir, 'source');
  const dest = join(dir, 'installed', 'default');
  mkdirSync(source);
  writeFileSync(join(source, 'colors.toml'), 'background = "#111c18"\n');
  const run = (action, target = dest) => spawnSync('bash', [publisher, action, source, target,
    String(process.getuid()), String(process.getgid())], { encoding: 'utf8' });

  assert.equal(run('check').status, 1);
  assert.equal(run('publish').status, 0);
  assert.equal(run('check').status, 0);
  assert.equal(run('publish').status, 0);
  writeFileSync(join(source, 'colors.toml'), 'background = "#123456"\n');
  assert.equal(run('check').status, 1);
  assert.equal(run('publish').status, 0);
  assert.equal(readFileSync(join(dest, 'colors.toml'), 'utf8'), 'background = "#123456"\n');
  chmodSync(join(dest, 'colors.toml'), 0o666);
  assert.equal(run('publish').status, 4);
  chmodSync(join(dest, 'colors.toml'), 0o644);
  writeFileSync(join(dest, 'unexpected file'), 'keep\n');
  assert.equal(run('publish').status, 4);
  assert.equal(readFileSync(join(dest, 'unexpected file'), 'utf8'), 'keep\n');
  rmSync(join(dest, 'unexpected file'));

  writeFileSync(join(dest, 'colors.toml'), 'local edit\n');
  assert.equal(run('check').status, 4);
  assert.equal(run('publish').status, 4);
  assert.equal(readFileSync(join(dest, 'colors.toml'), 'utf8'), 'local edit\n');

  const unknown = join(dir, 'unknown');
  mkdirSync(unknown);
  assert.equal(run('publish', unknown).status, 4);
  const link = join(dir, 'link');
  symlinkSync(unknown, link);
  assert.equal(run('publish', link).status, 4);
});

test('a destination appearing during initial publication is preserved', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-theme-race-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const source = join(dir, 'source');
  const bin = join(dir, 'bin');
  const dest = join(dir, 'dest');
  mkdirSync(source);
  mkdirSync(bin);
  writeFileSync(join(source, 'colors.toml'), 'background = "#111c18"\n');
  writeFileSync(join(bin, 'mv'), '#!/bin/bash\nif [[ "$1" == -T && "$2" == --no-clobber ]]; then mkdir "$5"; printf "keep\\n" > "$5/user-file"; fi\nexec /usr/bin/mv "$@"\n', { mode: 0o755 });
  const result = spawnSync('bash', [publisher, 'publish', source, dest,
    String(process.getuid()), String(process.getgid())], {
    encoding: 'utf8', env: { ...process.env, PATH: `${bin}:${process.env.PATH}` },
  });
  assert.equal(result.status, 4, result.stderr);
  assert.equal(readFileSync(join(dest, 'user-file'), 'utf8'), 'keep\n');
});

test('delivery metadata is excluded while runtime modes and palette independence are preserved', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-gtk4-publication-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const source = join(dir, 'source');
  const dest = join(dir, 'gtk4');
  mkdirSync(source);
  for (const name of ['apply', 'packages', 'install-runtime', 'sources.md'])
    writeFileSync(join(source, name), 'delivery metadata\n');
  writeFileSync(join(source, 'base.css'), 'button { opacity: 1; }\n');
  mkdirSync(join(source, 'assets'));
  writeFileSync(join(source, 'assets/slider@2.png'), Buffer.from([0x89, 0x50, 0x4e, 0x47]));
  writeFileSync(join(source, 'launch'), '#!/usr/bin/bash\nexit 0\n', { mode: 0o755 });
  const result = spawnSync('bash', [publisher, 'publish', source, dest,
    String(process.getuid()), String(process.getgid())], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  for (const name of ['apply', 'packages', 'install-runtime', 'sources.md', 'theme.name'])
    assert.equal(existsSync(join(dest, name)), false, name);
  assert.equal(readFileSync(join(dest, 'base.css'), 'utf8'), 'button { opacity: 1; }\n');
  assert.deepEqual(readFileSync(join(dest, 'assets/slider@2.png')), readFileSync(join(source, 'assets/slider@2.png')));
  assert.match(readFileSync(join(dest, '.mirroros-manifest'), 'utf8'), /^f 755 [a-f0-9]{64} \.\/launch$/m);
});

test('unsupported source entries cannot be published', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-theme-source-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const source = join(dir, 'source');
  mkdirSync(source);
  symlinkSync('/tmp', join(source, 'link'));
  const result = spawnSync('bash', [publisher, 'publish', source, join(dir, 'dest'),
    String(process.getuid()), String(process.getgid())], { encoding: 'utf8' });
  assert.equal(result.status, 6);
  rmSync(join(source, 'link'));
  writeFileSync(join(source, 'invalid name'), 'data');
  const invalidName = spawnSync('bash', [publisher, 'publish', source, join(dir, 'dest'),
    String(process.getuid()), String(process.getgid())], { encoding: 'utf8' });
  assert.equal(invalidName.status, 6);
});
