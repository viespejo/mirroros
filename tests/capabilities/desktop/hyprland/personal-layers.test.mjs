// Verify personal layer ordering without starting a compositor or touching user files.
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const hyprland = '/usr/bin/Hyprland';
const layers = ['monitors', 'input', 'looknfeel', 'bindings', 'autostart'];

for (const scenario of ['valid', 'missing', 'error']) {
  test(`Hyprland verifier loads personal layers: ${scenario}`, { skip: !existsSync(hyprland) }, (t) => {
    const dir = mkdtempSync(join(tmpdir(), 'mirroros-hypr-personal-'));
    t.after(() => rmSync(dir, { recursive: true, force: true }));
    const home = join(dir, 'home');
    const runtime = join(dir, 'runtime');
    mkdirSync(home, { mode: 0o700 });
    mkdirSync(runtime, { mode: 0o700 });
    const marker = join(dir, 'order');
    const entry = join(dir, 'hyprland.lua');
    const quote = JSON.stringify;
    for (const [index, name] of layers.entries()) {
      if (scenario === 'missing' && name === 'input') continue;
      const failure = scenario === 'error' && name === 'input' ? 'error("synthetic personal failure")\n' : '';
      writeFileSync(join(dir, `${name}.lua`), `local f = assert(io.open(${quote(marker)}, "a")); f:write("${name}\\n"); f:close()\nhl.config({ general = { border_size = ${index + 2} } })\n${failure}`);
    }
    writeFileSync(entry, `hl.config({ general = { border_size = 1 } })\nfor _, name in ipairs({ ${layers.map(quote).join(', ')} }) do\n  local path = ${quote(dir + '/')} .. name .. ".lua"\n  local file = io.open(path, "r")\n  if file then\n    file:close()\n    local ok, err = pcall(dofile, path)\n    if not ok then print("PERSONAL FAILED " .. name .. ": " .. err) end\n  end\n  print("BORDER " .. name .. " " .. tostring(hl.get_config("general:border_size")))\nend\n`);
    const result = spawnSync(hyprland, ['--verify-config', '--config', entry], {
      cwd: dir,
      env: { HOME: home, USER: process.env.USER || 'test', PATH: '/usr/bin:/bin', XDG_RUNTIME_DIR: runtime,
        XDG_CONFIG_HOME: join(home, '.config'), XDG_CACHE_HOME: join(home, '.cache') },
      encoding: 'utf8', timeout: 10000,
    });
    const output = (result.stdout || '') + (result.stderr || '');
    assert.equal(result.status, 0, output);
    assert.match(output, /config ok/);
    assert.equal(readFileSync(marker, 'utf8'), layers.filter((name) => scenario !== 'missing' || name !== 'input').join('\n') + '\n');
    assert.match(output, /BORDER monitors 2/);
    assert.match(output, scenario === 'missing' ? /BORDER input 2/ : /BORDER input 3/);
    assert.match(output, /BORDER autostart 6/);
    if (scenario === 'error') assert.match(output, /PERSONAL FAILED input/);
    else assert.doesNotMatch(output, /PERSONAL FAILED/);
  });
}
