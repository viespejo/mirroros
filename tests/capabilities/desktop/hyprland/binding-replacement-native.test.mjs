// Explore staged replacement with the native verifier; this is not the product loader.
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const hyprland = '/usr/bin/Hyprland';
const provider = resolve('capabilities/desktop/compositor/providers/hyprland');

test('native verifier accepts a staged personal binding replacement', { skip: !existsSync(hyprland) }, t => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-native-binding-replacement-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const home = join(dir, 'home'), runtime = join(dir, 'runtime');
  mkdirSync(home, { mode: 0o700 });
  mkdirSync(runtime, { mode: 0o700 });
  const entry = join(dir, 'entry.lua');
  const quote = JSON.stringify;
  writeFileSync(entry, `
local native_bind = hl.bind
local queued = {}
hl.bind = function(keys, dispatcher, options) queued[#queued + 1] = { keys = keys, dispatcher = dispatcher, options = options } end
dofile(${quote(join(provider, 'shell-bindings.lua'))})
local export = MirrorOSKeys.export
MirrorOSKeys.export = function() end
dofile(${quote(join(provider, 'window-bindings.lua'))})
MirrorOSKeys.export = export
local item = assert(MirrorOSKeys.entries['window.close'])
local replacement = hl.dsp.exec_cmd('true')
local count = 0
for _, binding in ipairs(queued) do
  if binding.keys == item.keys then
    count = count + 1
    binding.dispatcher = replacement
    binding.options.description = 'Personal close action'
  end
end
assert(count == 1)
item.dispatcher = replacement
item.description = 'Personal close action'
hl.bind = native_bind
for _, binding in ipairs(queued) do native_bind(binding.keys, binding.dispatcher, binding.options) end
MirrorOSKeys.export()
print('STAGED ' .. #queued)
`);
  const result = spawnSync(hyprland, ['--verify-config', '--config', entry], {
    cwd: dir, env: { HOME: home, USER: process.env.USER || 'test', PATH: '/usr/bin:/bin', XDG_RUNTIME_DIR: runtime,
      HYPRLAND_INSTANCE_SIGNATURE: 'test-instance', XDG_CONFIG_HOME: join(home, '.config'), XDG_CACHE_HOME: join(home, '.cache') },
    encoding: 'utf8', timeout: 10000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  assert.equal(result.status, 0, output);
  assert.match(output, /config ok/);
  assert.match(output, /STAGED 117/);
  assert.match(readFileSync(join(runtime, 'mirroros-keybindings.tsv'), 'utf8'), /^window\.close\tSUPER \+ W\tPersonal close action$/m);
});
