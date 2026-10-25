// Contracts for the shell preference resolver (DEC-024/025): versioned common
// defaults plus sparse per-option user overrides.
// Usage: node --test tests/capabilities/desktop/shell/config-overrides.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

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
