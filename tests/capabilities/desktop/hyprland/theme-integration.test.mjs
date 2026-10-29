// Isolated Hyprland config verification; no compositor or installed files are changed.
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const hyprland = '/usr/bin/Hyprland';
const provider = resolve('capabilities/desktop/compositor/providers/hyprland');
for (const scenario of ['valid', 'invalid', 'missing-runtime']) {
  test(`isolated Hyprland theme integration: ${scenario}`, { skip: !existsSync(hyprland) }, (t) => {
    const dir = mkdtempSync(join(tmpdir(), 'mirroros-hypr-integration-'));
    t.after(() => rmSync(dir, { recursive: true, force: true }));
    const home = join(dir, 'home'), runtime = join(dir, 'runtime');
    mkdirSync(home, { mode: 0o700 });
    mkdirSync(runtime, { mode: 0o700 });
    const q = JSON.stringify;
    const modulePath = name => join(dir, name);
    for (const name of ['theme-loader.lua', 'theme-validation.lua']) {
      writeFileSync(modulePath(name), readFileSync(join(provider, name), 'utf8'));
    }
    const theme = modulePath('theme.lua');
    writeFileSync(theme, scenario === 'invalid' ? 'return { active_border = "invalid" }\n' :
      'return { active_border = "rgba(abcdef12)", inactive_border = "rgba(12345678)" }\n');
    let runtimeText = readFileSync(join(provider, 'theme-runtime.lua'), 'utf8');
    for (const name of ['theme-loader.lua', 'theme-validation.lua']) {
      runtimeText = runtimeText.replace(`/usr/share/mirroros/hypr/${name}`, modulePath(name));
    }
    runtimeText = runtimeText.replace('loadfile(path, "t", {})', `loadfile(${q(theme)}, "t", {})`);
    if (scenario !== 'missing-runtime') writeFileSync(modulePath('theme-runtime.lua'), runtimeText);
    for (const name of ['monitors.lua', 'shell-bindings.lua', 'window-bindings.lua']) writeFileSync(modulePath(name), '-- isolated stub\n');
    let source = readFileSync(join(provider, 'defaults.lua'), 'utf8');
    for (const name of ['monitors.lua', 'shell-bindings.lua', 'window-bindings.lua', 'theme-runtime.lua']) {
      source = source.replace(`/usr/share/mirroros/hypr/${name}`, modulePath(name));
    }
    const prelude = `package.preload['/usr/share/mirroros/hypr/layouts.lua'] = function() return 'us' end\nio.popen = function() return { read = function() return '/usr/share/mirroros/themes/default/hyprland.lua\\n' end, close = function() return true end } end\n`;
    const probe = `\nprint('ACTIVE ' .. hl.get_config('general:col.active_border').colors[1])\nprint('INACTIVE ' .. hl.get_config('general:col.inactive_border').colors[1])\n`;
    const entry = join(dir, 'entry.lua');
    writeFileSync(entry, prelude + source + probe);
    const result = spawnSync(hyprland, ['--verify-config', '--config', entry], { cwd: dir,
      env: { HOME: home, USER: process.env.USER || 'test', PATH: '/usr/bin:/bin', XDG_RUNTIME_DIR: runtime,
        XDG_CONFIG_HOME: join(home, '.config'), XDG_CACHE_HOME: join(home, '.cache') }, encoding: 'utf8', timeout: 10000 });
    const output = (result.stdout || '') + (result.stderr || '');
    assert.equal(result.status, 0, output);
    assert.match(output, /config ok/);
    assert.match(output, scenario === 'valid' ? /ACTIVE 0x12ABCDEF/i : /ACTIVE 0xFF509475/i);
    assert.match(output, scenario === 'valid' ? /INACTIVE 0x78123456/i : /INACTIVE 0xAA595959/i);
    if (scenario !== 'valid') assert.match(output, /using provider defaults/);
  });
}
