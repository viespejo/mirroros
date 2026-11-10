import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

// Delivered shell code and owned hardware commands must not call Omarchy executables, Omarchy IPC, its media
// service or OMARCHY_PATH. Comments are ignored; legacy data identifiers kept from upstream are allowlisted.
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
const roots = ['capabilities/desktop/shell', 'capabilities/system/audio', 'capabilities/system/bluetooth',
  'capabilities/system/network', 'capabilities/system/power', 'capabilities/system/vpn'];
const singles = ['capabilities/desktop/compositor/providers/hyprland/display'];

const allowed = new Map([
  // Bar widget ids kept as legacy data names in defaults.json, Bar.qml and widget moduleName values.
  ...['menu', 'workspaces', 'indicators', 'clock', 'tray', 'keyboard-layout', 'bluetooth', 'network', 'audio',
    'monitor', 'power', 'dropbox'].map(id => [`omarchy.${id}`, 'legacy bar widget id']),
  // First-party service ids resolved by shell.qml (notification panel and OSD).
  ['omarchy.notifications', 'legacy service id'],
  ['omarchy.osd', 'legacy service id'],
  // Layer-shell namespaces of the copied shared panel container.
  ['omarchy-keyboard-panel', 'legacy layer namespace'],
  ['omarchy-keyboard-panel-dismiss', 'legacy layer namespace'],
  // Notification application name and hints accepted from notification senders.
  ['omarchy-action', 'legacy notification app name'],
  ['omarchy-exec-argv', 'legacy notification hint'],
  ['omarchy-glyph', 'legacy notification hint'],
]);
// Installed upstream license destinations (for example /usr/share/mirroros/hardware/licenses/omarchy-audio).
const licensePath = /\/licenses\/omarchy-[a-z0-9-]+/g;
const token = /omarchy[-.][A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*|ShellIpc|IpcRegistry|OMARCHY_PATH/g;

const walk = dir => readdirSync(dir, { withFileTypes: true }).flatMap(entry =>
  entry.isDirectory() ? walk(path.join(dir, entry.name)) : [path.join(dir, entry.name)]);
const delivered = file => !file.endsWith('.md') && !/LICENSE/.test(path.basename(file));

function codeLines(file, text) {
  const slashes = /\.(qml|js|mjs)$/.test(file), json = file.endsWith('.json');
  return text.split('\n').map((line, index) => {
    const trimmed = line.trim();
    if (json) return [index + 1, line];
    if (slashes) {
      if (/^(\/\/|\/\*|\*)/.test(trimmed)) return [index + 1, ''];
      return [index + 1, line.replace(/\s\/\/\s.*$/, '')];
    }
    if (trimmed.startsWith('#')) return [index + 1, ''];
    return [index + 1, line.replace(/\s#\s.*$/, '')];
  });
}

export function couplings(file, text) {
  const found = [];
  for (const [line, code] of codeLines(file, text))
    for (const match of code.replace(licensePath, '').matchAll(token))
      if (!allowed.has(match[0])) found.push(`${file}:${line}: ${match[0]}`);
  return found;
}

test('the detector reports Omarchy runtime coupling outside comments', () => {
  assert.deepEqual(couplings('x.qml', 'ShellIpc {\n// ShellIpc\nrun(["omarchy-shell"]) // omarchy.media\n'),
    ['x.qml:1: ShellIpc', 'x.qml:3: omarchy-shell']);
  assert.deepEqual(couplings('x', 'exec omarchy-audio-switch\n# omarchy-audio-switch\n'),
    ['x:1: omarchy-audio-switch']);
  assert.deepEqual(couplings('x.js', 'summon("omarchy.media"); env("OMARCHY_PATH")\n'),
    ['x.js:1: omarchy.media', 'x.js:1: OMARCHY_PATH']);
  assert.deepEqual(couplings('x', 'cfg_tracked_file a /usr/share/mirroros/hardware/licenses/omarchy-audio\n'), []);
});

test('delivered shell code and owned commands carry no Omarchy runtime coupling', () => {
  const files = [...roots.flatMap(root => walk(path.join(repo, root))), ...singles.map(file => path.join(repo, file))]
    .filter(delivered);
  assert.ok(files.length > 50);
  const found = files.flatMap(file => couplings(path.relative(repo, file), readFileSync(file, 'utf8')));
  assert.deepEqual(found, []);
});
