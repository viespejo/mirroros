// Static contract of the clock calendar panel (plan 02-32, ADR 0029): the unchanged
// v4.5.0 panel files, the adapted bar clock and the native `clock` IPC target, plus
// the calendar's opt-in settings stored per widget id. Then the weather pill and
// panel: no omarchy-* call, only fixed https:// open-meteo URLs, centerEnd
// placement, the native `weather` IPC target and curl in the packages file.
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

const weatherFiles = ['bar/widgets/Weather.qml', 'panels/weather/Panel.qml', 'panels/weather/Model.js',
  'panels/weather/Locations.js'];
const weatherWidget = read('bar/widgets/Weather.qml');
const weatherPanel = read('panels/weather/Panel.qml');

test('weather units follow the measurement locale, not the UI language, unless explicitly set', () => {
  const expression = weatherPanel.match(/readonly property bool useImperial: (.*)/);
  assert.ok(expression, 'the panel unit binding remains testable');
  const Model = require('../../../../capabilities/desktop/shell/panels/weather/Model.js');
  const resolve = (env, unit = '') => vm.runInNewContext(expression[1], {
    Model,
    setting: (name, fallback) => name === 'unit' ? unit : fallback,
    Quickshell: { env: name => env[name] || '' },
  });
  const spanishFormats = { LANG: 'en_US.UTF-8', LC_MESSAGES: 'en_US.UTF-8', LC_MEASUREMENT: 'es_ES.UTF-8' };
  assert.equal(resolve(spanishFormats), false, 'Spanish measurement formats win over the English UI');
  assert.equal(resolve({ LANG: 'es_ES.UTF-8', LC_MEASUREMENT: 'en_US.UTF-8' }), true, 'US measurement formats select imperial');
  assert.equal(resolve({ ...spanishFormats, LC_ALL: 'en_US.UTF-8' }), true, 'LC_ALL overrides LC_MEASUREMENT');
  assert.equal(resolve({ LANG: 'en_US.UTF-8', LC_MEASUREMENT: 'en_US.UTF-8', LC_ALL: 'es_ES.UTF-8' }), false);
  assert.equal(resolve({ LANG: 'en_US.UTF-8' }), true, 'LANG is the fallback without a measurement override');
  assert.equal(resolve({ LANG: 'es_ES.UTF-8' }), false);
  assert.equal(resolve({}), false, 'an unset locale uses the metric C fallback');
  assert.equal(resolve(spanishFormats, 'imperial'), true, 'the explicit imperial setting still wins');
  assert.equal(resolve({ ...spanishFormats, LC_ALL: 'en_US.UTF-8' }, 'metric'), false, 'the explicit metric setting still wins');
});

test('the weather files call no omarchy-* command and hold no wttr.in, IP lookup or state file', () => {
  const files = readdirSync(new URL('panels/weather/', shell)).map(name => `panels/weather/${name}`);
  assert.deepEqual(files.sort(), ['panels/weather/Locations.js', 'panels/weather/Model.js', 'panels/weather/Panel.qml']);
  for (const file of weatherFiles) {
    const text = code(read(file));
    assert.doesNotMatch(text, /omarchy-/, file);
    assert.doesNotMatch(text, /execDetached|\.run\(/, file);
    assert.doesNotMatch(text, /wttr|geo\.omarchy|FileView|weather\.json|\.local\/state/, file);
  }
  assert.doesNotMatch(code(weatherWidget), /\bProcess\b/);
  assert.doesNotMatch(code(read('panels/weather/Locations.js')), /https?:/);
});

test('weather requests only fixed https:// open-meteo URLs through curl argv', () => {
  const urls = weatherFiles.flatMap(file => [...code(read(file)).matchAll(/"(https?:\/\/[^"?]*)/g)].map(m => m[1]));
  assert.deepEqual([...new Set(urls)].sort(),
    ['https://api.open-meteo.com/v1/forecast', 'https://geocoding-api.open-meteo.com/v1/search']);
  const model = code(read('panels/weather/Model.js'));
  assert.match(model, /return \["curl", "-fsS", "--max-time", "5", url\]/);
  // Every process command in the panel comes from the model's builders.
  const commands = [...code(weatherPanel).matchAll(/(\w+)\.command = (.*)/g)].map(m => [m[1], m[2]]);
  assert.deepEqual(commands, [['forecastProc', 'command'], ['geocodeProc', 'Model.geocodingCommand(geocodeActiveQuery)']]);
  assert.match(weatherPanel, /var command = Model\.forecastCommand\(list\)/);
  assert.doesNotMatch(code(weatherPanel), /command: \[/);
});

test('the geocoder runs only while the user edits a location in the open panel', () => {
  assert.match(weatherPanel, /if \(!root\.opened \|\| !root\.editingLocation \|\| query\.length < 2\)/);
  assert.match(weatherPanel, /function startGeocode\(\) \{\n    if \(!root\.opened \|\| !root\.editingLocation\) return/);
});

test('weather search fields forward Tab to panel switching while the key catcher is blocked', () => {
  assert.match(weatherPanel, /blocked: root\.editingLocation/);
  const handler = weatherPanel.slice(weatherPanel.indexOf('function handleSearchKey(event)'));
  assert.match(handler, /event\.key === Qt\.Key_Tab \|\| event\.key === Qt\.Key_Backtab\) \{\n      root\.switchPanel\(/);
  assert.equal((weatherPanel.match(/Keys\.onPressed: function\(event\) \{ root\.handleSearchKey\(event\) \}/g) || []).length, 2);
});

test('weather panel keys follow Elsewhen: move, act on and remove the focus, a or + adds', () => {
  assert.match(weatherPanel, /onActivateRequested: root\.activateFocused\(\)/);
  assert.doesNotMatch(code(weatherPanel), /onReturnRequested/);
  assert.match(weatherPanel, /onDeleteRequested: root\.removeFocused\(\)/);
  assert.match(weatherPanel, /onMoveRequested: function\(dx, dy\) \{[\s\S]*?root\.moveFocus\(dy\)/);
  assert.match(weatherPanel, /if \(text === "a" \|\| text === "\+"\) root\.startEditingLocation\("add"\)/);
  assert.match(weatherPanel, /rowHover\.hovered \|\| root\.focusIndex === locationRow\.index/);
  assert.match(weatherPanel, /hasCursor: root\.focusIndex === root\.otherLocations\.length/);
  assert.match(weatherPanel, /function removeFocused\(\) \{[\s\S]*?if \(!Locations\.canRemove\(locationState, index\)\) return/);
});

test('a failed weather request keeps the previous values and starts no retry', () => {
  assert.doesNotMatch(code(weatherPanel), /[Rr]etry/);
  assert.match(weatherPanel, /if \(!parsed\) return/);
});

test('the weather pill sits in centerEnd with no shipped location and toggles on any click', () => {
  assert.deepEqual(defaults.bar.layout.centerEnd, [{ id: 'omarchy.weather' }]);
  assert.doesNotMatch(read('defaults.json'), /locations|latitude/);
  assert.match(bar, /"omarchy\.weather": weatherComponent/);
  assert.match(bar, /Component \{ id: weatherComponent; Widgets\.Weather \{ \} \}/);
  const pressed = code(weatherWidget).match(/onPressed: function\(b\) \{([\s\S]*?)\n    \}/);
  assert.ok(pressed, 'the weather button keeps one press handler');
  assert.equal(pressed[1].trim(), 'if (root.bar) root.togglePanel()');
  assert.match(weatherWidget, /source: Qt\.resolvedUrl\("\.\.\/\.\.\/panels\/weather\/Panel\.qml"\)/);
  for (const name of ['bar', 'settings', 'moduleName', 'anchorItem', 'hostWidget'])
    assert.match(weatherWidget, new RegExp(`if \\("${name}" in target\\) target\\.${name} = `), name);
  assert.doesNotMatch(weatherWidget, /^  visible:/m, 'the pill is always shown');
  assert.match(weatherPanel, /Model\.NEUTRAL_ICON/);
});

test('the bar declares the native weather IPC target with open, close and toggle only', () => {
  const handler = bar.match(/IpcHandler \{\n    target: "weather"\n([\s\S]*?)\n  \}/);
  assert.ok(handler, 'weather IpcHandler');
  const functions = [...handler[1].matchAll(/function (\w+)\(\): string \{ return root\.requestPanel\("omarchy\.weather", "(\w+)"\) \}/g)];
  assert.deepEqual(functions.map(match => [match[1], match[2]]),
    [['open', 'open'], ['close', 'close'], ['toggle', 'toggle']]);
  assert.doesNotMatch(code(weatherPanel), /ShellIpc|IpcHandler/);
});

test('curl is declared in the shell packages file', () => {
  const lines = read('packages').split('\n');
  const index = lines.indexOf('curl core');
  assert.ok(index > 0, 'curl core');
  assert.match(lines[index - 1], /^# .*open-meteo/);
});
