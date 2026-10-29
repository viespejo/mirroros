// Verify the actual entry point and personal loader without starting a compositor.
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const hyprland = '/usr/bin/Hyprland';
const provider = resolve('capabilities/desktop/compositor/providers/hyprland');
for (const scenario of ['missing', 'valid', 'error', 'replacement', 'missing-loader']) {
  test(`isolated Hyprland personal integration: ${scenario}`, { skip: !existsSync(hyprland) }, t => {
    const dir = mkdtempSync(join(tmpdir(), 'mirroros-hypr-personal-integration-'));
    t.after(() => rmSync(dir, { recursive: true, force: true }));
    const home = join(dir, 'home'), runtime = join(dir, 'runtime'), personal = join(home, '.config/hypr');
    mkdirSync(personal, { recursive: true });
    mkdirSync(runtime, { mode: 0o700 });
    const names = ['defaults.lua', 'personal-loader.lua', 'theme-runtime.lua', 'monitors.lua', 'shell-bindings.lua', 'window-bindings.lua'];
    let defaults = readFileSync(join(provider, 'defaults.lua'), 'utf8');
    let entry = readFileSync(join(provider, 'hyprland.lua'), 'utf8');
    for (const name of names) {
      defaults = defaults.replaceAll(`/usr/share/mirroros/hypr/${name}`, join(dir, name));
      entry = entry.replaceAll(`/usr/share/mirroros/hypr/${name}`, join(dir, name));
    }
    writeFileSync(join(dir, 'defaults.lua'), defaults);
    if (scenario !== 'missing-loader') writeFileSync(join(dir, 'personal-loader.lua'), readFileSync(join(provider, 'personal-loader.lua')));
    writeFileSync(join(dir, 'theme-runtime.lua'), 'return function() return nil end\n');
    writeFileSync(join(dir, 'monitors.lua'), '-- isolated\n');
    const realBindings = ['replacement', 'missing-loader'].includes(scenario);
    writeFileSync(join(dir, 'shell-bindings.lua'), realBindings ? readFileSync(join(provider, 'shell-bindings.lua')) : 'MirrorOSKeys = { export = function() print("EXPORT") end }\n');
    writeFileSync(join(dir, 'window-bindings.lua'), realBindings ? readFileSync(join(provider, 'window-bindings.lua')) : '-- isolated\n');
    if (scenario !== 'missing' && scenario !== 'missing-loader') {
      writeFileSync(join(personal, 'looknfeel.lua'), 'hl.config({ general = { border_size = 5 } })\n');
      writeFileSync(join(personal, 'bindings.lua'), scenario === 'error' ? 'print("PARTIAL")\nerror("synthetic failure")\n' : scenario === 'replacement' ? 'MirrorOSKeys.replace("window.close", "Personal close action", hl.dsp.exec_cmd("true"))\n' : 'print("PERSONAL BINDINGS")\n');
      writeFileSync(join(personal, 'autostart.lua'), 'print("PERSONAL LAST")\n');
    }
    const config = join(dir, 'entry.lua');
    writeFileSync(config, `package.preload['/usr/share/mirroros/hypr/layouts.lua'] = function() return 'us' end\n` + entry + `\nprint('BORDER ' .. tostring(hl.get_config('general:border_size')))\nprint('ACTIVE_OPACITY ' .. tostring(hl.get_config('decoration:active_opacity')))\nprint('INACTIVE_OPACITY ' .. tostring(hl.get_config('decoration:inactive_opacity')))\nprint('BLUR ' .. tostring(hl.get_config('decoration:blur:enabled')))\n`);
    const result = spawnSync(hyprland, ['--verify-config', '--config', config], {
      cwd: dir, env: { HOME: home, USER: process.env.USER || 'test', PATH: '/usr/bin:/bin', XDG_RUNTIME_DIR: runtime,
        HYPRLAND_INSTANCE_SIGNATURE: 'test-instance', XDG_CONFIG_HOME: join(home, '.config'), XDG_CACHE_HOME: join(home, '.cache') }, encoding: 'utf8', timeout: 10000,
    });
    const output = (result.stdout || '') + (result.stderr || '');
    assert.equal(result.status, 0, output);
    assert.match(output, /config ok/);
    if (realBindings) {
      const registry = readFileSync(join(runtime, 'mirroros-keybindings.tsv'), 'utf8');
      assert.match(registry, scenario === 'replacement' ? /^window\.close\tSUPER \+ W\tPersonal close action$/m : /^window\.close\tSUPER \+ W\tClose window$/m);
    } else assert.match(output, /EXPORT/);
    const active = output.match(/\[Lua\] ACTIVE_OPACITY ([0-9.]+)/);
    const inactive = output.match(/\[Lua\] INACTIVE_OPACITY ([0-9.]+)/);
    assert.ok(active && Math.abs(Number(active[1]) - 0.985) < 0.00001, output);
    assert.ok(inactive && Math.abs(Number(inactive[1]) - 0.96) < 0.00001, output);
    assert.match(output, /BLUR false/);
    if (scenario === 'missing' || scenario === 'missing-loader') {
      assert.match(output, /BORDER 2/);
      if (scenario === 'missing') assert.doesNotMatch(output, /Cannot load personal Hyprland/);
      else assert.match(output, /Cannot load personal Hyprland layers/);
    }
    else {
      assert.match(output, /BORDER 5/);
      assert.match(output, /PERSONAL LAST/);
      if (scenario === 'error') assert.match(output, /Cannot load personal Hyprland bindings: .*synthetic failure/);
      else if (scenario === 'valid') assert.match(output, /PERSONAL BINDINGS/);
      else assert.doesNotMatch(output, /Cannot load personal Hyprland bindings/);
    }
  });
}
