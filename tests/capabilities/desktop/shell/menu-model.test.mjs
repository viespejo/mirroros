#!/usr/bin/env node
// Synthetic checks for the adapted menu model (Story 4.3 prototype, Brief 3).
// Usage: node tests/capabilities/desktop/shell/menu-model.test.mjs [<omarchy-src>]
// With the pinned Omarchy source, also verifies that MenuModel.js equals
// upstream except for the header and the removed guard/summon block.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const shellDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../../capabilities/desktop/shell');
const require = createRequire(import.meta.url);
const MenuModel = require(path.join(shellDir, 'menu/MenuModel.js'));
const MirrorMenu = require(path.join(shellDir, 'menu/MirrorMenu.js'));
let passed = 0;
const test = (name, fn) => { fn(); passed += 1; console.log(`PASS ${name}`); };

const normalized = MirrorMenu.rawItems().map(([id, raw]) => MenuModel.normalizeItem(id, raw));
const { items, itemOrder } = MenuModel.mergeMenuSources(normalized, [], 'Go');

test('model: root injected with upstream label and first in order', () => {
  assert.equal(itemOrder[0], 'root');
  assert.equal(items.root.label, 'Go');
});

test('model: approved root groups retain upstream order', () => {
  assert.deepEqual(itemOrder.filter(id => items[id].parent === 'root'), ['apps', 'learn', 'style', 'install', 'system']);
});

test('model: Apps is a provider submenu, not an action', () => {
  assert.equal(items.apps.kind, 'menu');
  assert.equal(items.apps.provider, 'apps');
});

test('model: System rows in upstream order, all closed-table actions', () => {
  const rows = itemOrder.filter(id => items[id].parent === 'system');
  assert.deepEqual(rows, ['system.lock', 'system.suspend', 'system.hibernate', 'system.logout', 'system.reboot', 'system.shutdown']);
  for (const id of rows) {
    assert.equal(items[id].kind, 'action');
    assert.ok(MirrorMenu.isKnownAction(items[id].action), id);
    assert.equal(items[id].when, '');
  }
});

test('model: every action belongs to the closed table', () => {
  for (const id of itemOrder) if (items[id].action) assert.ok(MirrorMenu.isKnownAction(items[id].action), id);
  assert.equal(MirrorMenu.isKnownAction('systemctl poweroff'), false);
  assert.equal(MirrorMenu.isKnownAction('omarchy-system logout'), false);
});

test('routing: ids and aliases, unknown falls through', () => {
  assert.equal(MenuModel.resolveRoute(items, itemOrder, 'power-menu'), 'system');
  assert.equal(MenuModel.resolveRoute(items, itemOrder, 'applications'), 'apps');
  assert.equal(MenuModel.resolveRoute(items, itemOrder, 'wallpaper'), 'style.background');
  assert.equal(items['style.background'].action, 'wallpaper:open');
  assert.equal(items['install.style.background'].action, 'wallpaper:install');
  assert.deepEqual(itemOrder.filter(id => items[id].parent === 'style'), ['style.background']);
  assert.deepEqual(itemOrder.filter(id => items[id].parent === 'install'), ['install.style']);
  assert.equal(MenuModel.resolveRoute(items, itemOrder, ''), 'root');
  assert.equal(MenuModel.resolveRoute(items, itemOrder, 'nope'), 'nope');
});

test('apps: merged rows are children of apps and never routable', () => {
  const merged = MenuModel.mergeAppRows(items, itemOrder, [
    { id: 'apps.synthetic', parent: 'apps', kind: 'app', label: 'Synthetic', aliases: ['system'], searchTerms: [], description: '' }]);
  assert.equal(merged.items['apps.synthetic'].parent, 'apps');
  assert.equal(MenuModel.resolveRoute(merged.items, merged.itemOrder, 'system'), 'system');
  assert.equal(MenuModel.parentPathFor(merged.items, 'apps.synthetic'), 'Apps');
});

test('search: visible flag decides inclusion; label prefix outranks name text', () => {
  const lock = items['system.lock'];
  assert.equal(MenuModel.matchesQuery(lock, 'lock', true), true);
  assert.equal(MenuModel.matchesQuery(lock, 'lock', false), false);
  assert.ok(MenuModel.searchScore(items, items.learn, 'l') < MenuModel.searchScore(items, items.apps, 'l'));
});

test('labels: no checkmark without a checked/disabled expression', () => {
  assert.equal(MenuModel.labelFor(items['system.lock'], {}, { 'system.lock': true }), 'Lock');
});

test('dmenu helpers unchanged in behavior', () => {
  assert.equal(MenuModel.dmenuValue('\uf00c\tBeta\tsub'), 'Beta\tsub');
  assert.equal(MenuModel.dmenuValue('Alpha'), 'Alpha');
  assert.deepEqual(MenuModel.dmenuSelections(['A', 'B', 'C'], ['C', 'A', 'X']), ['A', 'C']);
  assert.deepEqual(MenuModel.dmenuSelections(['A', 'B', 'C'], ['C', 'A'], true), ['C', 'A']);
  assert.deepEqual(MenuModel.toggleDmenuSelection(['A'], 'A'), []);
});

test('removed: generated guard batch and plugin summon parsing', () => {
  for (const name of ['guardScript', 'guardReaders', 'summonAction']) assert.equal(name in MenuModel, false, name);
  assert.equal(/bash|pacman|GUARD_/.test(fs.readFileSync(path.join(shellDir, 'menu/MenuModel.js'), 'utf8').replace(/^\/\/.*$/gm, '')), false);
});

test('bar button: draws the shared MirrorOS symbol path in the accent, on the pixel grid, no Arch glyph', () => {
  const button = fs.readFileSync(path.join(shellDir, 'bar/widgets/MenuButton.qml'), 'utf8');
  const svg = fs.readFileSync(path.join(shellDir, '../../visual/branding/mirroros-symbol.svg'), 'utf8');
  const symbol = svg.match(/ d="([^"]+)"/)[1];
  assert.equal(button.match(/PathSvg \{ path: "([^"]+)" \}/)[1], symbol);
  assert.doesNotMatch(button, /\\uf303/i);
  assert.match(button, /fillColor: button\.active && button\.useActiveColor \? button\.activeColor : Commons\.Color\.accent/);
  // Whole physical-pixel blocks from the bar window's ratio; Screen reports a
  // rounded-up ratio under fractional scaling.
  assert.match(button, /blockPx: Math\.max\(1, Math\.ceil\(Style\.bar\.iconSize \* dpr \/ 8\)\)/);
  assert.match(button, /button\.QsWindow\.window/);
  assert.doesNotMatch(button, /Screen\.devicePixelRatio/);
  assert.match(button, /function onAfterAnimating\(\) \{ symbol\.snap\(\) \}/);
});

const upstream = process.argv[2];
if (upstream) {
  test('extraction boundary: identical to upstream outside the removed block', () => {
    const original = fs.readFileSync(path.join(upstream, 'shell/plugins/menu/MenuModel.js'), 'utf8').split('\n');
    const start = original.findIndex(line => line.startsWith('// Commands a `checked:`'));
    const end = original.findIndex(line => line.startsWith('// Multi-select requests'));
    assert.ok(start > 0 && end > start);
    const expected = [...original.slice(0, start), ...original.slice(end)]
      .filter(line => !/^\s+(summonAction|guardReaders|guardScript): /.test(line));
    const actual = fs.readFileSync(path.join(shellDir, 'menu/MenuModel.js'), 'utf8').split('\n')
      .filter((line, index) => !(index < 5 && line.startsWith('//')));
    assert.deepEqual(actual, expected);
  });
}
console.log(`All ${passed} checks passed`);
