// Static contract and pure models of the bar additions of plan 02-31: the runtime-only Stay Awake indicator,
// the microphone indicator and the active window label.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const shell = new URL('../../../../capabilities/desktop/shell/', import.meta.url);
const read = file => readFileSync(new URL(file, shell), 'utf8');
const load = file => {
  const context = vm.createContext({});
  vm.runInContext(read(file).replace(/^\.pragma library\n/, ''), context);
  return context;
};
const MicrophoneModel = load('bar/widgets/MicrophoneModel.js');
const ActiveWindowModel = load('bar/widgets/ActiveWindowModel.js');
const microphone = read('bar/widgets/Microphone.qml');
const activeWindow = read('bar/widgets/ActiveWindow.qml');
const bar = read('bar/Bar.qml');
const defaults = JSON.parse(read('defaults.json'));
// Negative checks ignore comment lines, which name what an adaptation removed.
const code = text => text.split('\n').filter(line => !line.trim().startsWith('//')).join('\n');
const stayAwakeService = read('services/StayAwake.qml');
const stayAwakeIndicator = read('bar/indicators/StayAwake.qml');
const indicators = read('bar/widgets/Indicators.qml');
const shellQml = read('shell.qml');

test('the Stay Awake service is one native idle inhibitor with runtime-only state', () => {
  assert.match(stayAwakeService, /import Quickshell\.Wayland/);
  assert.match(stayAwakeService, /IdleInhibitor\s*\{/);
  assert.match(stayAwakeService, /property bool enabled: false/);
  assert.match(stayAwakeService, /enabled: root\.enabled && !!root\.window/);
  assert.match(stayAwakeService, /function toggle\(\)/);
  for (const forbidden of [/\bProcess\b/, /execDetached/, /\bFileView\b/, /setText/, /systemd-inhibit/, /hypridle\.conf/])
    assert.doesNotMatch(stayAwakeService, forbidden);
});

test('the Stay Awake indicator uses the shell service and starts no process', () => {
  assert.match(stayAwakeIndicator, /firstPartyServiceFor\("mirroros\.stay-awake"\)/);
  assert.match(stayAwakeIndicator, /stayAwakeService\.toggle\(\)/);
  assert.match(stayAwakeIndicator, /inactiveTooltipText: I18n\.t\("bar\.stayAwake"\)/);
  assert.match(stayAwakeIndicator, /activeTooltipText: "Allow Idle Lock"/);
  assert.doesNotMatch(stayAwakeIndicator, /\bProcess\b|execDetached|firstPartyServiceFor\("omarchy\.idle"\)/);
});

test('the indicators widget maps StayAwake and lists it after Dnd by default', () => {
  assert.match(indicators, /"StayAwake": stayAwakeIndicator/);
  assert.match(indicators, /Component \{ id: stayAwakeIndicator; StayAwake \{ \} \}/);
  assert.match(indicators, /defaultIndicatorEntries: \[ "Reminder", "Dnd", "StayAwake" \]/);
});

test('the shell resolves the Stay Awake service and binds it to a live bar window', () => {
  assert.match(shellQml, /if \(id === "mirroros\.stay-awake"\) return stayAwakeService/);
  assert.match(shellQml, /return id === "omarchy\.notifications" \? notificationService : null/);
  assert.match(shellQml, /property StayAwake stayAwakeService: StayAwake \{\s*window: desktopShell\.bar \? desktopShell\.bar\.liveWindow : null/);
  assert.match(bar, /readonly property var liveWindow:/);
});

const capture = (name, muted = false) => ({ name, isStream: true, isSink: false, audio: { muted } });

test('only non-muted capture streams other than the shell meters count as microphone use', () => {
  assert.equal(MicrophoneModel.isShellLevelMeter('quickshell'), true);
  assert.equal(MicrophoneModel.isShellLevelMeter('quickshell-peak-monitor'), true);
  for (const name of ['quickshell2', 'Quickshell', 'pw-record', '', undefined])
    assert.equal(MicrophoneModel.isShellLevelMeter(name), false, String(name));
  const table = [
    [[], false],
    [null, false],
    [[capture('quickshell'), capture('quickshell-peak-monitor')], false],
    [[capture('pw-record')], true],
    [[capture('pw-record', true)], false],
    [[{ name: 'pw-record', isStream: true, isSink: false, audio: null }], true],
    [[{ name: 'firefox', isStream: true, isSink: true, audio: { muted: false } }], false],
    [[{ name: 'firefox', isStream: true, audio: { muted: false } }], false],
    [[{ name: 'alsa_input.mic', isStream: false, isSink: false, audio: { muted: false } }], false],
    [[null, capture('quickshell'), capture('zoom')], true],
  ];
  for (const [nodes, expected] of table)
    assert.equal(MicrophoneModel.inUse(nodes), expected, JSON.stringify(nodes));
});

test('the microphone indicator is visible only with a controllable source in use or muted', () => {
  // [hasSource, hasAudio, muted, inUse] -> visible
  const table = [
    [true, true, false, false, false],
    [true, true, false, true, true],
    [true, true, true, false, true],
    [true, true, true, true, true],
    [false, false, true, false, false],
    [false, true, true, true, false],
    [true, false, true, true, false],
  ];
  for (const [hasSource, hasAudio, muted, inUse, expected] of table)
    assert.equal(MicrophoneModel.visible(hasSource, hasAudio, muted, inUse), expected,
      JSON.stringify({ hasSource, hasAudio, muted, inUse }));
});

test('the active window label names the application before the title', () => {
  const table = [
    [['Foot', 'vim notes.md', 'foot'], 'Foot \u00b7 vim notes.md'],
    [['Files', '', 'org.gnome.Nautilus'], 'Files'],
    [['Files', 'Files', 'org.gnome.Nautilus'], 'Files'],
    [['Foot', 'foot', 'foot'], 'Foot'],
    [['Files', 'FILES', 'org.gnome.Nautilus'], 'Files'],
    [['Files', null, 'org.gnome.Nautilus'], 'Files'],
    [['', 'scratch', 'custom.app'], 'custom.app \u00b7 scratch'],
    [['', '', 'custom.app'], 'custom.app'],
    [['', 'Untitled', ''], 'Untitled'],
    [['', '', ''], ''],
    [[undefined, undefined, undefined], ''],
  ];
  for (const [args, expected] of table)
    assert.equal(ActiveWindowModel.label(...args), expected, JSON.stringify(args));
});

test('the bar maps both widgets and the defaults place them', () => {
  assert.match(bar, /"omarchy\.microphone": microphoneComponent/);
  assert.match(bar, /"omarchy\.active-window": activeWindowComponent/);
  assert.match(bar, /Component \{ id: microphoneComponent; Widgets\.Microphone \{ \} \}/);
  assert.match(bar, /Component \{ id: activeWindowComponent; Widgets\.ActiveWindow \{ \} \}/);
  const ids = region => defaults.bar.layout[region].map(entry => entry.id);
  assert.deepEqual(ids('left'), ['omarchy.menu', 'omarchy.workspaces', 'omarchy.active-window']);
  const right = ids('right');
  assert.equal(right.indexOf('omarchy.microphone'), right.indexOf('omarchy.audio') - 1);
  assert.equal(right.filter(id => id === 'omarchy.microphone').length, 1);
});

test('the microphone indicator is native PipeWire and opens the audio panel through the bar', () => {
  assert.match(microphone, /moduleName: "omarchy\.microphone"/);
  assert.match(microphone, /Pipewire\.defaultAudioSource/);
  assert.match(microphone, /PwObjectTracker/);
  assert.match(microphone, /requestPanel\("omarchy\.audio", "toggle"\)/);
  assert.match(microphone, /MicrophoneModel\.visible\(/);
  assert.match(microphone, /implicitWidth: visible \? button\.implicitWidth : 0/);
  assert.match(microphone, /Math\.max\(0, Math\.min\(1, root\.volume \+ \(delta > 0 \? step : -step\)\)\)/);
  for (const forbidden of [/UntypedInput/, /AudioNodes/, /\bProcess\b/, /omarchy-shell/, /\.run\(/, /wpctl/])
    assert.doesNotMatch(code(microphone), forbidden);
});

test('the active window label focuses on left click and can never close a window', () => {
  assert.match(activeWindow, /moduleName: "omarchy\.active-window"/);
  assert.match(activeWindow, /DesktopEntries\.heuristicLookup\(appId\)/);
  assert.match(activeWindow, /ActiveWindowModel\.label\(/);
  assert.match(activeWindow, /textFormat: Text\.PlainText/);
  assert.match(activeWindow, /setting\("maxWidth", 280\)/);
  assert.match(activeWindow, /acceptedButtons: Qt\.LeftButton\n/);
  assert.match(activeWindow, /root\.toplevel\.activate\(\)/);
  assert.match(activeWindow, /showTooltip\(root, root\.title\)/);
  assert.match(activeWindow, /readonly property bool tooltipHovered: visible && mouseArea\.containsMouse/);
  assert.match(activeWindow, /id: mouseArea\n/);
  assert.match(activeWindow, /Math\.min\(maxLabelWidth, Math\.ceil\(labelMetrics\.advanceWidth\)\)/);
  assert.doesNotMatch(activeWindow, /labelText\.implicitWidth/);
  assert.doesNotMatch(code(activeWindow), /close\(\)|\bProcess\b|MiddleButton|RightButton/);
});
