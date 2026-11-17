// Verify duplicate chord parsing without starting a compositor. This does not test dispatch.
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const hyprland = '/usr/bin/Hyprland';

test('screenshot registry rejects duplicate capture chords', () => {
  const provider = new URL('../../../../capabilities/desktop/compositor/providers/hyprland/', import.meta.url).pathname;
  for (const keys of ['PRINT', 'ALT + CTRL + SUPER + C', 'CTRL + SUPER + C']) {
    const result = spawnSync('lua', ['-e', `
      hl = { dsp = { exec_cmd = function() return {} end, global = function() return {} end },
        bind = function() end, layer_rule = function() end }
      MirrorOSStageBindings = true
      dofile(arg[1] .. '/shell-bindings.lua')
      dofile(arg[1] .. '/omasnap/screenshot-bindings.lua')
      assert(not pcall(MirrorOSKeys.bind, 'personal.duplicate', arg[2], 'Duplicate', {}))
    `, '-', provider, keys], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
  }
});

test('Hyprland verifier accepts duplicate clipboard chords', { skip: !existsSync(hyprland) }, (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-hypr-duplicate-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const home = join(dir, 'home');
  const runtime = join(dir, 'runtime');
  mkdirSync(home, { mode: 0o700 });
  mkdirSync(runtime, { mode: 0o700 });
  const config = join(dir, 'hyprland.lua');
  writeFileSync(config, 'hl.bind("SUPER + C", hl.dsp.exec_cmd("true"), { description = "Universal copy" })\n' +
    'hl.bind("SUPER + C", hl.dsp.exec_cmd("false"), { description = "Personal copy" })\n');
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
