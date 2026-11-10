// Exercise the QML record builder with synthetic compositor and registry data.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const source = readFileSync(new URL('../../../../capabilities/desktop/shell/services/KeybindingHelp.qml', import.meta.url), 'utf8');
const start = source.indexOf('  function buildRecords(registryText) {');
const end = source.indexOf('\n  // Selector options', start);
assert.ok(start >= 0 && end > start);
const buildRecords = source.slice(start, end).trim();

function build(binds) {
  const root = {
    bindsJson: binds,
    parseRegistry: () => ({ byKeys: { 'SUPER+D': 'menu.apps' }, entries: [] }),
    keysFor: bind => bind.key ? `SUPER + ${bind.key}` : 'SUPER + ',
    canonicalKeys: keys => keys.replaceAll(' ', '').toUpperCase(),
    matchWithoutKey: bind => bind.description === 'Workspace' ? { id: 'workspace.2', keys: 'SUPER + code:11' } : null,
  };
  runInNewContext(`(${buildRecords})("")`, { root });
  return JSON.parse(JSON.stringify(root.records));
}

test('duplicate keyed rows remain visible but cannot dispatch the registered action', () => {
  const rows = build([{ key: 'D', description: 'Apps' }, { key: 'D', description: 'Personal' }, { key: 'X', description: 'Other' }]);
  assert.deepEqual(rows.map(row => [row.description, row.id, row.launchable]), [
    ['Apps', '', false], ['Personal', '', false], ['Other', '', false],
  ]);
});

test('duplicate keyless matches are not launchable; unique matches remain launchable', () => {
  const rows = build([{ key: '', description: 'Workspace' }, { key: '', description: 'Workspace' }, { key: 'D', description: 'Apps' }]);
  assert.deepEqual(rows.map(row => [row.id, row.launchable]), [['', false], ['', false], ['menu.apps', true]]);
});

function qmlFunction(name) {
  const begin = source.indexOf(`  function ${name}(`);
  const finish = source.indexOf('\n  }\n', begin);
  assert.ok(begin >= 0 && finish > begin, name);
  return source.slice(begin, finish + 4).trim();
}

test('keyless bar panel chords resolve to their own entry beside workspace digits', () => {
  const root = {};
  runInNewContext(['canonicalKeys', 'canonicalModifiers', 'matchWithoutKey']
    .map(name => `root.${name} = ${qmlFunction(name).replace(/^function \w+/, 'function')};`).join('\n'), { root });
  const entries = [{ id: 'panel.bluetooth', keys: 'SUPER + CTRL + B', description: 'Bluetooth',
    modifiers: root.canonicalModifiers(root.canonicalKeys('SUPER + CTRL + B')) }];
  for (let n = 1; n <= 9; n++) {
    for (const [id, keys, description] of [
      [`panel.at-${n}`, `SUPER + CTRL + code:${n + 9}`, `Bar panel ${n}`],
      [`workspace.${n}`, `SUPER + code:${n + 9}`, 'Switch to workspace'],
    ]) {
      const canonical = root.canonicalKeys(keys);
      entries.push({ id, keys, description, modifiers: root.canonicalModifiers(canonical) });
    }
  }
  for (let n = 1; n <= 9; n++) {
    root.keysFor = () => 'SUPER + CTRL + ';
    assert.equal(runInNewContext('root.matchWithoutKey(bind, entries)', { root, entries, bind: { description: `Bar panel ${n}` } }).id, `panel.at-${n}`);
  }
  assert.equal(runInNewContext('root.matchWithoutKey(bind, entries)', { root, entries, bind: { description: 'Bluetooth' } }).id, 'panel.bluetooth');
  root.keysFor = () => 'SUPER + ';
  assert.equal(runInNewContext('root.matchWithoutKey(bind, entries)', { root, entries, bind: { description: 'Bar panel 1' } }), null);
});
