// Static contract of the world clock (plan 02-33, ADR 0029): the delivered Elsewhen file set without people,
// avatars, the big globe or the time-zone change; no start-up probe and nothing running while the panel is
// closed; only fixed https:// open-meteo URLs; "Where are you?" bound to the machine's zone; the bar host,
// the `omarchy.elsewhen` mapping and the native `worldclock` IPC target; Tab switching from the search fields;
// centerEnd placement; curl, tzdata and noto-fonts-cjk in the packages file; city lists persisted only under bar.widgets["omarchy.elsewhen"].
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
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

const dir = 'panels/elsewhen/';
const files = readdirSync(new URL(dir, shell)).sort();
const sources = files.filter(name => /\.(qml|js)$/.test(name)).map(name => dir + name);
const panel = read(`${dir}Panel.qml`);
const host = read('bar/widgets/WorldClock.qml');
const bar = read('bar/Bar.qml');
const defaults = JSON.parse(read('defaults.json'));

test('the delivered Elsewhen files exclude the big globe, its city data and the people avatar', () => {
  assert.deepEqual(files, ['Arc.js', 'ArcText.qml', 'CityMatches.qml', 'CityRow.qml', 'CitySearch.qml',
    'DaylightStrip.qml', 'GlobeModel.js', 'Greetings.js', 'HeroTitle.qml', 'MiniGlobe.qml', 'Model.js',
    'MoonDot.qml', 'Panel.qml', 'Sun.js', 'world.json']);
  for (const name of ['Globe.qml', 'GlobeFooter.qml', 'cities.json', 'Avatar.qml', 'manifest.json'])
    assert.ok(!files.includes(name), name);
});

test('the world clock has no privilege, GitHub, Omarchy coupling, own IPC or bar button', () => {
  for (const file of [...sources, 'bar/widgets/WorldClock.qml']) {
    const text = code(read(file));
    assert.doesNotMatch(text, /\bsudo\b|set-timezone|pkexec/, file);
    assert.doesNotMatch(text, /github/i, file);
    assert.doesNotMatch(text, /omarchy-|OMARCHY_PATH/, file);
    assert.doesNotMatch(text, /ShellIpc|IpcHandler/, file);
    assert.doesNotMatch(text, /XMLHttpRequest|execDetached|execArgv/, file);
  }
  for (const file of sources) assert.doesNotMatch(code(read(file)), /BarIconButton/, file);
  assert.doesNotMatch(code(panel), /timezoneProc|timezoneCommand|peopleProc|profiles|peopleEditIndex|Avatar/);
  assert.doesNotMatch(code(read(`${dir}CityRow.qml`)), /people|Avatar|account-plus|startMoonShow/i);
});

test('nothing probes or fetches until the panel opens', () => {
  assert.doesNotMatch(code(panel), /Component\.onCompleted/);
  assert.doesNotMatch(code(panel), /^\s+running: true/m);
  const timers = code(panel).split('Timer {').slice(1).map(block => block.slice(0, block.indexOf('\n  }')));
  assert.ok(timers.length >= 3);
  for (const block of timers.filter(text => /repeat: true/.test(text)))
    assert.match(block, /running: root\.opened/, block);
  const opened = panel.match(/onOpenedChanged: \{\n    if \(opened\) \{([\s\S]*?)\n    \} else/);
  assert.ok(opened, 'the open branch remains testable');
  assert.match(opened[1], /tick\(\); refresh\(\); refreshFacts\(\); loadCatalog\(\)/);
  // The first-run seed is written from the open-only probe.
  assert.match(panel, /if \(root\.needsSeed\) root\.seedFirstRun\(\)/);
  assert.doesNotMatch(read('defaults.json'), /cities|zones/);
});

test('the big globe is fixed off and the hero globe opens nothing', () => {
  assert.match(panel, /^  readonly property bool globeEnabled: false$/m);
  assert.doesNotMatch(code(panel), /setting\("globeEnabled"|setting\("smoothMotion"|globeMode|globeLoader|Globe\.qml/);
  assert.match(panel, /globeEnabled: root\.globeEnabled/);
  assert.doesNotMatch(code(panel), /onGlobeClicked/);
});

test('the world clock requests only fixed https:// open-meteo URLs through argument vectors', () => {
  const urls = sources.flatMap(file => [...code(read(file)).matchAll(/"(https?:\/\/[^"?]*)/g)].map(m => m[1]));
  assert.deepEqual([...new Set(urls)].sort(),
    ['https://api.open-meteo.com/v1/forecast', 'https://geocoding-api.open-meteo.com/v1/search']);
  const commands = [...code(panel).matchAll(/(\w+)\.command = (.*)/g)].map(m => [m[1], m[2]]);
  assert.deepEqual(commands, [
    ['placeProc', '["curl", "-fsS", "--max-time", "8", Model.geocodeUrl(q)]'],
    ['searchProc', 'Model.probeCommand(searchZoneIds, false)'],
    ['geoProc', `["bash", "-c", 'for url; do curl -fsS --max-time 8 "$url"; printf "\\\\n\\\\036\\\\n"; done', "bash"]`],
    ['weatherProc', '["curl", "-fsS", "--max-time", "8", Model.forecastUrl(stale.map(coordsFor))]'],
  ]);
  assert.match(panel, /\.concat\(missing\.map\(function\(row\) \{ return Model\.geocodeUrl\(row\.label\) \}\)\)/);
  assert.match(panel, /command: Model\.probeCommand\(root\.probeIds, true\)/);
  assert.match(panel, /command: \["timedatectl", "list-timezones"\]/);
});

test('"Where are you?" offers only the machine\'s zone and never changes it', () => {
  assert.match(panel, /readonly property var hereOptions: Model\.zoneOptions\(zoneCatalogText, \[\]\)\n\s+\.filter\(function\(option\) \{ return option\.value === localZone \}\)/);
  assert.match(panel, /return placesFor\(text\)\.filter\(function\(place\) \{ return place\.value === localZone \}\)/);
  const search = panel.slice(panel.indexOf('id: hereSearch'), panel.indexOf('onDismissed', panel.indexOf('id: hereSearch')));
  assert.match(search, /options: root\.hereOptions/);
  assert.match(search, /placesFor: function\(text\) \{ return root\.herePlacesFor\(text\) \}/);
  assert.match(panel, /if \(!next \|\| next\.zoneChange !== ""\) return\n    applyHere\(next\)/);
});

test('the bar maps omarchy.elsewhen to the host and declares the worldclock IPC target', () => {
  assert.match(bar, /"omarchy\.elsewhen": worldClockComponent/);
  assert.match(bar, /Component \{ id: worldClockComponent; Widgets\.WorldClock \{ \} \}/);
  const handler = bar.match(/IpcHandler \{\n    target: "worldclock"\n([\s\S]*?)\n  \}/);
  assert.ok(handler, 'worldclock IpcHandler');
  const functions = [...handler[1].matchAll(/function (\w+)\(\): string \{ return root\.requestPanel\("omarchy\.elsewhen", "(\w+)"\) \}/g)];
  assert.deepEqual(functions.map(match => [match[1], match[2]]),
    [['open', 'open'], ['close', 'close'], ['toggle', 'toggle']]);
  assert.equal((bar.match(/target: "worldclock"/g) || []).length, 1);
});

test('the host loads the panel, injects it and toggles it on any mouse button', () => {
  assert.match(host, /^  moduleName: "omarchy\.elsewhen"$/m);
  assert.match(host, /source: Qt\.resolvedUrl\("\.\.\/\.\.\/panels\/elsewhen\/Panel\.qml"\)/);
  // Quickshell synthesizes a directory's qmldir only when an import reaches it; without this the panel's sibling
  // types (HeroTitle, CitySearch, CityRow, ...) are "not a type" at runtime.
  assert.match(code(host), /^import "\.\.\/\.\.\/panels\/elsewhen" as \w+$/m);
  for (const name of ['bar', 'settings', 'moduleName', 'anchorItem', 'hostWidget'])
    assert.match(host, new RegExp(`if \\("${name}" in target\\) target\\.${name} = `), name);
  for (const fn of ['open', 'close', 'togglePanel', 'closeForPopoutSwitch'])
    assert.match(host, new RegExp(`function ${fn}\\(\\)`), fn);
  assert.match(host, /readonly property bool opened: /);
  assert.match(host, /readonly property bool popoutSwitchClosing: /);
  assert.match(host, /tooltipText: Commons\.I18n\.t\("elsewhen\.worldClock"\)/);
  const pressed = code(host).match(/onPressed: function\(b\) \{([\s\S]*?)\n    \}/);
  assert.ok(pressed, 'the host button keeps one press handler');
  assert.equal(pressed[1].trim(), 'if (root.bar) root.togglePanel()');
});

test('the panel anchors to the injected host and routes through its identity', () => {
  assert.match(panel, /anchorItem: root\.anchorItem\n    owner: root\.barIdentity/);
  assert.match(panel, /readonly property var barIdentity: hostWidget \|\| root/);
  for (const fn of ['open', 'openFromHotkey', 'close', 'toggle', 'switchPanel'])
    assert.match(panel, new RegExp(`function ${fn}\\(`), fn);
  assert.match(panel, /bar\.switchPanelFrom\(root\.barIdentity, direction\)/);
  assert.match(read(`${dir}MiniGlobe.qml`), /Qt\.resolvedUrl\("world\.json"\)/);
});

test('Tab and Shift+Tab in either search field switch panels', () => {
  for (const id of ['hereSearch', 'citySearch']) {
    const tab = new RegExp(`id: ${id}\\n[\\s\\S]*?onDismissed: root\\.takeKeyboardBack\\(\\)\\n\\s+// [^\\n]*\\n` +
      '\\s+Keys\\.onTabPressed: root\\.switchPanel\\(1\\)\\n\\s+Keys\\.onBacktabPressed: root\\.switchPanel\\(-1\\)');
    assert.match(panel, tab, id);
  }
});

test('centerEnd shows the world clock before weather and the packages declare curl, tzdata and CJK fonts', () => {
  assert.deepEqual(defaults.bar.layout.centerEnd, [{ id: 'omarchy.elsewhen' }, { id: 'omarchy.weather' }]);
  const packages = read('packages');
  assert.match(packages, /^curl core$/m);
  assert.match(packages, /^tzdata core$/m);
  assert.match(packages, /^noto-fonts-cjk extra$/m);
});

test('city edits persist only under bar.widgets["omarchy.elsewhen"]', () => {
  const body = panel.match(/  function persistSettings\(values\) \{([\s\S]*?)\n  \}/);
  assert.ok(body, 'persistSettings remains testable');
  const entry = Object.values(defaults.bar.layout).flat().find(item => item.id === 'omarchy.elsewhen');
  const base = { ...barModel.entrySettings(entry) };
  const writes = [];
  const root = {
    moduleName: 'omarchy.elsewhen', settings: { ...base },
    bar: { shell: { updateEntryInline: (id, settings) => writes.push([id, settings]) } },
  };
  const persist = vm.runInNewContext(`(function(values) {${body[1]}})`, { root });

  persist({ cities: [{ name: 'Madrid', zone: 'Europe/Madrid' }], zones: undefined });
  persist({ hour24: true });
  assert.deepEqual(writes.map(([id]) => id), ['omarchy.elsewhen', 'omarchy.elsewhen']);
  assert.deepEqual(Preferences.widgetOverride(base, writes[1][1]),
    { cities: [{ name: 'Madrid', zone: 'Europe/Madrid' }], hour24: true });
  assert.doesNotMatch(code(panel), /bar\.layout|updateEntry\(/);
});
