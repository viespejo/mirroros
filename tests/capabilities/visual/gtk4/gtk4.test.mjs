import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { chmodSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const theme = join(root, 'capabilities/visual/theme');
const runtime = join(root, 'capabilities/visual/gtk4');
const read = path => readFileSync(path, 'utf8');
const layers = ['base.css', 'typography.css', 'apps/pavucontrol.css'];
const sha256 = data => createHash('sha256').update(data).digest('hex');

function files(path) {
  return readdirSync(path, { withFileTypes: true }).flatMap(entry =>
    entry.isDirectory() ? files(join(path, entry.name)) : [join(path, entry.name)]);
}

function temporary(t, name) {
  const dir = mkdtempSync(join(tmpdir(), name));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return dir;
}

test('GTK4 palette matches the reviewed theme and shared layers contain no literal colors', () => {
  const native = new Map([...read(join(theme, 'default/colors.toml')).matchAll(/^([a-z_]+) = "(#[a-f0-9]{6})"$/gim)]
    .map(match => [match[1], match[2].toLowerCase()]));
  const css = read(join(theme, 'default/gtk-4.0.css'));
  const colors = new Map([...css.matchAll(/^@define-color (\w+) ([^;]+);$/gm)].map(match => [match[1], match[2]]));
  const roles = { background: 'background', surface: 'dark_background', deep: 'darker_background', raised: 'lighter_background',
    selection: 'selection', border: 'muted', foreground: 'foreground', text: 'light_foreground', bright: 'bright_foreground',
    accent: 'accent', secondary: 'dark_foreground', error: 'red', warning: 'bright_yellow', success: 'green' };
  for (const [role, key] of Object.entries(roles)) assert.equal(colors.get(`mirroros_${role}`), native.get(key), role);
  assert.equal(colors.get('mirroros_dim'), '#7e8467', 'reviewed additional disabled-text color');
  for (const layer of layers) {
    const text = read(join(runtime, layer));
    const declarations = [...text.matchAll(/(^[ \t]*[-\w]+:\s*|^@define-color \w+ )([^;\n]+)/gm)].map(match => match[2]).join('\n');
    assert.doesNotMatch(declarations, /#[a-f0-9]{3,8}\b|rgba?\(\s*\d|\b(?:white|black)\b/i, layer);
    assert.doesNotMatch(text, /@lab_|\/tmp\//i, layer);
    for (const match of text.matchAll(/@(mirroros_\w+)/g)) assert.ok(colors.has(match[1]), `${layer}: ${match[1]}`);
  }
  for (const path of files(runtime)) assert.doesNotMatch(read(path), /\/tmp\/mirroros-|MirrorOS-Widgets-Lab|MirrorOS-Pavucontrol-Lab/, path);
});

test('the theme loads only the palette, Osaka base, typography and pavucontrol adapter', () => {
  const entry = join(runtime, 'share/themes/MirrorOS/gtk-4.0/gtk.css');
  const imports = [...read(entry).matchAll(/@import url\("([^"]+)"\);/g)].map(match => match[1]);
  assert.equal(imports[0], '/usr/share/mirroros/themes/default/gtk-4.0.css');
  assert.deepEqual(imports.slice(1).map(path => resolve(dirname(entry), path)), layers.map(path => join(runtime, path)));
  for (const old of ['control-states.css', 'focus-states.css', 'chrome.css']) assert.equal(existsSync(join(runtime, old)), false);
  const font = read(join(runtime, 'typography.css'));
  assert.match(font, /font-family: "JetBrains Mono", "JetBrainsMono Nerd Font", monospace;/);
  assert.match(font, /font-size: 13px;/);
  const app = read(join(runtime, 'apps/pavucontrol.css'));
  const selectors = [...app.matchAll(/^([^\n{]+) \{/gm)].map(match => match[1]);
  assert.deepEqual(selectors, [
    'window.pavucontrol-window button.toggle:checked:not(:disabled)',
    'window.pavucontrol-window button.toggle:checked:hover:not(:disabled)',
    'window.pavucontrol-window button.toggle:checked:backdrop:not(:disabled)',
  ]);
  assert.equal((app.match(/background-color: @mirroros_accent;/g) || []).length, 2);
  assert.match(app, /border-color: @mirroros_osaka_029;/);
  assert.doesNotMatch(app, /@import|opacity|icon-source|outline/);
});

test('expanding palette tokens reconstructs the pinned Osaka CSS byte for byte', () => {
  const palette = new Map([...read(join(theme, 'default/gtk-4.0.css')).matchAll(/^@define-color (mirroros_osaka_\d+) ([^;]+);$/gm)]
    .map(match => [match[1], match[2]]));
  assert.equal(palette.size, 114);
  const original = read(join(runtime, 'base.css')).replace(/^\/\* Adapted[\s\S]*?\*\/\n/, '')
    .replace(/@(mirroros_osaka_\d+)/g, (_, name) => {
      assert.ok(palette.has(name), name);
      return palette.get(name);
    });
  assert.equal(sha256(original), 'b6496357400b151588e63aab6048d5b998083aa7a6cf9db60b26ce83f1d52596');
  for (const match of original.matchAll(/url\("([^"]+)"\)/g)) {
    assert.ok(match[1].startsWith('assets/'), match[1]);
    assert.ok(existsSync(join(runtime, match[1])), match[1]);
  }
  const assets = files(join(runtime, 'assets')).sort();
  assert.equal(assets.length, 182);
  const inventory = assets.map(path => `${sha256(readFileSync(path))}  ${path.slice(join(runtime, 'assets').length + 1)}`).join('\n') + '\n';
  assert.equal(sha256(inventory), '7e66311c847d7860b96de009a6ee281efdf35fba667fb6c5e11c8f0183f53514');
  const licenses = {
    'AUTHORS.yaru': 'eb5e3c27ba894f34d2cab78093fb1bf54cfba7da29e5febf70416e67584db30b',
    'COPYING.yaru': 'cb4392586efcf6ade8315f08e392b3eaf2ab37565f3c6ce8ef03aa3d76ed23ff',
    'LICENSE_CCBYSA.yaru': '7a8af68d18de818e54697230278c0ade42e6bac15d4116ef9560f74176431118',
    'LICENSE.osaka-jade': '5ce556535ed37e7061075c5ec86afc07a5199c804db70b1814795e7002980129',
  };
  for (const [name, hash] of Object.entries(licenses)) assert.equal(sha256(readFileSync(join(runtime, 'licenses', name))), hash, name);
});

test('application icon aliases are neutral self-contained SVGs, without copied system icon themes', () => {
  const aliases = JSON.parse(read(join(runtime, 'icon-aliases.json')));
  const names = Object.values(aliases).flat();
  assert.equal(names.length, 25);
  assert.equal(new Set(names).size, names.length);
  const iconRoot = join(runtime, 'share/icons');
  for (const group of Object.values(aliases)) {
    const canonical = read(join(iconRoot, `Adwaita/symbolic/apps/${group[0]}-symbolic.svg`));
    assert.match(canonical, /fill="currentColor"/);
    assert.doesNotMatch(canonical, /#[a-f0-9]{3,8}\b|<script|href=|<image|<style/i);
    for (const name of group) {
      assert.equal(read(join(iconRoot, `Adwaita/16x16/apps/${name}.svg`)), canonical);
      assert.equal(read(join(iconRoot, `Adwaita/scalable/apps/${name}.svg`)), canonical);
      assert.equal(read(join(iconRoot, `Adwaita/symbolic/apps/${name}-symbolic.svg`)), canonical);
      if (aliases.generic.includes(name)) assert.equal(read(join(iconRoot, `Adwaita/scalable/mimetypes/${name}.svg`)), canonical);
    }
  }
  const icons = files(iconRoot);
  assert.equal(icons.length, 82);
  assert.ok(icons.every(path => path.endsWith('.svg')));
  assert.equal(icons.filter(path => path.endsWith('/index.theme')).length, 0);
  assert.match(read(join(iconRoot, 'Adwaita/symbolic/status/emblem-default-symbolic.svg')), /fill="currentColor"/);
  assert.equal(existsSync(join(runtime, 'theme.name')), false);
  assert.match(read(join(runtime, 'STRATA-LICENSE')), /Copyright \(c\) 2026 LGSE Ltd\./);
  assert.equal(createHash('sha256').update(readFileSync(join(runtime, 'STRATA-LICENSE'))).digest('hex'),
    '9f7b0c37b47dc21925dae3176ebb065c4a8581331fbacb1ca939acc23a82a640');
});

test('GTK4 resolution accepts only its trusted default palette, never a user-selected CSS file', (t) => {
  const dir = temporary(t, 'mirroros-gtk4-resolve-');
  const anchor = join(dir, 'root');
  const state = join(dir, 'state');
  const product = join(anchor, 'usr/share/mirroros/themes/default');
  mkdirSync(product, { recursive: true });
  mkdirSync(join(state, 'mirroros/current'), { recursive: true });
  writeFileSync(join(product, 'colors.toml'), 'palette');
  const palette = join(product, 'gtk-4.0.css');
  writeFileSync(palette, 'reviewed colors');
  symlinkSync('/unknown/untrusted-theme', join(state, 'mirroros/current/theme'));
  const run = () => spawnSync('bash', [join(theme, 'resolve-current'), anchor, state, String(process.getuid()), 'gtk4'], { encoding: 'utf8' });
  let result = run();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, '/usr/share/mirroros/themes/default/gtk-4.0.css\n');
  assert.match(result.stderr, /Invalid or missing theme selection/);
  chmodSync(palette, 0o666);
  assert.equal(run().status, 4);
  rmSync(palette);
  symlinkSync('colors.toml', palette);
  assert.equal(run().status, 4);
  rmSync(palette);
  assert.equal(run().status, 4);
});

function launcherFixture(t) {
  const dir = temporary(t, 'mirroros-gtk4-launch-');
  const product = join(dir, 'themes');
  const staged = join(dir, 'gtk4');
  const home = join(dir, 'home');
  cpSync(runtime, staged, { recursive: true });
  mkdirSync(join(product, 'default'), { recursive: true });
  mkdirSync(join(home, 'config'), { recursive: true });
  writeFileSync(join(home, 'config/pavucontrol.ini'), 'private existing preferences\n');
  writeFileSync(join(product, 'resolve-current'), `#!/usr/bin/bash\nprintf '%s\\n' '${product}/default/gtk-4.0.css'\nexit "\u0024{TEST_RESOLVER_STATUS:-0}"\n`);
  writeFileSync(join(product, 'check-trusted-path'), 'fixture helper\n');
  const app = join(dir, 'pavucontrol');
  writeFileSync(app, `#!${process.execPath}\nimport { readFileSync, writeFileSync } from 'node:fs';\nconst keys = ['HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_DATA_DIRS', 'GTK_THEME', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS'];\nwriteFileSync(process.env.TEST_CAPTURE, JSON.stringify({ argv: process.argv.slice(2), env: Object.fromEntries(keys.map(k => [k, process.env[k]])), stdin: readFileSync(0, 'utf8') }));\nprocess.exit(Number(process.env.TEST_APP_STATUS || 0));\n`, { mode: 0o755 });
  // Redirect fixed system paths and ownership only in the disposable test copy; production has no root override.
  const uid = process.getuid();
  const source = read(join(runtime, 'launch')).replaceAll('/usr/share/mirroros/gtk4', staged)
    .replaceAll('/usr/share/mirroros/themes', product)
    .replace('for path in / /usr /usr/share /usr/share/mirroros ', `for path in '${dir}' `)
    .replaceAll('/usr/bin/pavucontrol', app).replace('"$owner" == 0', `"$owner" == ${uid}`).replace('! -uid 0', `! -uid ${uid}`);
  const launcher = join(staged, 'launch');
  writeFileSync(launcher, source);
  const capture = join(dir, 'capture.json');
  const env = { ...process.env, HOME: home, XDG_CONFIG_HOME: join(home, 'config'), XDG_DATA_HOME: join(home, 'data'),
    XDG_CACHE_HOME: join(home, 'cache'), XDG_STATE_HOME: join(home, 'state'), XDG_DATA_DIRS: '/extra/data:/usr/share',
    GTK_THEME: 'OtherTheme', WAYLAND_DISPLAY: 'wayland-test', DBUS_SESSION_BUS_ADDRESS: 'unix:path=/synthetic/session', TEST_CAPTURE: capture };
  const run = (args = ['pavucontrol'], extra = {}) => spawnSync('bash', [launcher, ...args], { env: { ...env, ...extra }, input: 'synthetic stdin', encoding: 'utf8' });
  return { dir, product, staged, home, capture, env, run };
}

test('launcher preserves real preferences, forwards argv/stdin and exit status, and changes only process resources', (t) => {
  const fixture = launcherFixture(t);
  const args = ['--tab=4', 'literal $(touch not-executed); *'];
  const result = fixture.run(['pavucontrol', ...args], { TEST_APP_STATUS: '17' });
  assert.equal(result.status, 17, result.stderr);
  const captured = JSON.parse(read(fixture.capture));
  assert.deepEqual(captured.argv, args);
  assert.equal(captured.stdin, 'synthetic stdin');
  for (const key of ['HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS'])
    assert.equal(captured.env[key], fixture.env[key], key);
  assert.equal(captured.env.GTK_THEME, 'MirrorOS');
  assert.equal(captured.env.XDG_DATA_DIRS, `${fixture.staged}/share:${fixture.env.XDG_DATA_DIRS}`);
  assert.equal(read(join(fixture.home, 'config/pavucontrol.ini')), 'private existing preferences\n');
  assert.equal(existsSync(join(root, 'not-executed')), false);
  assert.equal(fixture.run([], { TEST_RESOLVER_STATUS: '4' }).status, 2);
  const defaults = fixture.run(['pavucontrol'], { XDG_DATA_DIRS: '' });
  assert.equal(defaults.status, 0, defaults.stderr);
  assert.equal(JSON.parse(read(fixture.capture)).env.XDG_DATA_DIRS, `${fixture.staged}/share:/usr/local/share:/usr/share`);
  rmSync(fixture.capture);
  assert.equal(fixture.run(['pavucontrol'], { TEST_RESOLVER_STATUS: '4' }).status, 4);
  assert.equal(existsSync(fixture.capture), false);
});

test('launcher rejects unsafe resources before starting an application', (t) => {
  const fixture = launcherFixture(t);
  const css = join(fixture.staged, 'base.css');
  chmodSync(css, 0o666);
  assert.equal(fixture.run().status, 4);
  assert.equal(existsSync(fixture.capture), false);
  chmodSync(css, 0o644);
  rmSync(css);
  symlinkSync('typography.css', css);
  assert.equal(fixture.run().status, 4);
  rmSync(css);
  assert.equal(fixture.run().status, 4);
  assert.equal(existsSync(fixture.capture), false);
});

test('launcher checks separate runtime and palette ancestors before starting an application', (t) => {
  const fixture = launcherFixture(t);
  assert.notEqual(dirname(fixture.staged), fixture.product);
  chmodSync(fixture.product, 0o777);
  assert.equal(fixture.run().status, 4);
  assert.equal(existsSync(fixture.capture), false);
  chmodSync(fixture.product, 0o755);
  chmodSync(fixture.staged, 0o777);
  assert.equal(fixture.run().status, 4);
  assert.equal(existsSync(fixture.capture), false);
});

test('production launcher admits only reviewed applications and has no test root or configuration redirection', () => {
  const launcher = join(runtime, 'launch');
  for (const args of [[], ['strata'], ['sh', '-c', 'exit 0'], ['--help', 'extra']])
    assert.equal(spawnSync('bash', [launcher, ...args], { encoding: 'utf8' }).status, 2);
  assert.equal(spawnSync('bash', [launcher, '--help'], { encoding: 'utf8' }).status, 0);
  const code = read(launcher);
  assert.doesNotMatch(code, /MIRROROS_.*ROOT|TEST_|XDG_CONFIG_HOME=|XDG_DATA_HOME=|XDG_CACHE_HOME=|HOME=|gsettings|dconf|kill|pkill/);
  assert.match(code, /resolve-current" \/ "\$state" 0 gtk4/);
});

test('each native entry MirrorOS-<theme> imports its published theme palette and the same installed GTK4 layers', () => {
  const names = readdirSync(join(runtime, 'entries'));
  assert.deepEqual(names, ['default']);
  for (const name of names) {
    assert.match(name, /^[a-z0-9]+(-[a-z0-9]+)*$/);
    assert.deepEqual(readdirSync(join(runtime, 'entries', name)).sort(), ['gtk-dark.css', 'gtk.css']);
    // The dark color scheme loads gtk-dark.css; without it GTK falls back to Adwaita's dark variant.
    assert.match(read(join(runtime, 'entries', name, 'gtk-dark.css')), /^@import url\("gtk\.css"\);$/m);
    assert.ok(existsSync(join(theme, name, 'gtk-4.0.css')), name);
    const imports = [...read(join(runtime, 'entries', name, 'gtk.css')).matchAll(/@import url\("([^"]+)"\);/g)].map(match => match[1]);
    assert.deepEqual(imports, [`/usr/share/mirroros/themes/${name}/gtk-4.0.css`, ...layers.map(path => `/usr/share/mirroros/gtk4/${path}`)]);
  }
  assert.match(read(join(runtime, 'install-runtime')), /-o -path \.\/entries/);
});
