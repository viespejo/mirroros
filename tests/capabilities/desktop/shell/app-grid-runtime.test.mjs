#!/usr/bin/env node
// Isolated real-QML grid/model checks; no input injection or application launch.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';

const available = fs.existsSync('/usr/bin/qs') && !!process.env.WAYLAND_DISPLAY;

test('real Apps grid retains equal delegates, bounded scroll and stable selection', { skip: !available }, t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mirroros-app-grid-runtime-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const copy = path.join(dir, 'qs');
  fs.cpSync('capabilities/desktop/shell', copy, { recursive: true });
  for (const [file, text] of [
    ['menu/AppGrid.qml', '  readonly property var testGrid: grid\n'],
    ['menu/Menu.qml', '  readonly property var testGrid: appsGrid.testGrid\n'],
  ]) {
    const filePath = path.join(copy, file);
    fs.writeFileSync(filePath, fs.readFileSync(filePath, 'utf8').replace('  id: root\n', '  id: root\n' + text));
  }
  fs.writeFileSync(path.join(copy, 'shell.qml'), `import QtQuick
import Quickshell
import "menu"
ShellRoot {
  id: fixture
  property int phase: 0
  property real savedY: 0
  property int savedLayout: 0
  property string savedId: ""
  property var savedCell: null
  function check(ok, message) {
    if (!ok) throw new Error("FAIL " + message)
  }
  property QtObject library: QtObject {
    property int count: 80
    property string hiddenId: ""
    property string unavailableReason: ""
    property int launches: 0
    signal appsChanged()
    function sortedEntries(query) {
      var result = []
      for (var i = 0; i < count; i++) {
        var number = String(i).padStart(3, "0")
        if ("app" + number !== hiddenId)
          result.push({ entry: { id: "app" + number, name: "App " + number, icon: "application-x-executable" } })
      }
      return result
    }
    function entryName(entry) { return entry.name }
    function entrySubtext(entry) { return "" }
    function refreshIcons() {}
    function iconSource(icon) { return Quickshell.iconPath(icon, true) }
    function launch(id) { launches++ }
  }
  Menu { id: menu; appLibrary: fixture.library }
  Timer {
    interval: 250
    running: true
    repeat: true
    onTriggered: {
      try {
        var grid = menu.testGrid
        switch (fixture.phase++) {
        case 0:
          menu.openExistingMenu("apps")
          break
        case 1:
          check(grid.count === 80, "catalog size")
          menu.selectGrid(60)
          break
        case 2:
          fixture.savedY = grid.contentY
          fixture.savedId = menu.selectedId
          fixture.savedLayout = menu.layoutSerial
          fixture.savedCell = grid.itemAtIndex(menu.selectedIndex)
          check(savedY > 0 && savedCell !== null, "scrolled cell")
          library.appsChanged()
          break
        case 3:
          check(grid.contentY === savedY, "unchanged catalog scroll")
          check(grid.itemAtIndex(menu.selectedIndex) === savedCell, "unchanged catalog cell identity")
          check(menu.layoutSerial === savedLayout, "unchanged catalog model")
          library.count = 81
          library.appsChanged()
          break
        case 4:
          check(grid.contentY === savedY, "changed catalog scroll")
          check(menu.selectedId === savedId && menu.cursorActive, "selected identity")
          library.hiddenId = "app060"
          library.appsChanged()
          break
        case 5:
          check(grid.contentY === savedY, "removed app scroll")
          check(!menu.cursorActive, "removed selection disarmed")
          menu.activateSelected()
          check(library.launches === 0, "no accidental launch")
          menu.setFilter("App 07")
          menu.setFilter("App 00")
          break
        case 6:
          check(grid.contentY === grid.originY, "search resets scroll")
          menu.setFilter("")
          break
        case 7:
          menu.selectGrid(60)
          break
        case 8:
          library.count = 1
          library.appsChanged()
          break
        case 9:
          check(grid.contentY === grid.originY, "short catalog clamps scroll")
          fixture.savedLayout = menu.layoutSerial
          fixture.savedCell = grid.itemAtIndex(0)
          menu.opened = false
          menu.openExistingMenu("apps")
          break
        case 10:
          check(grid.contentY === grid.originY, "reopen resets scroll")
          check(menu.layoutSerial === savedLayout, "reopen reuses equal model")
          check(grid.itemAtIndex(0) === savedCell, "reopen retains cell identity")
          console.log("PASS real Apps model, cell identity, scroll, selection and reopen")
          Qt.quit()
        }
      } catch (error) {
        console.error(String(error))
        Qt.quit()
      }
    }
  }
}
`);
  const result = spawnSync('/usr/bin/qs', ['-p', copy], {
    env: { ...process.env, QML_IMPORT_PATH: dir }, encoding: 'utf8', timeout: 15000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /FAIL |TypeError|ReferenceError|Cannot assign|Error loading/);
  assert.match(output, /PASS real Apps model, cell identity, scroll, selection and reopen/);
});
