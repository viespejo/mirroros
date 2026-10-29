import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, readdirSync, readlinkSync, rmSync, statSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const script = resolve('capabilities/visual/theme/prepare-current');
const target = '/usr/share/mirroros/themes/default';

function fixture(t) {
  const home = mkdtempSync(join(tmpdir(), 'mirroros-current-'));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const run = (state, args = [], extra = {}) => {
    const env = { ...process.env, ...extra, HOME: home };
    delete env.XDG_STATE_HOME;
    if (state !== undefined) env.XDG_STATE_HOME = state;
    return spawnSync('bash', [script, ...args], { env, encoding: 'utf8' });
  };
  return { home, run };
}

test('creates the default link once and respects an absolute state directory', (t) => {
  const { home, run } = fixture(t);
  const link = join(home, '.local/state/mirroros/current/theme');
  assert.equal(run().stdout, 'changed\n');
  assert.equal(readlinkSync(link), target);
  assert.equal(run().stdout, 'unchanged\n');
  const state = join(home, 'custom-state');
  assert.equal(run(state).stdout, 'changed\n');
  assert.equal(readlinkSync(join(state, 'mirroros/current/theme')), target);
  assert.equal(run('relative').status, 4);
});

test('session mode ignores inherited state and uses the user manager when available', (t) => {
  const { home, run } = fixture(t);
  const bin = join(home, 'bin');
  mkdirSync(bin);
  const systemctl = join(bin, 'systemctl');
  const custom = join(home, 'session-state');
  writeFileSync(systemctl, `#!/bin/sh\nprintf 'XDG_STATE_HOME=%s\\n' '${custom}'\n`, { mode: 0o755 });
  const env = { PATH: `${bin}:${process.env.PATH}` };
  assert.equal(run('/inherited/root-state', ['--session'], env).status, 0);
  assert.equal(readlinkSync(join(custom, 'mirroros/current/theme')), target);
  writeFileSync(systemctl, '#!/bin/sh\nexit 1\n', { mode: 0o755 });
  assert.equal(run('/inherited/root-state', ['--session'], env).status, 0);
  assert.equal(readlinkSync(join(home, '.local/state/mirroros/current/theme')), target);
});

test('preserves unknown files, directories and links', (t) => {
  for (const kind of ['file', 'directory', 'link']) {
    const { home, run } = fixture(t);
    const dir = join(home, '.local/state/mirroros/current');
    const link = join(dir, 'theme');
    mkdirSync(dir, { recursive: true });
    if (kind === 'file') writeFileSync(link, 'personal');
    if (kind === 'directory') mkdirSync(link);
    if (kind === 'link') symlinkSync('/unknown/theme', link);
    const result = run();
    assert.equal(result.status, 4);
    assert.match(result.stderr, /Conflict/);
    if (kind === 'file') assert.equal(readFileSync(link, 'utf8'), 'personal');
    if (kind === 'link') assert.equal(readlinkSync(link), '/unknown/theme');
  }
});
