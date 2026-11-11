// Contracts for the shell preference resolver (DEC-024/025): versioned common
// defaults plus sparse per-option user overrides.
// Usage: node --test tests/capabilities/desktop/shell/config-overrides.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const shellDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../../capabilities/desktop/shell');
const require = createRequire(import.meta.url);
const P = require(path.join(shellDir, 'services/ShellPreferences.js'));
const shippedDefaults = JSON.parse(fs.readFileSync(path.join(shellDir, 'defaults.json'), 'utf8'));

const defaults = {
  version: 1,
  bar: { position: 'top', background: 'opaque', layout: { left: [{ id: 'a' }, { id: 'b' }], right: [{ id: 'c' }] } },
  plugins: [],
};
const clone = value => JSON.parse(JSON.stringify(value));

// Simulates ShellConfig.commit: mutate the effective config, record changed paths.
function save(base, overrides, mutate) {
  const before = P.resolve(base, overrides);
  const after = clone(before);
  mutate(after);
  return P.applyChanges(overrides, P.diff(before, after));
}

test('shipped defaults.json is a valid version-1 defaults document', () => {
  assert.equal(P.validateDefaults(shippedDefaults), '');
  assert.ok(Array.isArray(shippedDefaults.bar.layout.right));
});

test('missing preferences resolve to the current defaults', () => {
  const parsed = P.parse('', defaults);
  assert.equal(parsed.status, 'absent');
  assert.deepEqual(P.resolve(defaults, parsed.overrides), defaults);
  assert.equal(P.parse('  \n', defaults).status, 'absent');
});

test('uncustomized options follow updated defaults; explicit overrides survive', () => {
  const overrides = { version: 1, bar: { position: 'bottom' } };
  const updated = clone(defaults);
  updated.bar.position = 'left';
  updated.bar.background = 'translucent';
  const effective = P.resolve(updated, overrides);
  assert.equal(effective.bar.position, 'bottom');
  assert.equal(effective.bar.background, 'translucent');
  assert.deepEqual(effective.bar.layout, updated.bar.layout);
});

test('lists replace the whole default list', () => {
  const overrides = { version: 1, bar: { layout: { left: [{ id: 'z' }] } } };
  const effective = P.resolve(defaults, overrides);
  assert.deepEqual(effective.bar.layout.left, [{ id: 'z' }]);
  assert.deepEqual(effective.bar.layout.right, [{ id: 'c' }]);
  const empty = P.resolve(defaults, { version: 1, bar: { layout: { right: [] } } });
  assert.deepEqual(empty.bar.layout.right, []);
});

test('removing an override restores the current default and prunes empty objects', () => {
  const overrides = { version: 1, bar: { position: 'bottom', layout: { left: [{ id: 'z' }] } }, notifications: { fontScale: 120 } };
  let next = P.removeOverride(overrides, ['bar', 'layout', 'left']);
  assert.deepEqual(next, { version: 1, bar: { position: 'bottom' }, notifications: { fontScale: 120 } });
  next = P.removeOverride(next, ['bar', 'position']);
  assert.deepEqual(next, { version: 1, notifications: { fontScale: 120 } });
  assert.deepEqual(P.resolve(defaults, next).bar, defaults.bar);
  assert.deepEqual(P.removeOverride(next, ['bar', 'missing', 'deep']), next);
});

test('saving one option does not snapshot unrelated effective defaults', () => {
  const next = save(defaults, { version: 1 }, config => {
    config.notifications = { fontScale: 110 };
  });
  assert.deepEqual(next, { version: 1, notifications: { fontScale: 110 } });
  const updated = clone(defaults);
  updated.bar.position = 'left';
  assert.equal(P.resolve(updated, next).bar.position, 'left');
});

test('changing one list entry records that whole list only', () => {
  const next = save(defaults, { version: 1 }, config => {
    config.bar.layout.left[0] = { id: 'a', format: 'HH:mm' };
  });
  assert.deepEqual(next, { version: 1, bar: { layout: { left: [{ id: 'a', format: 'HH:mm' }, { id: 'b' }] } } });
});

test('an unchanged mutation records nothing and serialization is stable', () => {
  const overrides = { notifications: { fontScale: 110 }, version: 1 };
  const before = P.resolve(defaults, overrides);
  assert.deepEqual(P.diff(before, clone(before)), []);
  const text = P.serialize(overrides);
  assert.ok(text.startsWith('{\n  "version": 1,'));
  assert.equal(P.serialize(P.parse(text, defaults).overrides), text);
});

test('existing overrides are retained when another option is saved', () => {
  const next = save(defaults, { version: 1, bar: { position: 'bottom' } }, config => {
    config.notifications = { stacking: 'all' };
  });
  assert.deepEqual(next, { version: 1, bar: { position: 'bottom' }, notifications: { stacking: 'all' } });
});

test('setting a value equal to the current default keeps it as an explicit choice', () => {
  const overrides = { version: 1, bar: { position: 'bottom' } };
  const next = save(defaults, overrides, config => { config.bar.position = 'top'; });
  assert.deepEqual(next, { version: 1, bar: { position: 'top' } });
});

test('invalid and unsupported files are reported, not reinterpreted', () => {
  const cases = [
    ['{', 'malformed JSON'],
    ['[]', 'top level must be a JSON object'],
    ['{"bar":{}}', 'unsupported version'],
    ['{"version":2}', 'unsupported version'],
    ['{"version":1,"theme":{}}', 'unsupported key theme'],
    ['{"version":1,"bar":[]}', 'bar: expected object, found array'],
    ['{"version":1,"bar":{"layout":{"left":{}}}}', 'bar.layout.left: expected array, found object'],
    ['{"version":1,"bar":{"position":3}}', 'bar.position: expected string, found number'],
    ['{"version":1,"notifications":[]}', 'notifications: expected object, found array'],
  ];
  for (const [text, reason] of cases) {
    const parsed = P.parse(text, defaults);
    assert.equal(parsed.status, 'invalid', text);
    assert.ok(parsed.error.includes(reason), `${text}: ${parsed.error}`);
    assert.deepEqual(P.resolve(defaults, parsed.overrides), defaults, text);
  }
});

test('prototype-pollution keys are rejected and never merged', () => {
  for (const text of [
    '{"version":1,"__proto__":{"polluted":true}}',
    '{"version":1,"bar":{"constructor":{"prototype":{"polluted":true}}}}',
    '{"version":1,"notifications":{"x":[{"prototype":1}]}}',
  ]) {
    const parsed = P.parse(text, defaults);
    assert.equal(parsed.status, 'invalid', text);
    assert.match(parsed.error, /forbidden key/);
  }
  const hostile = JSON.parse('{"version":1,"bar":{"__proto__":{"polluted":true}}}');
  P.resolve(defaults, hostile);
  P.applyChanges({ version: 1 }, [{ path: ['__proto__', 'polluted'], value: true }]);
  assert.equal({}.polluted, undefined);
  assert.equal(P.validateDefaults(JSON.parse('{"version":1,"__proto__":{}}')).startsWith('forbidden key'), true);
});

test('keys without a default are accepted for their consumer to validate', () => {
  const parsed = P.parse('{"version":1,"notifications":{"historyHours":1,"unknown":"x"}}', defaults);
  assert.equal(parsed.status, 'valid');
  assert.equal(P.resolve(defaults, parsed.overrides).notifications.historyHours, 1);
});

test('resolution does not mutate its inputs', () => {
  const d = clone(defaults), o = { version: 1, bar: { layout: { left: [{ id: 'z' }] } } };
  const snapshotD = clone(d), snapshotO = clone(o);
  const effective = P.resolve(d, o);
  effective.bar.layout.left.push({ id: 'y' });
  P.applyChanges(o, [{ path: ['bar', 'position'], value: 'left' }]);
  assert.deepEqual(d, snapshotD);
  assert.deepEqual(o, snapshotO);
});

// Per-widget inline settings (DEC-035/039): bar.widgets.<id>, never bar.layout.
const barModel = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(shellDir, 'bar/BarModel.js'), 'utf8'), barModel);

// Mirrors ShellConfig.updateEntryInline for a widget placed in the layout.
function saveInline(base, overrides, id, settings) {
  const before = P.resolve(base, overrides);
  const after = clone(before);
  let entry = null;
  for (const zone of Object.keys(after.bar.layout)) {
    entry = (after.bar.layout[zone] || []).find(e => e && e.id === id) || null;
    if (entry) break;
  }
  assert.ok(entry, `${id} is in the layout`);
  const override = P.widgetOverride(barModel.entrySettings(entry), settings);
  after.bar.widgets = after.bar.widgets || {};
  if (Object.keys(override).length) after.bar.widgets[id] = override;
  else delete after.bar.widgets[id];
  if (!Object.keys(after.bar.widgets).length) delete after.bar.widgets;
  return P.applyChanges(overrides, P.diff(before, after));
}

function effectiveSettings(base, overrides, id) {
  const config = P.resolve(base, overrides);
  const entry = Object.values(config.bar.layout).flat().find(e => e && e.id === id);
  return { ...barModel.entrySettings(entry, (config.bar.widgets || {})[id]) };
}

test('an inline setting is written sparsely under bar.widgets.<id> only', () => {
  const next = saveInline(defaults, { version: 1 }, 'a', { id: 'a', format: 'HH:mm' });
  assert.deepEqual(next, { version: 1, bar: { widgets: { a: { format: 'HH:mm' } } } });
  const pinned = saveInline(defaults, next, 'c', { id: 'c', pinned: ['x'], hidden: [] });
  assert.deepEqual(pinned.bar, { widgets: { a: { format: 'HH:mm' }, c: { pinned: ['x'], hidden: [] } } });
  assert.equal('layout' in pinned.bar, false);
});

test('a later default layout change still reaches a user with inline settings', () => {
  const next = saveInline(defaults, { version: 1 }, 'c', { id: 'c', showPercentage: true });
  const updated = clone(defaults);
  updated.bar.layout.right = [{ id: 'c' }, { id: 'd' }];
  const effective = P.resolve(updated, next);
  assert.deepEqual(effective.bar.layout.right, [{ id: 'c' }, { id: 'd' }]);
  assert.deepEqual(effectiveSettings(updated, next, 'c'), { showPercentage: true });
});

test('precedence: defaults entry < hand-written layout entry < bar.widgets', () => {
  const base = clone(defaults);
  base.bar.layout.left[0] = { id: 'a', format: 'x', size: 1 };
  assert.deepEqual(effectiveSettings(base, { version: 1 }, 'a'), { format: 'x', size: 1 });
  const legacy = { version: 1, bar: { layout: { left: [{ id: 'a', format: 'y' }] } } };
  assert.deepEqual(effectiveSettings(base, legacy, 'a'), { format: 'y' });
  const both = { version: 1, bar: { layout: legacy.bar.layout, widgets: { a: { format: 'z' } } } };
  assert.deepEqual(effectiveSettings(base, both, 'a'), { format: 'z' });
  assert.deepEqual(effectiveSettings(base, { version: 1, bar: { widgets: { a: { format: 'z' } } } }, 'a'), { format: 'z', size: 1 });
});

test('a legacy zone override is honoured and left untouched by inline saves', () => {
  const legacy = { version: 1, bar: { layout: { left: [{ id: 'a', format: 'y' }] } } };
  const next = saveInline(defaults, legacy, 'a', { id: 'a', format: 'y', weekStartDay: 1 });
  assert.deepEqual(next.bar.layout, legacy.bar.layout);
  assert.deepEqual(next.bar.widgets, { a: { weekStartDay: 1 } });
  assert.deepEqual(effectiveSettings(defaults, next, 'a'), { format: 'y', weekStartDay: 1 });
});

test('a key no longer sent or equal to the base resets its override', () => {
  const base = clone(defaults);
  base.bar.layout.left[0] = { id: 'a', format: 'x' };
  const start = { version: 1, bar: { position: 'bottom', widgets: { a: { format: 'z', week: 1 } } } };
  const dropped = saveInline(base, start, 'a', { id: 'a', format: 'z' });
  assert.deepEqual(dropped.bar.widgets, { a: { format: 'z' } });
  const reset = saveInline(base, dropped, 'a', { id: 'a', format: 'x' });
  assert.deepEqual(reset, { version: 1, bar: { position: 'bottom' } });
  assert.deepEqual(saveInline(base, { version: 1 }, 'a', { id: 'a', format: 'x' }), { version: 1 });
  assert.deepEqual(saveInline(base, start, 'a', { id: 'a', format: 'z', week: 1 }), start);
});

test('a bar.widgets that is not an object of objects is invalid and preserved', () => {
  for (const text of [
    '{"version":1,"bar":{"widgets":[]}}',
    '{"version":1,"bar":{"widgets":"x"}}',
    '{"version":1,"bar":{"widgets":{"a":[]}}}',
    '{"version":1,"bar":{"widgets":{"a":null}}}',
  ]) {
    const parsed = P.parse(text, defaults);
    assert.equal(parsed.status, 'invalid', text);
    assert.match(parsed.error, /^bar\.widgets/, text);
    assert.deepEqual(P.resolve(defaults, parsed.overrides), defaults, text);
  }
  assert.equal(P.parse('{"version":1,"bar":{"widgets":{"a":{"format":"x"}}}}', defaults).status, 'valid');
});

function shellSources(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return shellSources(full);
    return /\.(qml|js)$/.test(entry.name) ? [full] : [];
  });
}
const codeLines = text => text.split('\n').filter(line => !/^\s*(\/\/|\*|\/\*)/.test(line)).join('\n');

test('no shell source writes into bar.layout zones; inline saves go through updateEntryInline', () => {
  const zoneWrite = /\blayout(\.\w+|\[[^\]]+\])(\[[^\]]+\])?\s*(=(?!=)|\.(push|splice|unshift)\()/;
  for (const file of shellSources(shellDir)) {
    const code = codeLines(fs.readFileSync(file, 'utf8'));
    assert.doesNotMatch(code, zoneWrite, path.relative(shellDir, file));
  }
  const config = codeLines(fs.readFileSync(path.join(shellDir, 'services/ShellConfig.qml'), 'utf8'));
  assert.match(config, /Preferences\.widgetOverride\(base, settings\)/);
  assert.match(config, /copy\.bar\.widgets\[stripped\] = override/);
  for (const widget of ['Clock', 'Tray', 'Power']) {
    const code = codeLines(fs.readFileSync(path.join(shellDir, `bar/widgets/${widget}.qml`), 'utf8'));
    assert.match(code, /\.updateEntryInline\(/, widget);
  }
});
