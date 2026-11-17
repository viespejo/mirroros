#!/usr/bin/env node
// Application visibility and icon refresh regressions; no desktop required.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { test } from 'node:test';
import AppSearch from '../../../../capabilities/desktop/shell/services/AppSearch.js';

const source = fs.readFileSync(new URL('../../../../capabilities/desktop/shell/services/AppLibrary.qml', import.meta.url), 'utf8');
const hides = fs.readFileSync(new URL('../../../../capabilities/desktop/shell/launcher.hides', import.meta.url), 'utf8');
const body = name => source.match(new RegExp(`function ${name}\\([^)]*\\) \\{([\\s\\S]*?)\\n  \\}`))[1];
const isHiddenEntry = new Function('root', 'entry', body('isHiddenEntry'));
const loadConfiguredHides = new Function('root', 'rawText', body('loadConfiguredHides'));
const root = {
  configuredHiddenEntryIds: {}, desktopHiddenEntryIds: { 'vendor-hidden': true },
  normalizeDesktopId: new Function('id', body('normalizeDesktopId')), appsChanged() {},
};
loadConfiguredHides(root, hides);

test('icon refresh requests during a scan queue another scan', () => {
  const refresh = new Function('root', 'iconIndexScan', body('refreshIcons'));
  const state = { iconRescanQueued: false };
  const process = { running: false };
  refresh(state, process);
  assert.equal(process.running, true);
  assert.equal(state.iconRescanQueued, false);
  refresh(state, process);
  assert.equal(state.iconRescanQueued, true);
  assert.match(source, /if \(root.iconRescanQueued\) \{\s*root.iconRescanQueued = false\s*root.refreshIcons\(\)/);
  assert.match(source, /onTriggered: root.refreshIcons\(\)/);
  assert.match(source, /command: \["gsettings", "monitor", "org.gnome.desktop.interface", "icon-theme"\]/);
});

test('indexed icons retain the first candidate and use a file-signature cache key', () => {
  const index = new Function('root', 'Util', 'path', body('indexIconLine'));
  const state = { pendingIconIndex: {} };
  const Util = { fileUrl: value => 'file://' + value.replaceAll(' ', '%20') };
  index(state, Util, '123:456:20\t/icons/theme name/foot.svg');
  index(state, Util, '999:456:20\t/icons/fallback/foot.png');
  index(state, Util, 'invalid');
  assert.deepEqual(state.pendingIconIndex, { foot: 'file:///icons/theme%20name/foot.svg?v=123%3A456%3A20' });
  const iconSource = new Function('root', 'Quickshell', 'Util', 'icon', body('iconSource'));
  const qs = { iconPath: name => 'image://icon/' + name };
  assert.equal(iconSource({ iconIndex: state.pendingIconIndex }, qs, Util, 'foot'), state.pendingIconIndex.foot);
  assert.equal(iconSource({ iconIndex: {} }, qs, Util, 'unknown'), 'image://icon/unknown');
  assert.equal(iconSource({ iconIndex: {} }, qs, Util, '/absolute/icon.svg'), 'file:///absolute/icon.svg');
});

test('launcher hides only the three approved technical entries', () => {
  assert.deepEqual(Object.keys(root.configuredHiddenEntryIds).sort(), ['foot-server', 'footclient', 'uuctl']);
  for (const id of Object.keys(root.configuredHiddenEntryIds)) assert.equal(isHiddenEntry(root, { id }), true);
});

test('configured hide-list loader normalizes ids, replaces state and emits changes', () => {
  let changes = 0;
  const state = { ...root, configuredHiddenEntryIds: {}, appsChanged() { changes++; } };
  loadConfiguredHides(state, ' extra.desktop\r\n\nextra\nother\n');
  assert.deepEqual(state.configuredHiddenEntryIds, { extra: true, other: true });
  assert.equal(isHiddenEntry(state, { id: 'extra' }), true);
  loadConfiguredHides(state, 'replacement');
  assert.deepEqual(state.configuredHiddenEntryIds, { replacement: true });
  loadConfiguredHides(state, '');
  assert.deepEqual(state.configuredHiddenEntryIds, {});
  assert.equal(changes, 3);
});

test('external list retains upstream load/failure handlers and explicitly reloads on changes', () => {
  assert.match(source, /FileView \{\s*path: Quickshell.shellPath\("launcher.hides"\)\s*watchChanges: true\s*printErrors: false\s*onLoaded: root.loadConfiguredHides\(text\(\)\)\s*onFileChanged: reload\(\)\s*onLoadFailed: root.loadConfiguredHides\(""\)/);
});

test('regular Foot, Omasnap and unrelated applications remain visible', () => {
  for (const id of ['foot', 'omasnap', 'other-app', 'uuctl-extra', 'footclient-extra']) {
    assert.equal(isHiddenEntry(root, { id }), false);
  }
  assert.equal(isHiddenEntry(root, null), false);
});

test('Omasnap desktop keywords preserve descriptive searches after renaming', () => {
  const recipe = fs.readFileSync(new URL('../../../../capabilities/desktop/compositor/providers/hyprland/omasnap/PKGBUILD', import.meta.url), 'utf8');
  const keywords = recipe.match(/^\+Keywords=(.+)$/m)[1].split(';').filter(Boolean);
  const entry = { id: 'omasnap', name: 'Omasnap', keywords };
  for (const query of ['omasnap', 'screenshot', 'capture', 'screen capture']) {
    assert.deepEqual(AppSearch.sortedEntries([entry], query).map(row => row.entry.id), ['omasnap']);
  }
  assert.equal(AppSearch.entryName(entry), 'Omasnap');
});

test('desktop visibility filters still apply independently of launcher policy', () => {
  assert.equal(isHiddenEntry(root, { id: 'vendor-hidden' }), true);
  assert.equal(isHiddenEntry({ ...root, desktopHiddenEntryIds: {} }, { id: 'vendor-hidden' }), false);
  assert.equal(isHiddenEntry({ ...root, desktopHiddenEntryIds: {} }, { id: 'uuctl' }), true);
  assert.match(source, /AppSearch.sortedEntries\(values, query, function\(entry\) \{ return root.isHiddenEntry\(entry\) \}\)/);
  assert.match(source, /Quickshell.execDetached\(\["uwsm", "app", "--", id \+ "\.desktop"\]\)/);
});
