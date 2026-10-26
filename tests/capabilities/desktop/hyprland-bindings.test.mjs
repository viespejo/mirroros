// Static contracts of the delivered Hyprland bindings, run with a Lua interpreter and a recording `hl` stub.
// They check the approved key table before delivery; runtime behavior in Hyprland is an attended session check.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const provider = path.join(root, 'capabilities/desktop/compositor/providers/hyprland');
const shell = path.join(root, 'capabilities/desktop/shell');
const lua = ['lua5.4', 'lua'].find(name => spawnSync(name, ['-v']).status === 0);

// The stub records every hl.bind as "keys<TAB>description<TAB>options<TAB>dispatcher"; dispatchers are tables that
// name the dsp call and its exec command. The configuration is loaded twice, as at a reload.
const stub = `
local out = {}
local function described(name, args)
  if name == "exec_cmd" then return { kind = "exec", command = args } end
  return { kind = name }
end
local dsp = setmetatable({}, { __index = function(_, family)
  local value = setmetatable({}, {
    __index = function(_, call) return function(args) return described(family .. "." .. call, args) end end,
    __call = function(_, args) return described(family, args) end,
  })
  return value
end })
hl = {
  dsp = dsp,
  bind = function(keys, dispatcher, opts)
    local flags = {}
    for name, value in pairs(opts or {}) do if name ~= "description" then flags[#flags + 1] = name .. "=" .. tostring(value) end end
    table.sort(flags)
    local text = type(dispatcher) == "function" and "function" or (dispatcher.command or dispatcher.kind)
    out[#out + 1] = keys .. "\\t" .. tostring(opts and opts.description) .. "\\t" .. table.concat(flags, ",") .. "\\t" .. text
  end,
  config = function() end, dispatch = function() end, get_config = function() end,
}
local mode = arg[1]
for load = 1, 2 do
  out = {}
  dofile(arg[2] .. "/shell-bindings.lua")
  if mode == "duplicate" then MirrorOSKeys.bind("extra.duplicate", "SHIFT + SUPER + i", "Duplicate", "x") end
  dofile(arg[2] .. "/window-bindings.lua")
end
for _, line in ipairs(out) do print(line) end
`;

function load(mode = 'normal') {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mirroros-bindings-'));
  try {
    fs.writeFileSync(path.join(dir, 'stub.lua'), stub);
    const result = spawnSync(lua, [path.join(dir, 'stub.lua'), mode, provider], {
      encoding: 'utf8', env: { PATH: process.env.PATH, XDG_RUNTIME_DIR: dir, HYPRLAND_INSTANCE_SIGNATURE: 'test-instance' },
    });
    const registry = fs.existsSync(path.join(dir, 'mirroros-keybindings.tsv'))
      ? fs.readFileSync(path.join(dir, 'mirroros-keybindings.tsv'), 'utf8') : null;
    return { ...result, registry, leftovers: fs.readdirSync(dir).filter(name => name !== 'stub.lua') };
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const chord = keys => {
  const parts = keys.split('+').map(part => part.trim().toUpperCase().replace(/^CONTROL$/, 'CTRL'));
  const mods = parts.filter(part => ['SUPER', 'SHIFT', 'CTRL', 'ALT'].includes(part)).sort();
  return [...mods, parts.find(part => !['SUPER', 'SHIFT', 'CTRL', 'ALT'].includes(part))].join('+');
};

const loaded = lua ? load() : null;
const bindings = loaded ? loaded.stdout.trim().split('\n').map(line => {
  const [keys, description, options, action] = line.split('\t');
  return { keys, chord: chord(keys), description, options, action };
}) : [];
const byChord = new Map(bindings.map(binding => [binding.chord, binding]));

test('the bindings load twice without error and no source unbinds at runtime', { skip: !lua && 'no Lua interpreter' }, () => {
  assert.equal(loaded.status, 0, loaded.stderr);
  assert.equal(bindings.length, 116);
  for (const file of ['shell-bindings.lua', 'window-bindings.lua', 'hyprland.lua']) {
    const code = fs.readFileSync(path.join(provider, file), 'utf8').split('\n').filter(line => !/^\s*--/.test(line)).join('\n');
    assert.doesNotMatch(code, /unbind/, file);
    assert.doesNotMatch(code, /\brequire\s*\(\s*["'][^"']*bindings/, file);
  }
  assert.match(fs.readFileSync(path.join(provider, 'shell-bindings.lua'), 'utf8'), /^MirrorOSKeys = \{ entries = \{\}, chords = \{\} \}$/m);
});

test('no chord is bound twice and the helper rejects a repeated chord', { skip: !lua && 'no Lua interpreter' }, () => {
  assert.equal(byChord.size, bindings.length);
  const duplicate = load('duplicate');
  assert.notEqual(duplicate.status, 0);
  assert.match(duplicate.stderr, /repeated chord SHIFT \+ SUPER \+ i/);
});

test('every approved Story 4.3 key is bound with a description', { skip: !lua && 'no Lua interpreter' }, () => {
  const required = [
    'SUPER+SPACE', 'SHIFT+SUPER+CODE:201', 'SUPER+D', 'ALT+SUPER+SPACE', 'SUPER+ESCAPE', 'XF86POWEROFF', 'SUPER+K',
    'SUPER+I', 'SHIFT+SUPER+I', 'SUPER+COMMA', 'SHIFT+SUPER+COMMA', 'CTRL+SUPER+COMMA', 'ALT+SUPER+COMMA',
    'ALT+SHIFT+SUPER+COMMA', 'SUPER+APOSTROPHE', 'ALT+SUPER+APOSTROPHE', 'CTRL+SUPER+L', 'SUPER+RETURN',
    'ALT+SUPER+RETURN', 'SUPER+W', 'SUPER+Q', 'SUPER+J', 'SUPER+P', 'SUPER+T', 'SUPER+F', 'ALT+SUPER+F', 'SUPER+TAB',
    'SUPER+S', 'SUPER+GRAVE', 'ALT+SUPER+S', 'SHIFT+SUPER+GRAVE', 'SUPER+G', 'ALT+SUPER+G', 'ALT+SUPER+TAB',
    'ALT+SHIFT+SUPER+TAB', 'CTRL+SUPER+LEFT', 'CTRL+SUPER+RIGHT', 'ALT+TAB', 'ALT+SHIFT+TAB', 'ALT+CTRL+TAB',
    'ALT+CTRL+SHIFT+TAB', 'CTRL+SUPER+Z', 'ALT+CTRL+SUPER+Z', 'SUPER+MOUSE:272', 'SUPER+MOUSE:273',
    'SUPER+MOUSE_DOWN', 'SUPER+MOUSE_UP', 'ALT+SUPER+MOUSE_DOWN', 'ALT+SUPER+MOUSE_UP',
  ];
  for (const direction of ['LEFT', 'RIGHT', 'UP', 'DOWN'])
    required.push(`SUPER+${direction}`, `SHIFT+SUPER+${direction}`, `ALT+SHIFT+SUPER+${direction}`,
      `CTRL+SHIFT+SUPER+${direction}`, `ALT+SUPER+${direction}`);
  for (let n = 1; n <= 10; n++) {
    const key = `CODE:${n + 9}`;
    required.push(`SUPER+${key}`, `SHIFT+SUPER+${key}`, `ALT+SHIFT+SUPER+${key}`);
    if (n <= 5) required.push(`ALT+SUPER+${key}`);
  }
  for (const mods of ['SUPER', 'ALT+SUPER', 'CTRL+SUPER'])
    for (const key of ['CODE:20', 'CODE:21']) required.push(`${mods}+${key}`, `${mods.replace('SUPER', 'SHIFT+SUPER')}+${key}`);
  for (const key of required) assert.ok(byChord.has(key), 'missing ' + key);
  assert.equal(new Set(required).size, bindings.length, 'every bound chord is in the approved list');
  for (const binding of bindings) assert.ok(binding.description && binding.description !== 'nil', binding.keys);
  assert.match(byChord.get('XF86POWEROFF').options, /locked=true/);
  for (const chord of ['SUPER+I', 'SHIFT+SUPER+I']) assert.doesNotMatch(byChord.get(chord).options, /locked=true/, chord);
  assert.match(byChord.get('SUPER+MOUSE:272').options, /mouse=true/);
});

test('reserved, excluded and retired keys stay unbound', { skip: !lua && 'no Lua interpreter' }, () => {
  const unbound = [
    'SHIFT+SUPER+Q', 'SHIFT+SUPER+E', 'SHIFT+SUPER+SPACE', 'CTRL+SUPER+I', 'SHIFT+SUPER+T', 'SUPER+L', 'ALT+SUPER+L',
    'SUPER+SLASH', 'ALT+SUPER+SLASH', 'SHIFT+SUPER+TAB', 'CTRL+SUPER+TAB', 'SUPER+F1', 'CTRL+SUPER+SPACE', 'SUPER+H',
    'SUPER+A', 'SUPER+C', 'SUPER+V', 'SUPER+X', 'CTRL+SUPER+V', 'CTRL+SUPER+C', 'PRINT', 'ALT+PRINT', 'SUPER+PRINT',
    'SHIFT+SUPER+RETURN', 'SHIFT+SUPER+B', 'SHIFT+SUPER+F', 'SHIFT+SUPER+N', 'CTRL+SUPER+A', 'CTRL+SUPER+B',
    'CTRL+SUPER+D', 'CTRL+SUPER+N', 'CTRL+SUPER+P', 'XF86AUDIORAISEVOLUME', 'XF86MONBRIGHTNESSUP', 'SUPER+O',
    'SUPER+M', 'ALT+CTRL+DELETE',
  ];
  for (const key of unbound) assert.ok(!byChord.has(key), 'unexpected ' + key);
});

test('shell actions call existing IPC functions of the installed shell', { skip: !lua && 'no Lua interpreter' }, () => {
  const ipc = bindings.map(binding => binding.action).filter(action => action.startsWith('qs '));
  assert.ok(ipc.length >= 14);
  const sources = {
    menu: fs.readFileSync(path.join(shell, 'menu/Menu.qml'), 'utf8'),
    notifications: fs.readFileSync(path.join(shell, 'notifications/Service.qml'), 'utf8'),
  };
  for (const action of ipc) {
    const match = action.match(/^qs ipc -p \/usr\/share\/mirroros\/shell call (menu|notifications) (\w+)(?: (\w+))?$/);
    assert.ok(match, action);
    assert.match(sources[match[1]], new RegExp(`function ${match[2]}\\(`), action);
  }
  for (const binding of bindings.filter(b => b.action.startsWith('uwsm ')))
    assert.match(binding.action, /^uwsm app -- foot( |$)/);
});

test('the registry lists launchable entries for the current instance and leaves no temporary file', { skip: !lua && 'no Lua interpreter' }, () => {
  const lines = loaded.registry.trimEnd().split('\n');
  assert.equal(lines[0], '# instance test-instance');
  const rows = lines.slice(1).map(line => line.split('\t'));
  const ids = rows.map(row => row[0]);
  assert.deepEqual(ids, [...ids].sort());
  assert.equal(rows.length, 110);
  for (const row of rows) assert.equal(row.length, 3);
  for (const hidden of ['mouse.move', 'mouse.resize', 'workspace.scroll-next', 'group.scroll-prev']) assert.ok(!ids.includes(hidden));
  assert.ok(ids.includes('help.keybindings') && ids.includes('terminal.open'));
  assert.deepEqual(loaded.leftovers, ['mirroros-keybindings.tsv']);
});

test('Lua sources parse', { skip: !lua && 'no Lua interpreter' }, () => {
  const luac = ['luac5.4', 'luac'].find(name => spawnSync(name, ['-v']).status === 0);
  if (!luac) return;
  execFileSync(luac, ['-p', ...['hyprland.lua', 'keyboard.lua', 'layouts.lua', 'monitors.lua', 'shell-bindings.lua', 'window-bindings.lua',
    'greeter/hyprland.lua'].map(file => path.join(provider, file))]);
});

test('session and greeter reload only the shared Virtual-1 monitor rule', { skip: !lua && 'no Lua interpreter' }, () => {
  const result = execFileSync(lua, ['-e', `
    local original_dofile = dofile
    package.preload['/usr/share/mirroros/hypr/layouts.lua'] = function() return 'us,es' end
    dofile = function(file)
      if file == '/usr/share/mirroros/hypr/monitors.lua' then
        return original_dofile(arg[1] .. '/monitors.lua')
      end
      assert(file == '/usr/share/mirroros/hypr/shell-bindings.lua'
        or file == '/usr/share/mirroros/hypr/window-bindings.lua', file)
    end
    hl = {
      config = function() end, bind = function() end, on = function() end,
      dsp = { exec_cmd = function() end },
      monitor = function(spec)
        local count = 0
        for _ in pairs(spec) do count = count + 1 end
        assert(count == 4)
        assert(spec.output == 'Virtual-1')
        assert(spec.mode == '1920x1080@60')
        assert(spec.position == 'auto')
        assert(spec.scale == 1.2)
        print(spec.output)
      end,
    }
    for _, file in ipairs({'hyprland.lua', 'greeter/hyprland.lua'}) do
      for reload = 1, 2 do original_dofile(arg[1] .. '/' .. file) end
    end
  `, '-', provider], { input: '', encoding: 'utf8' });
  assert.deepEqual(result.trim().split('\n'), Array(4).fill('Virtual-1'));
});

test('the session and greeter layout list starts with the resolved layout without duplicates', { skip: !lua && 'no Lua interpreter' }, () => {
  const order = resolved => execFileSync(lua, ['-e', `package.preload['/usr/share/mirroros/hypr/keyboard.lua'] = function() return '${resolved}' end
    package.path = ''
    package.preload['/usr/share/mirroros/hypr/layouts.lua'] = loadfile(arg[1])
    io.write((require('/usr/share/mirroros/hypr/layouts.lua')))`, '-', path.join(provider, 'layouts.lua')],
  { input: '', encoding: 'utf8' });
  assert.equal(order('es'), 'es,us');
  assert.equal(order('us'), 'us,es');
  assert.equal(order('de'), 'de,us,es');
  for (const file of ['hyprland.lua', 'greeter/hyprland.lua'])
    assert.match(fs.readFileSync(path.join(provider, file), 'utf8'), /kb_layout = require\("\/usr\/share\/mirroros\/hypr\/layouts\.lua"\)/);
  const greeter = fs.readFileSync(path.join(provider, 'greeter/hyprland.lua'), 'utf8');
  assert.match(greeter, /hl\.bind\("SUPER \+ I", hl\.dsp\.exec_cmd\(indicator \.\. " next"\)\)/);
  assert.match(greeter, /hl\.bind\("SUPER \+ SHIFT \+ I", hl\.dsp\.exec_cmd\(indicator \.\. " prev"\)\)/);
  assert.match(greeter, /hl\.on\("hyprland\.start", function\(\)\n    hl\.exec_cmd\(indicator \.\. " current"\)\nend\)/);
});
