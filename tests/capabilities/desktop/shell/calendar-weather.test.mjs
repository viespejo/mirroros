// Static contract of the clock calendar panel (plan 02-32, ADR 0029): the unchanged
// v4.5.0 panel files, the adapted bar clock and the native `clock` IPC target, plus
// the calendar's opt-in settings stored per widget id.
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import vm from 'node:vm';

const shell = new URL('../../../../capabilities/desktop/shell/', import.meta.url);
const read = file => readFileSync(new URL(file, shell), 'utf8');
// Negative checks ignore comment lines, which name what an adaptation removed.
const code = text => text.split('\n').filter(line => !line.trim().startsWith('//')).join('\n');
const require = createRequire(import.meta.url);
const Preferences = require('../../../../capabilities/desktop/shell/services/ShellPreferences.js');
const barModel = vm.createContext({});
vm.runInContext(read('bar/BarModel.js'), barModel);

const clock = read('bar/widgets/Clock.qml');
const calendarPanel = read('panels/clock/Panel.qml');
const bar = read('bar/Bar.qml');
const defaults = JSON.parse(read('defaults.json'));

test('the calendar files and the bar clock run no process and call no omarchy-* command', () => {
  const files = readdirSync(new URL('panels/clock/', shell)).map(name => `panels/clock/${name}`);
  assert.deepEqual(files.sort(), ['panels/clock/Model.js', 'panels/clock/Panel.qml', 'panels/clock/WallClock.qml']);
  for (const file of [...files, 'bar/widgets/Clock.qml']) {
    const text = code(read(file));
    assert.doesNotMatch(text, /\bProcess\b/, file);
    assert.doesNotMatch(text, /execDetached/, file);
    assert.doesNotMatch(text, /omarchy-/, file);
  }
});

test('the bar clock hosts the unchanged calendar panel and replaces the old model subset', () => {
  assert.match(clock, /^import "\.\.\/\.\.\/panels\/clock\/Model\.js" as Model$/m);
  assert.match(clock, /source: Qt\.resolvedUrl\("\.\.\/\.\.\/panels\/clock\/Panel\.qml"\)/);
  assert.match(clock, /Calendar\.WallClock \{/);
  assert.doesNotMatch(code(clock), /\bSystemClock\b/);
  assert.doesNotMatch(code(clock), /ShellIpc/);
  for (const name of ['bar', 'settings', 'moduleName', 'anchorItem', 'hostWidget'])
    assert.match(clock, new RegExp(`if \\("${name}" in target\\) target\\.${name} = `), name);
  for (const fn of ['open', 'close', 'togglePanel', 'closeForPopoutSwitch'])
    assert.match(clock, new RegExp(`function ${fn}\\(\\)`), fn);
  assert.match(clock, /readonly property bool opened: /);
  assert.equal(existsSync(new URL('bar/ClockModel.js', shell)), false);
});

test('left click toggles the calendar, right click cycles the format, middle click does nothing', () => {
  const pressed = code(clock).match(/onPressed: function\(b\) \{([\s\S]*?)\n    \}/);
  assert.ok(pressed, 'the clock button keeps one press handler');
  assert.match(pressed[1], /b === Qt\.RightButton\) root\.cycleFormat\(\)/);
  assert.match(pressed[1], /b === Qt\.LeftButton\) root\.togglePanel\(\)/);
  assert.doesNotMatch(pressed[1], /MiddleButton/);
  assert.doesNotMatch(code(clock), /\.run\(/);
});

test('the bar declares the native clock IPC target with open, close and toggle only', () => {
  const handler = bar.match(/IpcHandler \{\n    target: "clock"\n([\s\S]*?)\n  \}/);
  assert.ok(handler, 'clock IpcHandler');
  const functions = [...handler[1].matchAll(/function (\w+)\(\): string \{ return root\.requestPanel\("omarchy\.clock", "(\w+)"\) \}/g)];
  assert.deepEqual(functions.map(match => [match[1], match[2]]),
    [['open', 'open'], ['close', 'close'], ['toggle', 'toggle']]);
  assert.match(bar, /"omarchy\.clock": clockComponent/);
});

test('calendar settings persist sparsely under bar.widgets["omarchy.clock"]', () => {
  const body = calendarPanel.match(/  function persistSettings\(values\) \{([\s\S]*?)\n  \}/);
  assert.ok(body, 'persistSettings remains testable');
  const entry = Object.values(defaults.bar.layout).flat().find(item => item.id === 'omarchy.clock');
  const base = { ...barModel.entrySettings(entry) };
  const writes = [];
  const root = {
    moduleName: 'omarchy.clock', settings: { ...base }, hostWidget: { settings: {} },
    bar: { shell: { updateEntryInline: (id, settings) => writes.push([id, settings]) } },
  };
  const persist = vm.runInNewContext(`(function(values) {${body[1]}})`, { root });

  persist({ weekStartDay: 'sunday' });
  persist({ birthYear: 1979, lifeExpectancy: 85 });
  assert.equal(writes.length, 2);
  assert.deepEqual(writes.map(([id]) => id), ['omarchy.clock', 'omarchy.clock']);
  assert.deepEqual(root.hostWidget.settings, root.settings, 'the host widget is kept in step');
  // ShellConfig.updateEntryInline stores only what differs from the layout entry.
  assert.deepEqual(Preferences.widgetOverride(base, writes[0][1]), { weekStartDay: 'sunday' });
  assert.deepEqual(Preferences.widgetOverride(base, writes[1][1]),
    { weekStartDay: 'sunday', birthYear: 1979, lifeExpectancy: 85 });
});

test('the memento-mori bar stays hidden without a birth year', () => {
  assert.match(calendarPanel, /setting\("birthYear", 0\)/);
  assert.match(calendarPanel, /visible: root\.birthYear > 0/);
});
