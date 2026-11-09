// Power panel: the adapted v4.5.0 model and the MirrorOS adaptation points in Power.qml.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const shell = new URL('../../../../capabilities/desktop/shell/', import.meta.url);
const module = { exports: {} };
vm.runInNewContext(readFileSync(new URL('panels/power/Model.js', shell), 'utf8'), { module });
const Model = module.exports;
const power = readFileSync(new URL('bar/widgets/Power.qml', shell), 'utf8');

function body(name) {
  const match = power.match(new RegExp(`  function ${name}\\([^)]*\\) \\{([\\s\\S]*?)\\n  \\}`));
  assert.ok(match, `${name} must remain testable`);
  return match[1];
}

function fn(name, params, context) {
  return vm.runInNewContext(`(function(${params}) {${body(name)}})`, context);
}

const states = { Charging: 1, Discharging: 2, FullyCharged: 4, PendingCharge: 5 };

test('battery-status key-value output gains the upstream units and a formatted time', () => {
  const raw = 'percentage\t87\nstate\tdischarging\nrate\t7.4\nsize\t57\ncycles\t112\nthreshold\t75-80\ntime\t135\n';
  const info = Model.withUnits(Model.parseKeyValue(raw));
  assert.deepEqual({ ...info }, { percentage: '87%', state: 'discharging', rate: '7.4W', size: '57Wh', cycles: '112',
    threshold: '75-80%', time: '2h 15m' });
  assert.equal(Model.localizeReading(info.rate), '7.4W');
});

test('holding state and a single threshold are kept; missing keys stay missing', () => {
  const info = Model.withUnits(Model.parseKeyValue('percentage\t95\nstate\tholding\nrate\t0\nthreshold\t95\n'));
  assert.equal(info.state, 'holding');
  assert.equal(info.threshold, '95%');
  assert.equal(info.time, undefined);
  assert.equal(info.cycles, undefined);
  assert.deepEqual({ ...Model.withUnits(Model.parseKeyValue('')) }, {});
});

test('durations follow the v4.5.0 English battery.duration forms', () => {
  assert.equal(Model.formatDuration('45'), '45m');
  assert.equal(Model.formatDuration('120'), '2h');
  assert.equal(Model.formatDuration('61'), '1h 1m');
  for (const empty of ['', '0', '-3', 'x', undefined, null]) assert.equal(Model.formatDuration(empty), '', String(empty));
});

test('charge threshold detection marks holding on AC below full', () => {
  const device = { isPresent: true, percentage: 0.8, state: states.PendingCharge };
  assert.equal(Model.chargeThresholdActive(device, false, states), true);
  assert.equal(Model.chargeThresholdActive(device, true, states), false);
  assert.equal(Model.chargeThresholdActive({ ...device, state: states.FullyCharged, percentage: 1 }, false, states), false);
  assert.equal(Model.modeLabel({ ...device, state: states.FullyCharged }, false, states), 'Threshold');
});

test('profile labels and keyboard selection over the native profile list', () => {
  const profiles = ['power-saver', 'balanced', 'performance'];
  assert.deepEqual(profiles.map(p => Model.profileLabel(p)), ['Power-saver', 'Balanced', 'Performance']);
  assert.equal(Model.selectProfileIndex(0, -1, profiles), 0);
  assert.equal(Model.selectProfileIndex(1, 1, profiles), 2);
  assert.equal(Model.selectProfileIndex(2, 1, profiles), 2);
  assert.match(power, /if \(PowerProfiles\.hasPerformanceProfile\) list\.push\("performance"\)/);
});

test('a profile is written per power source through power-profile and repeats are ignored while pending', () => {
  const proc = { running: false, command: null };
  const root = { powerProfileCommand: '/usr/share/mirroros/hardware/power-profile', discharging: true, pendingProfile: '' };
  const context = { root, actionProc: proc, pendingProfile: '' };
  Object.defineProperty(context, 'pendingProfile', { get: () => root.pendingProfile, set: v => { root.pendingProfile = v } });
  Object.defineProperty(context, 'powerProfileCommand', { get: () => root.powerProfileCommand });
  const setProfile = fn('setProfile', 'profile', context);
  setProfile('power-saver');
  assert.deepEqual([...proc.command], ['/usr/share/mirroros/hardware/power-profile', 'set', 'battery', 'power-saver']);
  assert.equal(root.pendingProfile, 'power-saver');
  setProfile('performance');
  assert.deepEqual([...proc.command], ['/usr/share/mirroros/hardware/power-profile', 'set', 'battery', 'power-saver']);
  root.pendingProfile = '';
  proc.running = false;
  root.discharging = false;
  setProfile('balanced');
  assert.deepEqual([...proc.command], ['/usr/share/mirroros/hardware/power-profile', 'set', 'ac', 'balanced']);
});

test('both bar buttons toggle the power panel without changing the percentage setting', () => {
  const match = power.match(/onPressed: function\(b\) \{([\s\S]*?)\n    \}/);
  assert.ok(match);
  const root = {
    unavailable: false, inventoryUnknown: false, batteryPresent: true, opened: false,
    showPercentage: false,
    toggle() { this.opened = !this.opened },
    togglePercentage() { this.showPercentage = !this.showPercentage },
  };
  const Qt = { LeftButton: 1, RightButton: 2 };
  const press = vm.runInNewContext(`(function(b) {${match[1]}})`, { root, Qt });
  for (const button of [Qt.LeftButton, Qt.RightButton]) {
    press(button);
    assert.equal(root.opened, true);
    press(button);
    assert.equal(root.opened, false);
    assert.equal(root.showPercentage, false);
    for (const [key, value] of [['unavailable', true], ['inventoryUnknown', true], ['batteryPresent', false]]) {
      const previous = root[key];
      root[key] = value;
      press(button);
      assert.equal(root.opened, false, key);
      root[key] = previous;
    }
  }
});

test('battery details come from battery-status; no system statistics or Omarchy helpers remain', () => {
  assert.match(power, /batteryStatusCommand: "\/usr\/share\/mirroros\/hardware\/battery-status"/);
  const code = power.replace(/^\s*\/\/.*$/gm, '');
  for (const absent of [/omarchy-/, /system-stats/, /systemProc/, /ShellIpc/, /manageIpc: true/])
    assert.doesNotMatch(code, absent);
  assert.match(body('refresh'), /batteryProc/);
});
