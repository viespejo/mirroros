#!/usr/bin/env node
// Apps launcher geometry and shared-route regressions; no desktop required.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const shell = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../../capabilities/desktop/shell');
const menu = fs.readFileSync(path.join(shell, 'menu/Menu.qml'), 'utf8');
const grid = fs.readFileSync(path.join(shell, 'menu/AppGrid.qml'), 'utf8');
const body = name => menu.match(new RegExp(`function ${name}\\([^)]*\\) \\{([\\s\\S]*?)\\n  \\}`))[1];
const expression = (source, name) => source.match(new RegExp(`(?:readonly )?property (?:int|bool) ${name}: (.*)`))[1];

function geometry(width, height, scale = 1) {
  const Style = {
    fontScale: scale, space: value => Math.round(value * scale),
    spacing: { sm: 8 * scale, lg: 16 * scale, md: 12 * scale, xl: 24 * scale, panelPadding: 18 * scale, controlPaddingY: 6 * scale },
    font: { heading: 16 * scale },
  };
  const root = { screenWidth: width, screenHeight: height };
  for (const name of ['iconSize', 'labelHeight', 'cellGutter', 'cellPadding', 'cellWidth', 'cellHeight', 'inset', 'headerHeight', 'headerSpacing', 'screenMargin', 'cardWidth', 'columns', 'gridWidth', 'cardHeight', 'viewportHeight']) {
    root[name] = new Function('root', 'Style', 'labelMetrics', 'screenWidth', 'screenHeight', `return ${expression(grid, name)}`)(root, Style, { height: 16 * scale }, width, height);
  }
  return root;
}

test('Apps uses the same grid for direct and tree routes, but not selectors', () => {
  const appsView = new Function('root', `return ${expression(menu, 'appsView')}`);
  assert.equal(appsView({ activeMenu: 'apps', dmenuActive: false }), true);
  assert.equal(appsView({ activeMenu: 'apps', dmenuActive: true }), false);
  assert.equal(appsView({ activeMenu: 'root', dmenuActive: false }), false);
  const width = new Function('root', 'appsGrid', 'Style', 'panel', `return ${expression(menu, 'cardWidth')}`);
  const g = geometry(1920, 1080);
  assert.equal(width({ appsView: true }, g, {}, {}), g.cardWidth);
  assert.ok(g.cardWidth > 300);
  assert.equal(g.columns, 7);
  assert.equal(g.viewportHeight, 4 * g.cellHeight);
});

test('Omarchy grid dimensions stay screen-bounded at common sizes and scales', () => {
  for (const [width, height, scale] of [[1920, 1080, 1], [1280, 720, 1], [800, 600, 1], [960, 540, 1.5], [640, 480, 1]]) {
    const g = geometry(width, height, scale);
    assert.ok(g.cardWidth <= width - 2 * g.screenMargin);
    assert.ok(g.cardHeight <= height - 2 * g.screenMargin);
    assert.ok(g.columns >= 1 && g.columns <= 7);
    assert.ok(g.gridWidth <= g.cardWidth - 2 * g.inset);
    assert.ok(g.viewportHeight > 0);
  }
});

test('Apps stays centered through navigation and filtering without list scrims or row peeks', () => {
  assert.match(body('setActiveMenu'), /if \(id === "apps" \|\| root.appsView\) panel.cardTop = -1/);
  assert.match(menu, /effectiveCardTop: !root.appsView && cardTop >= 0 \? cardTop : centeredTop/);
  assert.match(menu, /if \(shown && !root.appsView && cardTop < 0\)/);
  assert.match(menu, /visibleRowsHeight: root.appsView \? appsGrid.viewportHeight/);
  assert.equal((menu.match(/visible: !root.appsView && opacity > 0/g) || []).length, 2);
  const calls = [];
  new Function('root', 'appsGrid', 'displayModel', body('revealCursor'))({ appsView: true, selectedIndex: 9 }, { reveal: index => calls.push(index) }, { count: 10 });
  assert.deepEqual(calls, [9]);
});

test('grid selection clamps at either end and preserves the stable app identity', () => {
  const ids = ['app.a', 'app.b', 'app.c', 'app.d', 'app.e', 'app.f', 'app.g', 'app.h'];
  const select = new Function('root', 'displayModel', 'delta', body('selectGrid'));
  let reveals = 0;
  const root = { selectedIndex: 0, disarmPointer() {}, revealCursor() { reveals++; } };
  const model = { count: ids.length, get: index => ({ itemId: ids[index] }) };
  select(root, model, 7);
  assert.equal(root.selectedIndex, 7);
  assert.equal(root.selectedId, 'app.h');
  select(root, model, 1);
  assert.equal(root.selectedIndex, 7);
  select(root, model, -7);
  assert.equal(root.selectedId, 'app.a');
  select(root, model, -1);
  assert.equal(root.selectedIndex, 0);
  assert.equal(root.cursorActive, true);
  assert.equal(reveals, 4);
  select(root, { count: 0 }, 1);
  assert.equal(reveals, 4);
  assert.match(menu, /root.selectGrid\(-appsGrid.columns\)/);
  assert.match(menu, /root.selectGrid\(appsGrid.columns\)/);
  assert.match(grid, /maximumLineCount: 2/);
  assert.match(grid, /onClicked: root.menu.activateIndex\(cell.index, true\)/);
});
