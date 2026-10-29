import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const lua = ['lua5.4', 'lua'].find(name => spawnSync(name, ['-v']).status === 0);
const loader = resolve('capabilities/desktop/compositor/providers/hyprland/personal-loader.lua');

function run(t, files) {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-personal-loader-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  for (const [name, content] of Object.entries(files)) writeFileSync(join(dir, `${name}.lua`), content);
  const runner = join(dir, 'runner.lua');
  writeFileSync(runner, `MirrorOSKeys = { export = function() print("EXPORT") end }\nlocal load = dofile(arg[1])\nload(arg[2], function(message) print("WARN " .. message) end)\n`);
  const result = spawnSync(lua, [runner, loader, dir], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim().split('\n');
}

test('optional personal layers load in order and export bindings', { skip: !lua }, t => {
  const files = Object.fromEntries(['monitors', 'input', 'looknfeel', 'bindings', 'autostart'].map(name => [name, `print("${name}")\n`]));
  assert.deepEqual(run(t, files), ['monitors', 'input', 'looknfeel', 'bindings', 'EXPORT', 'autostart']);
});

test('missing layers are silent and still export bindings', { skip: !lua }, t => {
  assert.deepEqual(run(t, {}), ['EXPORT']);
});

test('binding errors warn, export partial state and continue', { skip: !lua }, t => {
  const lines = run(t, { bindings: 'print("PARTIAL")\nerror("synthetic failure")\n', autostart: 'print("LATER")\n' });
  assert.equal(lines[0], 'PARTIAL');
  assert.match(lines[1], /^WARN Cannot load personal Hyprland bindings: .*synthetic failure/);
  assert.deepEqual(lines.slice(2), ['EXPORT', 'LATER']);
});

test('syntax errors warn and do not prevent later layers', { skip: !lua }, t => {
  const lines = run(t, { input: 'not valid lua !!!\n', looknfeel: 'print("LATER")\n' });
  assert.match(lines[0], /^WARN Cannot load personal Hyprland input:/);
  assert.deepEqual(lines.slice(1), ['LATER', 'EXPORT']);
});
