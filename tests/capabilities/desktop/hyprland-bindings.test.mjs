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
  MirrorOSStageBindings = mode == "replacement" or mode == "replacement-invalid"
  dofile(arg[2] .. "/shell-bindings.lua")
  if mode == "duplicate" then MirrorOSKeys.bind("extra.duplicate", "SHIFT + SUPER + i", "Duplicate", "x") end
  dofile(arg[2] .. "/window-bindings.lua")
  if mode == "replacement" or mode == "replacement-invalid" then
    assert(#out == 0)
    if mode == "replacement" then
      assert(not pcall(MirrorOSKeys.replace, "window.close", "Invalid", "not-a-dispatcher"))
      MirrorOSKeys.replace("window.close", "Personal close action", hl.dsp.exec_cmd("personal-command"))
      assert(not pcall(MirrorOSKeys.replace, "window.close", "Again", "x"))
    else
      assert(not pcall(MirrorOSKeys.replace, "unknown.id", "Unknown", "x"))
    end
    MirrorOSKeys.finalize()
    MirrorOSKeys.export()
  end
  if mode == "personal" or mode == "personal-export" then
    MirrorOSKeys.bind("personal.example", "SUPER + F12", "Personal example", hl.dsp.exec_cmd("personal-command"))
    if mode == "personal-export" then MirrorOSKeys.export() end
  end
  if mode == "personal-error" or mode == "personal-error-export" then
    local ok = pcall(function()
      MirrorOSKeys.bind("personal.partial", "SUPER + F12", "Partial personal binding", hl.dsp.exec_cmd("personal-command"))
      error("synthetic failure after binding")
    end)
    assert(not ok)
    if mode == "personal-error-export" then MirrorOSKeys.export() end
  end
  if mode == "personal-duplicate" then MirrorOSKeys.bind("personal.duplicate", "SUPER + K", "Duplicate", "x") end
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
  assert.equal(bindings.length, 117);
  for (const file of ['shell-bindings.lua', 'window-bindings.lua', 'hyprland.lua', 'defaults.lua']) {
    const code = fs.readFileSync(path.join(provider, file), 'utf8').split('\n').filter(line => !/^\s*--/.test(line)).join('\n');
    assert.doesNotMatch(code, /unbind/, file);
    assert.doesNotMatch(code, /\brequire\s*\(\s*["'][^"']*bindings/, file);
  }
  assert.match(fs.readFileSync(path.join(provider, 'shell-bindings.lua'), 'utf8'), /^MirrorOSKeys = \{ entries = \{\}, chords = \{\}, pending = \{\}, staged = MirrorOSStageBindings == true \}$/m);
});

test('no chord is bound twice and the helper rejects a repeated chord', { skip: !lua && 'no Lua interpreter' }, () => {
  assert.equal(byChord.size, bindings.length);
  const duplicate = load('duplicate');
  assert.notEqual(duplicate.status, 0);
  assert.match(duplicate.stderr, /repeated chord SHIFT \+ SUPER \+ i/);
});

test('personal registry additions require a new export and reject product chords', { skip: !lua && 'no Lua interpreter' }, () => {
  const withoutExport = load('personal');
  assert.equal(withoutExport.status, 0, withoutExport.stderr);
  assert.match(withoutExport.stdout, /SUPER \+ F12\tPersonal example/);
  assert.doesNotMatch(withoutExport.registry, /personal\.example/);
  const withExport = load('personal-export');
  assert.equal(withExport.status, 0, withExport.stderr);
  assert.match(withExport.registry, /personal\.example\tSUPER \+ F12\tPersonal example/);
  const duplicate = load('personal-duplicate');
  assert.notEqual(duplicate.status, 0);
  assert.match(duplicate.stderr, /repeated chord SUPER \+ K/);
});

test('a personal error can leave a binding registered after the last export', { skip: !lua && 'no Lua interpreter' }, () => {
  const failed = load('personal-error');
  assert.equal(failed.status, 0, failed.stderr);
  assert.match(failed.stdout, /SUPER \+ F12\tPartial personal binding/);
  assert.doesNotMatch(failed.registry, /personal\.partial/);
  const exported = load('personal-error-export');
  assert.equal(exported.status, 0, exported.stderr);
  assert.match(exported.registry, /personal\.partial\tSUPER \+ F12\tPartial personal binding/);
});

test('staged replacements bind once and export the selected action', { skip: !lua && 'no Lua interpreter' }, () => {
  const replaced = load('replacement');
  assert.equal(replaced.status, 0, replaced.stderr);
  assert.match(replaced.stdout, /^SUPER \+ W\tPersonal close action\t\tpersonal-command$/m);
  assert.equal(replaced.stdout.trim().split('\n').length, 117);
  assert.match(replaced.registry, /^window\.close\tSUPER \+ W\tPersonal close action$/m);
  const invalid = load('replacement-invalid');
  assert.equal(invalid.status, 0, invalid.stderr);
  assert.match(invalid.registry, /^window\.close\tSUPER \+ W\tClose window$/m);
});

test('every approved Story 4.3 key is bound with a description', { skip: !lua && 'no Lua interpreter' }, () => {
  const required = [
    'SUPER+SPACE', 'SHIFT+SUPER+CODE:201', 'SUPER+D', 'ALT+SUPER+SPACE', 'SUPER+ESCAPE', 'XF86POWEROFF', 'SUPER+K', 'CTRL+SUPER+SPACE',
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
    'SUPER+SLASH', 'ALT+SUPER+SLASH', 'SHIFT+SUPER+TAB', 'CTRL+SUPER+TAB', 'SUPER+F1', 'SUPER+H',
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
    wallpaper: fs.readFileSync(path.join(shell, 'services/WallpaperActions.qml'), 'utf8'),
  };
  for (const action of ipc) {
    const match = action.match(/^qs ipc -p \/usr\/share\/mirroros\/shell call (menu|notifications|wallpaper) (\w+)(?: (\w+))?$/);
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
  assert.equal(rows.length, 111);
  for (const row of rows) assert.equal(row.length, 3);
  for (const hidden of ['mouse.move', 'mouse.resize', 'workspace.scroll-next', 'group.scroll-prev']) assert.ok(!ids.includes(hidden));
  assert.ok(ids.includes('help.keybindings') && ids.includes('terminal.open'));
  assert.deepEqual(loaded.leftovers, ['mirroros-keybindings.tsv']);
});

test('Lua sources parse', { skip: !lua && 'no Lua interpreter' }, () => {
  const luac = ['luac5.4', 'luac'].find(name => spawnSync(name, ['-v']).status === 0);
  if (!luac) return;
  execFileSync(luac, ['-p', ...['hyprland.lua', 'defaults.lua', 'personal-loader.lua', 'keyboard.lua', 'layouts.lua', 'monitors.lua', 'shell-bindings.lua', 'window-bindings.lua',
    'greeter/hyprland.lua'].map(file => path.join(provider, file))]);
});

test('session and greeter reload shared monitor rules and session sets GDK scale', { skip: !lua && 'no Lua interpreter' }, () => {
  const result = execFileSync(lua, ['-e', `
    local original_dofile = dofile
    package.preload['/usr/share/mirroros/hypr/layouts.lua'] = function() return 'us,es' end
    dofile = function(file)
      if file == '/usr/share/mirroros/hypr/monitors.lua' then
        return original_dofile(arg[1] .. '/monitors.lua')
      end
      if file == '/usr/share/mirroros/hypr/defaults.lua' then return original_dofile(arg[1] .. '/defaults.lua') end
      if file == '/usr/share/mirroros/hypr/personal-loader.lua' then return function() end end
      if file == '/usr/share/mirroros/hypr/theme-runtime.lua' then return function() return nil end end
      assert(file == '/usr/share/mirroros/hypr/shell-bindings.lua'
        or file == '/usr/share/mirroros/hypr/window-bindings.lua', file)
    end
    hl = {
      config = function() end, bind = function() end, on = function() end,
      env = function(key, value) assert(key == 'GDK_SCALE' and value == '1'); print('GDK_SCALE') end,
      dsp = { exec_cmd = function() end },
      monitor = function(spec)
        local count = 0
        for _ in pairs(spec) do count = count + 1 end
        assert(count == 4)
        assert(spec.position == 'auto')
        if spec.output == '' then
          assert(spec.mode == 'preferred' and spec.scale == 1)
          print('default')
        else
          assert(spec.output == 'Virtual-1' and spec.mode == '1920x1080@60' and spec.scale == 1.6)
          print(spec.output)
        end
      end,
    }
    for _, file in ipairs({'hyprland.lua', 'greeter/hyprland.lua'}) do
      for reload = 1, 2 do original_dofile(arg[1] .. '/' .. file) end
    end
  `, '-', provider], { input: '', encoding: 'utf8' });
  assert.deepEqual(result.trim().split('\n'), [
    'GDK_SCALE', 'default', 'Virtual-1', 'GDK_SCALE', 'default', 'Virtual-1',
    'default', 'Virtual-1', 'default', 'Virtual-1',
  ]);
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
  for (const file of ['defaults.lua', 'greeter/hyprland.lua'])
    assert.match(fs.readFileSync(path.join(provider, file), 'utf8'), /kb_layout = require\("\/usr\/share\/mirroros\/hypr\/layouts\.lua"\)/);
  const greeter = fs.readFileSync(path.join(provider, 'greeter/hyprland.lua'), 'utf8');
  assert.match(greeter, /hl\.bind\("SUPER \+ I", hl\.dsp\.exec_cmd\(indicator \.\. " next"\)\)/);
  assert.match(greeter, /hl\.bind\("SUPER \+ SHIFT \+ I", hl\.dsp\.exec_cmd\(indicator \.\. " prev"\)\)/);
  assert.match(greeter, /hl\.on\("hyprland\.start", function\(\)\n    hl\.exec_cmd\(indicator \.\. " current"\)\nend\)/);
});
