#!/usr/bin/env node
// Application visibility policy regressions; no desktop required.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { test } from 'node:test';

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

test('desktop visibility filters still apply independently of launcher policy', () => {
  assert.equal(isHiddenEntry(root, { id: 'vendor-hidden' }), true);
  assert.equal(isHiddenEntry({ ...root, desktopHiddenEntryIds: {} }, { id: 'vendor-hidden' }), false);
  assert.equal(isHiddenEntry({ ...root, desktopHiddenEntryIds: {} }, { id: 'uuctl' }), true);
  assert.match(source, /AppSearch.sortedEntries\(values, query, function\(entry\) \{ return root.isHiddenEntry\(entry\) \}\)/);
  assert.match(source, /Quickshell.execDetached\(\["uwsm", "app", "--", id \+ "\.desktop"\]\)/);
});
