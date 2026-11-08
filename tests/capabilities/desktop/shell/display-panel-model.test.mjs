// Display panel: the adapted v4.5.0 model and the MirrorOS adaptation points in Monitor.qml.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const shell = new URL('../../../../capabilities/desktop/shell/', import.meta.url);
const module = { exports: {} };
vm.runInNewContext(readFileSync(new URL('panels/display/Model.js', shell), 'utf8'), { module });
const Model = module.exports;
const monitor = readFileSync(new URL('bar/widgets/Monitor.qml', shell), 'utf8');

function body(name) {
  const match = monitor.match(new RegExp(`  function ${name}\\([^)]*\\) \\{([\\s\\S]*?)\\n  \\}`));
  assert.ok(match, `${name} must remain testable`);
  return match[1];
}

function fn(name, params, context) {
  return vm.runInNewContext(`(function(${params}) {${body(name)}})`, context);
}

const output = (name, extra = {}) => ({ name, enabled: true, focused: false, width: 1920, height: 1200, scale: 1,
  internal: /^eDP-/.test(name), mirror: null, ...extra });

test('state with the internal panel focused offers its backlight and scale', () => {
  const state = Model.parseState(JSON.stringify({ focused: 'eDP-1', internal: 'eDP-1', external: 'DP-1', backlight: 42,
    outputs: [output('eDP-1', { focused: true, scale: 1.6 }), output('DP-1', { enabled: false, width: 2560, height: 1440 })] }));
  assert.equal(state.brightnessAvailable, true);
  assert.equal(state.brightnessPercent, 42);
  assert.equal(state.focusedMonitor, 'eDP-1');
  assert.equal(state.internalMonitor, 'eDP-1');
  assert.equal(state.externalMonitor, 'DP-1');
  assert.equal(state.monitorScale, '1.6');
  assert.equal(state.displays.length, 2);
  assert.equal(state.enabledDisplayCount, 1);
});

test('an external focused display shows fixed brightness; no backlight is never fabricated', () => {
  const outputs = [output('eDP-1'), output('DP-1', { focused: true })];
  const external = Model.parseState(JSON.stringify({ focused: 'DP-1', internal: 'eDP-1', external: 'DP-1', backlight: 80, outputs }));
  assert.equal(external.brightnessAvailable, false);
  assert.equal(external.brightnessPercent, 0);
  const guest = Model.parseState(JSON.stringify({ focused: 'Virtual-1', internal: null, external: 'Virtual-1', backlight: null,
    outputs: [output('Virtual-1', { focused: true })] }));
  assert.equal(guest.brightnessAvailable, false);
  assert.equal(guest.internalMonitor, '');
});

test('invalid or empty state yields no displays and no brightness', () => {
  for (const raw of ['', 'not json', '[]', 'null', JSON.stringify({ outputs: [{ enabled: true }] })]) {
    const state = Model.parseState(raw);
    assert.equal(state.displays.length, 0, raw);
    assert.equal(state.brightnessAvailable, false, raw);
    assert.equal(state.focusedMonitor, '', raw);
  }
});

test('scale presets are filtered to distinct clean scales of the focused mode', () => {
  const presets = ['1', '1.25', '1.6', '2', '3', '4'];
  assert.deepEqual([...Model.availableScales(presets, 2880, 1920)], ['1', '1.25', '1.6', '2', '3', '4']);
  assert.equal(Model.cleanScale('1.6', 2560, 1600), '1.6');
  assert.equal(Model.cleanScale('1.25', 1920, 1080), '1.25');
  const unique = Model.availableScales(presets, 1366, 768);
  assert.equal(new Set(unique.map(s => Model.cleanScale(s, 1366, 768))).size, unique.length);
});

test('the last independent enabled output cannot be disabled; only mirrors of the target count', () => {
  const single = [output('eDP-1')];
  assert.equal(Model.canToggle(single[0], single), false);
  const mirrored = [output('eDP-1'), output('DP-1', { mirror: 'eDP-1' })];
  assert.equal(Model.independentEnabledCount(mirrored), 1);
  assert.equal(Model.canToggle(mirrored[0], mirrored), true);
  assert.equal(Model.canToggle(mirrored[1], mirrored), true);
  const chained = [output('eDP-1'), output('DP-1', { enabled: false }), output('DP-2', { mirror: 'DP-1' })];
  assert.equal(Model.canToggle(chained[0], chained), false);
  const two = [output('eDP-1'), output('DP-1')];
  assert.equal(Model.canToggle(two[0], two), true);
  const disabled = [output('eDP-1'), output('DP-1', { enabled: false })];
  assert.equal(Model.canToggle(disabled[1], disabled), true);
  assert.equal(Model.canToggle(null, two), false);
});

test('panel actions call the owned commands and ignore repeats while pending', () => {
  const displays = [output('eDP-1', { focused: true }), output('DP-1')];
  const proc = { running: false, command: null };
  const root = { displayCommand: '/usr/share/mirroros/hardware/display', pendingOutput: '', pendingScale: '', displays,
    canToggle: d => Model.canToggle(d, displays), effectiveScale: s => Model.cleanScale(s, 1920, 1200) };
  const context = { root, actionProc: proc, displays };
  Object.assign(context, root);
  const toggle = fn('toggleDisplay', 'name, enabled', context);
  toggle('DP-1', true);
  assert.deepEqual([...proc.command], ['/usr/share/mirroros/hardware/display', 'output', 'DP-1', 'off']);
  assert.equal(root.pendingOutput, 'DP-1');
  proc.running = true;
  toggle('eDP-1', true);
  assert.deepEqual([...proc.command], ['/usr/share/mirroros/hardware/display', 'output', 'DP-1', 'off']);
  proc.running = false;
  const scale = fn('setScale', 'scale', context);
  scale('1.6');
  assert.deepEqual([...proc.command], ['/usr/share/mirroros/hardware/display', 'scale', '1.6']);
  assert.equal(root.pendingScale, '1.6');
});

test('the mirror toggle is offered only with an internal and an enabled external output (ADR 0027)', () => {
  // Copy out of the vm realm so strict deep equality compares values only.
  const mirror = (displays, name) => ({ ...Model.mirrorState(displays, name) });
  const internal = output('eDP-1', { focused: true });
  assert.deepEqual(mirror([internal, output('HDMI-A-1')], 'eDP-1'), { available: true, active: false });
  assert.deepEqual(mirror([internal, output('HDMI-A-1', { mirror: 'eDP-1' })], 'eDP-1'), { available: true, active: true });
  assert.deepEqual(mirror([internal, output('HDMI-A-1', { mirror: 'DP-2' })], 'eDP-1'), { available: true, active: false });
  for (const [displays, name] of [[[internal], 'eDP-1'], [[internal, output('HDMI-A-1', { enabled: false })], 'eDP-1'],
    [[output('DP-1'), output('HDMI-A-1')], ''], [[output('HDMI-A-1')], 'eDP-1'], [null, 'eDP-1'], [[internal, output('DP-1')], null]])
    assert.deepEqual(mirror(displays, name), { available: false, active: false });
});

test('the mirror row runs the owned display mirror and ignores repeats while an action is pending', () => {
  const proc = { running: false, command: null };
  const root = { displayCommand: '/usr/share/mirroros/hardware/display', pendingMirror: false, mirrorInfo: { available: true, active: false } };
  const toggle = fn('toggleMirror', '', { root, actionProc: proc });
  toggle();
  assert.deepEqual([...proc.command], ['/usr/share/mirroros/hardware/display', 'mirror']);
  assert.equal(root.pendingMirror, true);
  proc.running = true;
  proc.command = null;
  toggle();
  assert.equal(proc.command, null);
  proc.running = false;
  root.pendingMirror = false;
  root.mirrorInfo = { available: false, active: false };
  toggle();
  assert.equal(proc.command, null);
  assert.equal(root.pendingMirror, false);
  assert.match(monitor, /root\.pendingMirror = false\n\s+root\.refresh\(\)/);
});

test('brightness uses the owned command without OSD; no Omarchy helpers or text size remain', () => {
  assert.match(body('setBrightness'), /\[root\.brightnessCommand, "--no-osd", percent \+ "%"\]/);
  assert.match(monitor, /brightnessCommand: "\/usr\/share\/mirroros\/hardware\/brightness"/);
  for (const absent of [/omarchy-/, /ShellIpc/, /textSize/i, /--monitor/, /hyprctl/, /manageIpc: true/])
    assert.doesNotMatch(monitor.replace(/^\s*\/\/.*$/gm, ''), absent);
});
