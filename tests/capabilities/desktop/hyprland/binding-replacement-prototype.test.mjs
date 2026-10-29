// Explore selecting a personal replacement before binding; this does not modify the provider.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const lua = ['lua5.4', 'lua'].find(name => spawnSync(name, ['-v']).status === 0);
const provider = resolve('capabilities/desktop/compositor/providers/hyprland');

test('a pre-registration replacement can keep one chord and an accurate registry', { skip: !lua }, t => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-binding-replacement-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const runner = join(dir, 'prototype.lua');
  writeFileSync(runner, `
local queued, applied = {}, {}
local dsp = setmetatable({}, { __index = function(_, family)
  return setmetatable({}, {
    __index = function(_, call) return function() return { kind = family .. '.' .. call } end end,
    __call = function() return { kind = family } end,
  })
end })
dsp.exec_cmd = function(command) return { kind = 'exec', command = command } end
hl = { dsp = dsp, config = function() end, get_config = function() end, dispatch = function() end,
  bind = function(keys, dispatcher, options) queued[#queued + 1] = { keys = keys, dispatcher = dispatcher, options = options } end }
dofile(arg[1] .. '/shell-bindings.lua')
dofile(arg[1] .. '/window-bindings.lua')
local entry = assert(MirrorOSKeys.entries['window.close'])
local replacement = hl.dsp.exec_cmd('personal-action')
local count = 0
for _, binding in ipairs(queued) do
  if binding.keys == entry.keys then
    count = count + 1
    binding.dispatcher = replacement
    binding.options.description = 'Personal close action'
  end
end
assert(count == 1)
entry.dispatcher = replacement
entry.description = 'Personal close action'
MirrorOSKeys.export()
for _, binding in ipairs(queued) do
  applied[#applied + 1] = binding
  if binding.keys == 'SUPER + W' then print(binding.keys .. '\\t' .. binding.options.description .. '\\t' .. binding.dispatcher.command) end
end
print('COUNT ' .. #applied)
`);
  const result = spawnSync(lua, [runner, provider], { encoding: 'utf8', env: { PATH: process.env.PATH,
    XDG_RUNTIME_DIR: dir, HYPRLAND_INSTANCE_SIGNATURE: 'test-instance' } });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /SUPER \+ W\tPersonal close action\tpersonal-action/);
  assert.match(result.stdout, /COUNT 117/);
  const registry = readFileSync(join(dir, 'mirroros-keybindings.tsv'), 'utf8');
  assert.match(registry, /^window\.close\tSUPER \+ W\tPersonal close action$/m);
});
