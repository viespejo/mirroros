// Bluetooth panel: the adapted v4.5.0 model and the MirrorOS single-action and failure rules.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
const modelSource = readFileSync(path.join(repo, 'capabilities/desktop/shell/panels/bluetooth/Model.js'), 'utf8');
const module = { exports: {} };
vm.runInNewContext(modelSource, { module });
const Model = module.exports;
const plain = value => JSON.parse(JSON.stringify(value));
// Bluetooth.qml without comment lines, so rationale text never satisfies or trips a check.
const panel = readFileSync(path.join(repo, 'capabilities/desktop/shell/bar/widgets/Bluetooth.qml'), 'utf8')
  .split('\n').filter(line => !line.trim().startsWith('//')).join('\n');

// Documentation-range addresses only; names are placeholders.
const A = '00:11:22:33:44:01';
const B = '00:11:22:33:44:02';
const device = fields => ({ address: A, name: '', deviceName: '', connected: false, paired: false,
  bonded: false, trusted: false, ...fields });

test('name filters drop UUID-like and address-like labels', () => {
  assert.equal(Model.hasHumanName(device({ name: 'Headset' })), true);
  assert.equal(Model.hasHumanName(device({ name: A })), false);
  assert.equal(Model.hasHumanName(device({ name: '0000110b-0000-1000-8000-00805f9b34fb' })), false);
  assert.equal(Model.hasHumanName(device({ name: '0x1234' })), false);
  assert.equal(Model.hasHumanName(device({ name: '  ' })), false);
  assert.equal(Model.deviceLabel(device({ name: 'Alias', deviceName: 'Headset' })), 'Headset');
});

test('deviceRow projects primitives only (upstream segfault guard)', () => {
  const row = Model.deviceRow(device({ name: 'Headset', connected: 1, battery: 80, batteryAvailable: true,
    extra: { live: true } }));
  assert.deepEqual(plain(row), { address: A, name: 'Headset', deviceName: '', connected: true, state: -1,
    batteryAvailable: true, battery: 80, pairing: false });
  for (const value of Object.values(row)) assert.notEqual(typeof value, 'object');
  assert.equal(Model.deviceRow(null), null);
});

test('deviceLists files connected, paired and available devices sorted by label', () => {
  const lists = Model.deviceLists([
    device({ address: A, name: 'Zeta', connected: true, paired: true }),
    device({ address: B, name: 'Beta', paired: true }),
    device({ address: '00:11:22:33:44:03', name: 'Alpha', bonded: true }),
    device({ address: '00:11:22:33:44:04', name: 'Speaker' }),
    device({ address: '00:11:22:33:44:05', name: '00:11:22:33:44:05' }),
  ]);
  assert.deepEqual(plain(lists.connected.map(Model.deviceLabel)), ['Zeta']);
  assert.deepEqual(plain(lists.known.map(Model.deviceLabel)), ['Alpha', 'Beta']);
  assert.deepEqual(plain(lists.discovered.map(Model.deviceLabel)), ['Speaker']);
});

test('a trusted but unpaired device is filed as paired, so the command must never trust after a failed pair', () => {
  // Kept upstream rule: trusted alone moves a device out of "available". Omarchy's helper trusts after a
  // failed pair, which shows an unpaired device as paired; bluetooth-device stops at the failed pair (DEC-067).
  const lists = Model.deviceLists([device({ name: 'Phone', trusted: true })]);
  assert.deepEqual(plain(lists.known.map(Model.deviceLabel)), ['Phone']);
  assert.equal(lists.discovered.length, 0);
  const untrusted = Model.deviceLists([device({ name: 'Phone' })]);
  assert.deepEqual(plain(untrusted.discovered.map(Model.deviceLabel)), ['Phone']);
});

test('available devices are shown only while discovering', () => {
  const lists = Model.deviceLists([device({ name: 'Speaker' }), device({ address: B, name: 'Mouse', paired: true })]);
  assert.deepEqual(plain(Model.visibleSections(lists, false)), ['known']);
  assert.deepEqual(plain(Model.visibleSections(lists, true)), ['known', 'discovered']);
  assert.deepEqual(plain(Model.sectionDevices(lists, 'discovered').map(Model.deviceLabel)), ['Speaker']);
  assert.deepEqual(plain(Model.sectionDevices(lists, 'other')), []);
});

test('bluetoothSinkMatchesDevice matches the device address or label on a sink node', () => {
  const sink = props => ({ isSink: true, isStream: false, ready: true, name: '', description: '', properties: props });
  const headset = device({ name: 'Headset' });
  assert.equal(Model.bluetoothSinkMatchesDevice(sink({ 'node.name': 'bluez_output.00_11_22_33_44_01.1' }), headset), true);
  assert.equal(Model.bluetoothSinkMatchesDevice(sink({ 'device.description': 'Headset' }), headset), true);
  assert.equal(Model.bluetoothSinkMatchesDevice(sink({ 'node.name': 'alsa_output.pci' }), headset), false);
  assert.equal(Model.bluetoothSinkMatchesDevice({ ...sink({ 'device.description': 'Headset' }), isStream: true }, headset),
    false);
});

test('one action runs at a time: repeats and other rows are ignored (DEC-072)', () => {
  const current = Model.startAction(null, A, 'pair');
  assert.deepEqual(plain(current), { address: A, action: 'pair' });
  assert.equal(Model.startAction(current, A, 'pair'), null);
  assert.equal(Model.startAction(current, B, 'connect'), null);
  assert.equal(Model.startAction(null, '', 'connect'), null);
  assert.equal(Model.startAction(null, A, ''), null);
  assert.equal(Model.pendingAction(current, A), 'pair');
  assert.equal(Model.pendingAction(current, B), '');
  assert.equal(Model.pendingAction(null, A), '');
  assert.equal(Model.actionBlocked(current, A), false);
  assert.equal(Model.actionBlocked(current, B), true);
  assert.equal(Model.actionBlocked(null, B), false);
});

test('a failed pair points at Advanced…; other actions get a generic literal (DEC-070, DEC-072)', () => {
  assert.equal(Model.failureLiteral('pair'), 'Pairing failed. Devices that need a code: use Advanced…');
  assert.equal(Model.failureLiteral('connect'), 'Connect failed');
  assert.equal(Model.failureLiteral('disconnect'), 'Disconnect failed');
  assert.equal(Model.failureLiteral('forget'), 'Forget failed');
  assert.equal(Model.failureLiteral('rename'), 'Action failed');
  assert.equal(Model.failureLiteral('pair', key => `[${key}]`), '[bluetooth.pairFailed]');
});

test('bluetooth-device exit codes map to row results', () => {
  assert.deepEqual(plain(Model.actionResult('pair', 0)), { ok: true, failure: '' });
  assert.equal(Model.actionResult('pair', 4).failure, 'Pairing failed. Devices that need a code: use Advanced…');
  // Pairing succeeded; a later step failed, so the row must not send the user to Advanced….
  assert.equal(Model.actionResult('pair', 5).failure, 'Trust failed');
  assert.equal(Model.actionResult('pair', 6).failure, 'Connect failed');
  assert.equal(Model.actionResult('connect', 3).failure, 'Could not turn Bluetooth on');
  assert.equal(Model.actionResult('connect', 6).failure, 'Connect failed');
  assert.equal(Model.actionResult('disconnect', 7).failure, 'Disconnect failed');
  assert.equal(Model.actionResult('forget', 8).failure, 'Forget failed');
  assert.equal(Model.actionResult('forget', 2).failure, 'Forget failed');
  assert.equal(Model.actionResult('pair', 2).ok, false);
});

test('radio switch failures name the requested direction', () => {
  assert.equal(Model.powerFailureLiteral(true), 'Could not turn Bluetooth on');
  assert.equal(Model.powerFailureLiteral(false), 'Could not turn Bluetooth off');
});

test('the parallel pending-action map is gone', () => {
  assert.equal(Model.withPendingAction, undefined);
  assert.equal(Model.cloneMap, undefined);
});

test('the panel never writes adapter visibility (DEC-071)', () => {
  assert.doesNotMatch(panel, /\b(pairable|pairableTimeout|discoverable|discoverableTimeout)\b/);
  // Discovery is the only adapter write: start while open, stop after close.
  const writes = [...panel.matchAll(/adapter\.(\w+)\s*=[^=]/g)].map(match => match[1]);
  assert.deepEqual([...new Set(writes)], ['discovering']);
});

test('device and radio actions run only the owned commands through a Process (DEC-068, DEC-072)', () => {
  assert.match(panel, /"\/usr\/share\/mirroros\/hardware\/bluetooth-device"/);
  assert.match(panel, /"\/usr\/share\/mirroros\/hardware\/bluetooth-power"/);
  assert.match(panel, /deviceProc\.command = \[deviceTool, action, device\.address\]/);
  assert.match(panel, /powerProc\.command = \[powerTool, powerTarget \? "on" : "off"\]/);
  assert.match(panel, /audioDefaultProc\.command = \[audioDevice, "default", "output", String\(sink\.name\)\]/);
  // One execDetached remains: the Advanced terminal.
  assert.equal([...panel.matchAll(/execDetached\(/g)].length, 1);
  assert.doesNotMatch(panel, /\.disconnect\(\)|pendingTimeout|pendingActions|withPendingAction/);
  assert.doesNotMatch(panel, /\bsudo\b|\bpkexec\b|omarchy-|ShellIpc|IpcHandler|summon\(/);
  assert.doesNotMatch(panel, /\btoggle\b"/);
});

test('Advanced opens bluetoothctl with a KeyboardDisplay agent and closes the panel (DEC-070)', () => {
  assert.match(panel,
    /execDetached\(\["uwsm", "app", "--", "foot", "-e", "bluetoothctl", "--agent", "KeyboardDisplay"\]\)\s*close\(\)/);
  assert.match(panel, /text: "Advanced\u2026"/);
  assert.match(panel, /focusSection === "advanced"\) \{\s*openAdvanced\(\)/);
});

test('the panel has no agent and never requests or shows a code', () => {
  assert.doesNotMatch(panel, /\bAgent\s*\{|registerAgent|passkey|pincode|RequestConfirmation|RequestPinCode/i);
  assert.doesNotMatch(panel, /import Quickshell\.Bluetooth/);
});

test('any mouse button on the icon toggles the panel; no right-click radio action (DEC-073)', () => {
  assert.match(panel, /BarIconButton \{[\s\S]*?onPressed: function\(b\) \{ root\.toggle\(\) \}/);
  assert.doesNotMatch(panel, /RightButton\) root\.toggleBluetooth/);
});

test('the unavailable state shows the same reason in the bar and the panel (AC-9)', () => {
  assert.match(panel, /tooltipText: root\.bluezAvailable \? "" : root\.unavailableReason/);
  assert.match(panel, /visible: !root\.bluezAvailable\s*text: root\.unavailableReason/);
  assert.match(panel, /visible: unavailable \|\| !providers \|\| !providers\.ready \|\| adapter !== null/);
});
