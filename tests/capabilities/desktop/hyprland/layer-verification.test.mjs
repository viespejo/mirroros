// Run with Hyprland installed. This checks config loading without starting a compositor.
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const hyprland = '/usr/bin/Hyprland';

for (const scenario of ['valid', 'missing-theme', 'invalid-theme', 'partial-theme', 'invalid-config']) {
  test(`Hyprland verifier loads isolated layers: ${scenario}`, { skip: !existsSync(hyprland) }, (t) => {
    const dir = mkdtempSync(join(tmpdir(), 'mirroros-hypr-layers-'));
    t.after(() => rmSync(dir, { recursive: true, force: true }));
    const home = join(dir, 'home');
    const runtime = join(dir, 'runtime');
    mkdirSync(home, { mode: 0o700 });
    mkdirSync(runtime, { mode: 0o700 });
    const marker = join(dir, 'order');
    const defaults = join(dir, 'defaults.lua');
    const theme = join(dir, 'theme.lua');
    const personal = join(dir, 'personal.lua');
    const entry = join(dir, 'hyprland.lua');
    const luaString = (value) => JSON.stringify(value);
    const layer = (name, color, size) => `local f = assert(io.open(${luaString(marker)}, "a")); f:write("${name}\\n"); f:close()\nhl.config({ general = { border_size = ${size}, col = { active_border = "${color}" } } })\n`;
    writeFileSync(defaults, layer('defaults', 'rgba(111111ff)', 1));
    if (scenario === 'valid') writeFileSync(theme, layer('theme', 'rgba(509475ff)', 3));
    if (scenario === 'invalid-theme') writeFileSync(theme, 'error("synthetic theme failure")\n');
    if (scenario === 'partial-theme') writeFileSync(theme, layer('theme', 'rgba(509475ff)', 3) + 'error("synthetic failure after side effects")\n');
    if (scenario === 'invalid-config') writeFileSync(theme, layer('theme', 'not-a-color', 3));
    writeFileSync(personal, layer('personal', 'rgba(222222ff)', 5));
    writeFileSync(entry, `local function snapshot(name) print("BORDER " .. name .. " " .. tostring(hl.get_config("general:border_size"))); print("COLOR " .. name .. " " .. tostring(hl.get_config("general:col.active_border").colors[1])) end\ndofile(${luaString(defaults)})\nsnapshot("defaults")\nlocal ok, err = pcall(dofile, ${luaString(theme)})\nif not ok then print("OPTIONAL THEME FAILED: " .. err) end\nsnapshot("theme")\ndofile(${luaString(personal)})\nsnapshot("personal")\n`);
    const result = spawnSync(hyprland, ['--verify-config', '--config', entry], {
      cwd: dir,
      env: { HOME: home, USER: process.env.USER || 'test', PATH: '/usr/bin:/bin', XDG_RUNTIME_DIR: runtime,
        XDG_CONFIG_HOME: join(home, '.config'), XDG_CACHE_HOME: join(home, '.cache') },
      encoding: 'utf8', timeout: 10000,
    });
    const output = (result.stdout || '') + (result.stderr || '');
    assert.equal(result.status, scenario === 'invalid-config' ? 1 : 0, output);
    if (scenario === 'invalid-config') assert.match(output, /invalid color/);
    else assert.match(output, /config ok/);
    assert.match(output, /BORDER defaults 1/);
    assert.match(output, ['valid', 'partial-theme', 'invalid-config'].includes(scenario) ? /BORDER theme 3/ : /BORDER theme 1/);
    assert.match(output, /BORDER personal 5/);
    assert.match(output, /COLOR defaults 0xFF111111/i);
    assert.match(output, ['valid', 'partial-theme'].includes(scenario) ? /COLOR theme 0xFF509475/i : /COLOR theme 0xFF111111/i);
    assert.match(output, /COLOR personal 0xFF222222/i);
    assert.equal(readFileSync(marker, 'utf8'), ['valid', 'partial-theme', 'invalid-config'].includes(scenario) ? 'defaults\ntheme\npersonal\n' : 'defaults\npersonal\n');
    if (['missing-theme', 'invalid-theme', 'partial-theme'].includes(scenario)) assert.match(output, /OPTIONAL THEME FAILED/);
    if (scenario === 'invalid-config') assert.doesNotMatch(output, /OPTIONAL THEME FAILED/);
  });
}
