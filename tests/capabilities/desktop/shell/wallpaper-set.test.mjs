import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readlinkSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const helper = fileURLToPath(new URL('../../../../capabilities/desktop/shell/services/wallpaper-set', import.meta.url));

function fixture(t) {
  const home = mkdtempSync(join(tmpdir(), 'mirroros-wallpaper-set-'));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const state = join(home, 'state');
  const link = join(state, 'mirroros/current/background');
  const image = join(home, 'outside catalog ; image.png');
  writeFileSync(image, 'existence, not decoding, is checked');
  const run = (path = image) => spawnSync('bash', [helper, path], {
    env: { ...process.env, HOME: home, XDG_STATE_HOME: state }, encoding: 'utf8',
  });
  return { home, link, image, run };
}

test('selection accepts an existing file outside the catalog and resolves its link', (t) => {
  const { home, link, image, run } = fixture(t);
  const alias = join(home, 'alias.png');
  symlinkSync(image, alias);
  const result = run(alias);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, image);
  assert.equal(readlinkSync(link), image);
  const other = join(home, 'other.png');
  writeFileSync(other, 'other');
  assert.equal(run(other).status, 0);
  assert.equal(readlinkSync(link), other);
});

test('missing images do not create state or replace an existing selection', (t) => {
  const { home, link, image, run } = fixture(t);
  assert.notEqual(run(join(home, 'missing.png')).status, 0);
  assert.ok(!existsSync(dirname(link)));
  assert.equal(run().status, 0);
  assert.notEqual(run(join(home, 'missing.png')).status, 0);
  assert.equal(readlinkSync(link), image);
});

test('unknown regular files and directories at the selection path are preserved', (t) => {
  for (const kind of ['file', 'directory']) {
    const { link, run } = fixture(t);
    mkdirSync(dirname(link), { recursive: true });
    if (kind === 'file') writeFileSync(link, 'personal');
    else mkdirSync(link);
    const result = run();
    assert.equal(result.status, 4, result.stderr);
    if (kind === 'file') assert.equal(readFileSync(link, 'utf8'), 'personal');
    else assert.ok(lstatSync(link).isDirectory());
  }
});
