// Weather locations (plan 02-32, ADR 0029): the owned list operations and
// schedule decisions in panels/weather/Locations.js, the saved shell.json shape
// through ShellPreferences and the panel's persistLocations, and the combined
// request built for the saved list.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import vm from 'node:vm';

const require = createRequire(import.meta.url);
const shellPath = '../../../../capabilities/desktop/shell/';
const Locations = require(`${shellPath}panels/weather/Locations.js`);
const Model = require(`${shellPath}panels/weather/Model.js`);
const Preferences = require(`${shellPath}services/ShellPreferences.js`);
const shell = new URL(shellPath, import.meta.url);
const read = file => readFileSync(new URL(file, shell), 'utf8');
const panel = read('panels/weather/Panel.qml');
const defaults = JSON.parse(read('defaults.json'));
// Plain copies, so values built in another realm compare by structure.
const plain = value => JSON.parse(JSON.stringify(value));

const malibu = { name: 'Malibu', latitude: 34.02577, longitude: -118.7804 };
const oslo = { name: 'Oslo', latitude: 59.91273, longitude: 10.74609 };
const lima = { name: 'Lima', latitude: -12.04318, longitude: -77.02824 };
const empty = Locations.normalize({});

test('normalisation drops unusable records and clamps the active index', () => {
  assert.deepEqual(empty, { locations: [], active: 0 });
  assert.deepEqual(Locations.normalize({ locations: [malibu, { name: '', latitude: 1, longitude: 1 },
    { name: 'Far', latitude: 91, longitude: 0 }, { name: 'Text', latitude: 'x', longitude: 1 },
    { name: ' Oslo ', latitude: '59.91273', longitude: '10.74609' }], active: 7 }),
  { locations: [malibu, oslo], active: 0 });
  assert.deepEqual(Locations.normalize({ locations: [malibu, oslo], active: 1 }).active, 1);
  assert.deepEqual(Locations.normalize({ locations: 'Malibu' }), empty);
  assert.equal(Locations.location({ name: 'Bare' }), null, 'a name without coordinates is not a location');
});

test('the first added location becomes active and later adds keep the active one', () => {
  let state = Locations.add(empty, malibu);
  assert.deepEqual(state, { locations: [malibu], active: 0 });
  state = Locations.add(state, oslo);
  assert.deepEqual(state, { locations: [malibu, oslo], active: 0 });
  assert.deepEqual(Locations.add(state, { name: 'Nowhere' }), state, 'an unusable record is ignored');
});

test('the pinned-name search replaces only the active record', () => {
  const state = { locations: [malibu, oslo], active: 1 };
  assert.deepEqual(Locations.replaceActive(state, lima), { locations: [malibu, lima], active: 1 });
  assert.deepEqual(Locations.replaceActive(empty, lima), { locations: [lima], active: 0 },
    'with nothing saved the search adds the first location');
});

test('activating a row moves the previous active location back into the list', () => {
  const state = { locations: [malibu, oslo, lima], active: 0 };
  assert.deepEqual(Locations.others(state).map(row => row.location.name), ['Oslo', 'Lima']);
  const next = Locations.activate(state, 2);
  assert.equal(Locations.activeLocation(next).name, 'Lima');
  assert.deepEqual(Locations.others(next).map(row => [row.index, row.location.name]), [[0, 'Malibu'], [1, 'Oslo']],
    'the other rows keep the saved order');
  assert.deepEqual(Locations.activate(state, 9), state, 'an unknown row changes nothing');
});

test('only non-active rows can be removed, never the last location', () => {
  const state = { locations: [malibu, oslo, lima], active: 2 };
  assert.equal(Locations.canRemove(state, 2), false, 'the active row');
  assert.equal(Locations.canRemove({ locations: [malibu], active: 0 }, 0), false, 'the last location');
  assert.deepEqual(Locations.remove(state, 2), state);
  assert.deepEqual(Locations.remove(state, 0), { locations: [oslo, lima], active: 1 },
    'removing a row before the active one keeps the same location active');
  assert.deepEqual(Locations.remove({ locations: [malibu, oslo], active: 0 }, 1), { locations: [malibu], active: 0 });
});

test('the panel saves the list sparsely under bar.widgets["omarchy.weather"]', () => {
  const body = panel.match(/  function persistLocations\(state\) \{([\s\S]*?)\n  \}/);
  assert.ok(body, 'persistLocations remains testable');
  const entry = Object.values(defaults.bar.layout).flat().find(item => item.id === 'omarchy.weather');
  const base = {};
  for (const key in entry) if (key !== 'id') base[key] = entry[key];
  const writes = [];
  const root = {
    moduleName: 'omarchy.weather', settings: { ...base }, hostWidget: { settings: {} },
    bar: { shell: { updateEntryInline: (id, settings) => writes.push([id, settings]) } },
  };
  const persist = vm.runInNewContext(`(function(state) {${body[1]}})`, { root, Locations });

  persist(Locations.add(empty, malibu));
  persist(Locations.add(Locations.normalize(root.settings), oslo));
  persist(Locations.activate(Locations.normalize(root.settings), 1));
  assert.deepEqual(writes.map(([id]) => id), ['omarchy.weather', 'omarchy.weather', 'omarchy.weather']);
  assert.deepEqual(root.hostWidget.settings, root.settings, 'the host widget is kept in step');

  // ShellConfig.updateEntryInline stores only what differs from the layout entry.
  const overrides = writes.map(([, settings]) => plain(Preferences.widgetOverride(base, settings)));
  assert.deepEqual(overrides[0], { locations: [malibu], active: 0 });
  assert.deepEqual(overrides[2], { locations: [malibu, oslo], active: 1 });

  // The user file keeps that override under bar.widgets and never a bar.layout key.
  const file = { version: 1, bar: { widgets: { 'omarchy.weather': overrides[2] } } };
  const parsed = Preferences.parse(Preferences.serialize(file), defaults);
  assert.equal(parsed.status, 'valid');
  assert.equal(Object.hasOwn(parsed.overrides.bar, 'layout'), false);
  const resolved = Preferences.resolve(defaults, parsed.overrides);
  const settings = Preferences.widgetSettings(base, resolved.bar.widgets['omarchy.weather']);
  assert.deepEqual(plain(Locations.normalize(settings)), { locations: [malibu, oslo], active: 1 });
});

test('a closed panel fetches only the active location; an open one fetches all in one request', () => {
  const state = { locations: [malibu, oslo, lima], active: 1 };
  assert.equal(Locations.fetchScope(state, false, false, 'timer'), 'active');
  assert.equal(Locations.fetchScope(state, false, false, 'change'), 'active');
  assert.equal(Locations.fetchScope(state, false, false, 'open'), 'all');
  assert.equal(Locations.fetchScope(state, true, false, 'timer'), 'all');
  assert.deepEqual(plain(Locations.fetchLocations(state, 'active')), [oslo]);
  assert.deepEqual(plain(Locations.fetchLocations(state, 'all')), [malibu, oslo, lima]);
  assert.deepEqual(plain(Locations.fetchLocations(state, 'none')), []);

  const [url] = Model.forecastCommand(Locations.fetchLocations(state, 'all')).slice(-1);
  assert.match(url, /^https:\/\/api\.open-meteo\.com\/v1\/forecast\?latitude=34\.02577,59\.91273,-12\.04318&longitude=-118\.7804,10\.74609,-77\.02824&/);
});

test('nothing is fetched without a location or while locked; unlocking refreshes', () => {
  for (const reason of ['timer', 'open', 'unlock', 'change']) {
    assert.equal(Locations.fetchScope(empty, true, false, reason), 'none', `${reason} without a location`);
    assert.equal(Locations.fetchScope({ locations: [malibu], active: 0 }, true, true, reason), 'none', `${reason} while locked`);
  }
  assert.equal(Locations.unlocked(true, false), true, 'locked -> unlocked is the resume refresh');
  assert.equal(Locations.unlocked(false, false), false);
  assert.equal(Locations.unlocked(false, true), false);
  assert.equal(Locations.unlocked(true, true), false);
  assert.equal(Locations.fetchScope({ locations: [malibu, oslo], active: 0 }, false, false, 'unlock'), 'active');
});

test('the schedule runs every 30 minutes and only with a saved location', () => {
  assert.equal(Locations.REFRESH_MS, 30 * 60 * 1000);
  const timer = panel.match(/  Timer \{\n    id: refreshTimer\n([\s\S]*?)\n  \}/);
  assert.ok(timer, 'refreshTimer');
  assert.match(timer[1], /interval: Locations\.REFRESH_MS/);
  assert.match(timer[1], /running: root\.hasLocation/);
  assert.match(timer[1], /onTriggered: root\.refresh\("timer"\)/);
  assert.doesNotMatch(timer[1], /triggeredOnStart/);
  assert.match(panel, /onLockedNowChanged: \{[\s\S]*?Locations\.unlocked\(wasLocked, lockedNow\)[\s\S]*?refresh\("unlock"\)/);
  assert.match(panel, /firstPartyServiceFor\("omarchy\.notifications"\)/);
  assert.match(panel, /function afterOpen\(\) \{\n    root\.focusIndex = -1\n    root\.refresh\("open"\)/);
});

test('keyboard focus walks the hero, the other rows and "+ Add location", wrapping round', () => {
  // Two other rows: -1 hero, 0 and 1 rows, 2 "+ Add location".
  assert.deepEqual([-1, 0, 1, 2].map(at => Locations.moveFocus(at, 1, 2)), [0, 1, 2, -1]);
  assert.deepEqual([-1, 0, 1, 2].map(at => Locations.moveFocus(at, -1, 2)), [2, -1, 0, 1]);
  // Only the active location: the hero and "+ Add location".
  assert.equal(Locations.moveFocus(-1, 1, 0), 0);
  assert.equal(Locations.moveFocus(0, 1, 0), -1);
  assert.equal(Locations.clampFocus(5, 2), 2);
  assert.equal(Locations.clampFocus(-3, 2), -1);
  assert.equal(Locations.clampFocus(undefined, 2), -1);
});
