// Omasnap v1.26.2, commit 6150151846b0ddc2ca8e6b107324de8b0c7240ae.
// On recipe updates, review src/chrome-theme.cpp and rerun with MIRROROS_OMASNAP_SOURCE.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

const root = new URL('../../../../', import.meta.url);
const provider = new URL('capabilities/desktop/compositor/providers/hyprland/omasnap/', root);
const theme = new URL('capabilities/visual/theme/default/', root);
const upstream = process.env.MIRROROS_OMASNAP_SOURCE;
const sourceHash = 'e80656676dc46e87c8f82534ccd40cf3b7f748e2b337e32b766820adf7b0c835';
function values(file) {
  let section = '';
  const result = {};
  for (const line of readFileSync(file, 'utf8').split('\n')) {
    const header = line.match(/^\[([^\]]+)\]$/);
    if (header) section = header[1] + '.';
    const value = line.match(/^([\w-]+) = (?:"([^"]+)"|([\d.]+))$/);
    if (value) result[section + value[1]] = value[2] ?? Number(value[3]);
  }
  return result;
}
const palette = { ...values(new URL('colors.toml', theme)), ...values(new URL('shell.toml', theme)) };
// Each absent key has the v1.26.2 fallback, not an invented theme requirement.
const fallbacks = {
  'popups.background': 'background', 'popups.text': 'foreground', 'popups.background-alpha': 1,
  light_foreground: 'foreground', accent: 'foreground', orange: 'accent',
  'controls.normal-color': 'foreground', 'controls.hover-cursor-color': 'foreground',
  'controls.selected-color': 'foreground', 'controls.normal-fill-alpha': 0.04,
  'controls.hover-cursor-fill-alpha': 0.08, 'controls.selected-fill-alpha': 0.18,
  'controls.normal-border': 'controls.normal-color', 'controls.normal-border-alpha': 0.4,
  'controls.hover-cursor-border': 'controls.hover-cursor-color', 'controls.hover-cursor-border-alpha': 0.25,
  'controls.selected-border': 'controls.selected-color', 'controls.selected-border-alpha': 1,
  'popups.border': 'hyprland.active-border', 'hyprland.active-border': 'hyprland_active_border',
  hyprland_active_border: 'accent', 'popups.border-alpha': 1,
  // Upstream inactive border: foreground with alpha 75/255.
  hyprland_inactive_border: 'foreground',
  'tooltip.background': 'background', 'tooltip.background-alpha': 0.97,
  'tooltip.text': 'foreground', 'tooltip.border': 'foreground', 'tooltip.border-alpha': 1,
};
function resolve(key, seen = new Set()) {
  assert.ok(!seen.has(key), `cyclic palette reference: ${key}`);
  seen.add(key);
  const value = palette[key] ?? fallbacks[key];
  assert.notEqual(value, undefined, `undeclared key without fallback: ${key}`);
  if (typeof value === 'number' || /^#[\da-f]{6}$/i.test(value)) return value;
  return resolve(value, seen);
}

test('Omasnap recipe remains pinned to the reviewed theme consumer', () => {
  const recipe = readFileSync(new URL('PKGBUILD', provider), 'utf8');
  assert.match(recipe, /^pkgver=1\.26\.2$/m);
  assert.match(recipe, /6150151846b0ddc2ca8e6b107324de8b0c7240ae/);
  assert.match(recipe, /e173edd4f2e797273c967513f24c360b6f00733792b9708757a82c39fbc43bf9/);
});

test('Omasnap required palette and every optional chrome key resolve without controls additions', () => {
  for (const key of ['background', 'foreground', ...Object.keys(fallbacks)]) {
    const value = resolve(key);
    if (key.endsWith('-alpha')) assert.ok(typeof value === 'number' && value >= 0 && value <= 1, key);
    else assert.match(value, /^#[\da-f]{6}$/i, key);
  }
  assert.doesNotMatch(readFileSync(new URL('shell.toml', theme), 'utf8'), /^\[controls\]/m);
});

test('Omasnap HOME-based bridge exposes colors and shell settings even with a custom state home', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-omasnap-theme-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const home = join(dir, 'home');
  const state = join(home, 'custom-state');
  mkdirSync(join(state, 'mirroros/current'), { recursive: true });
  symlinkSync(theme.pathname, join(state, 'mirroros/current/theme'));
  const bin = join(dir, 'bin');
  mkdirSync(bin);
  writeFileSync(join(bin, 'systemctl'), '#!/usr/bin/bash\nprintf "XDG_STATE_HOME=%s\\n" "$TEST_STATE"\n', { mode: 0o755 });
  const result = spawnSync('bash', [new URL('capabilities/visual/theme/omarchy-bridge', root).pathname, 'apply', '--session'], {
    encoding: 'utf8', env: { PATH: bin + ':' + process.env.PATH, HOME: home, TEST_STATE: state },
  });
  assert.equal(result.status, 0, result.stderr);
  for (const file of ['colors.toml', 'shell.toml']) {
    const bridge = join(home, '.local/state/omarchy/current/theme', file);
    assert.ok(existsSync(bridge), file);
    assert.equal(realpathSync(bridge), new URL(file, theme).pathname);
  }
});

test('Omasnap upstream theme paths and keys match the pinned source', { skip: !upstream && 'set MIRROROS_OMASNAP_SOURCE' }, () => {
  const source = readFileSync(join(upstream, 'src/chrome-theme.cpp'), 'utf8');
  assert.equal(createHash('sha256').update(source).digest('hex'), sourceHash, 'review source changes and update the contract');
  assert.match(source, /\.local\/state\/omarchy\/current\/theme/);
  for (const file of ['colors.toml', 'shell.toml']) assert.ok(source.includes(`QStringLiteral("${file}")`));
  const begin = source.indexOf('ChromeTheme loadChromeTheme(');
  const consumer = source.slice(begin, source.indexOf('ChromeThemeWatcher::ChromeThemeWatcher(', begin));
  const keys = [...consumer.matchAll(/QStringLiteral\("([^\"]+)"\)/g)].map(match => match[1])
    .filter(key => !key.endsWith('.toml'));
  assert.deepEqual([...new Set(keys)].sort(), ['background', 'foreground', ...Object.keys(fallbacks)].sort());
});
