// Verify duplicate chord parsing without starting a compositor. This does not test dispatch.
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const hyprland = '/usr/bin/Hyprland';

test('Hyprland verifier accepts duplicate chords', { skip: !existsSync(hyprland) }, (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-hypr-duplicate-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const home = join(dir, 'home');
  const runtime = join(dir, 'runtime');
  mkdirSync(home, { mode: 0o700 });
  mkdirSync(runtime, { mode: 0o700 });
  const config = join(dir, 'hyprland.lua');
  writeFileSync(config, 'hl.bind("SUPER + F12", hl.dsp.exec_cmd("true"), { description = "First" })\n' +
    'hl.bind("SUPER + F12", hl.dsp.exec_cmd("false"), { description = "Second" })\n');
  const result = spawnSync(hyprland, ['--verify-config', '--config', config], {
    cwd: dir,
    env: { HOME: home, USER: process.env.USER || 'test', PATH: '/usr/bin:/bin', XDG_RUNTIME_DIR: runtime,
      XDG_CONFIG_HOME: join(home, '.config'), XDG_CACHE_HOME: join(home, '.cache') },
    encoding: 'utf8', timeout: 10000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  assert.equal(result.status, 0, output);
  assert.match(output, /config ok/);
});
