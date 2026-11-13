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
const runtime = join(theme, 'gtk4');
const read = path => readFileSync(path, 'utf8');
const layers = ['base.css', 'control-states.css', 'focus-states.css', 'chrome.css', 'apps/pavucontrol.css'];

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
    assert.doesNotMatch(text, /#[a-f0-9]{3,8}\b|@lab_|\/tmp\//i, layer);
    for (const match of text.matchAll(/@(mirroros_\w+)/g)) assert.ok(colors.has(match[1]), `${layer}: ${match[1]}`);
  }
  for (const path of files(runtime)) assert.doesNotMatch(read(path), /\/tmp\/mirroros-|MirrorOS-Widgets-Lab|MirrorOS-Pavucontrol-Lab/, path);
});

test('the theme loads native GTK, palette and reviewed layers in their original cascade order', () => {
  const entry = join(runtime, 'share/themes/MirrorOS/gtk-4.0/gtk.css');
  const imports = [...read(entry).matchAll(/@import url\("([^"]+)"\);/g)].map(match => match[1]);
  assert.deepEqual(imports.slice(0, 2), ['resource:///org/gtk/libgtk/theme/Default/Default-dark.css',
    '/usr/share/mirroros/themes/default/gtk-4.0.css']);
  assert.deepEqual(imports.slice(2).map(path => resolve(dirname(entry), path)), layers.map(path => join(runtime, path)));
  const focus = read(join(runtime, 'focus-states.css'));
  assert.match(focus, /window list > row\.activatable:selected:hover/);
  assert.match(focus, /window list > row\.activatable:selected:active/);
  assert.match(focus, /window list > row\.activatable:selected\.has-open-popup/);
  assert.doesNotMatch(focus, /outline(?:-width)?:\s*(?:none|0)/);
  const chrome = read(join(runtime, 'chrome.css'));
  assert.match(chrome, /popover\.background \{\s+background-color: transparent;/);
  assert.match(chrome, /combobox popover\.menu \{\s+margin-bottom: 6px;/);
  assert.match(chrome, /padding: 0 6px 0 0;/);
  const app = read(join(runtime, 'apps/pavucontrol.css'));
  assert.equal((app.match(/window\.pavucontrol-window /g) || []).length, 2);
  assert.match(app, /separator \+ checkbutton \{\s+margin: 12px 12px 6px;/);
  assert.match(app, /checkbutton \+ checkbutton \{\s+margin: 0 12px 12px;/);
  assert.doesNotMatch(app, /background|color:|@import/);
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
  assert.equal(read(join(runtime, 'theme.name')), 'mirroros-gtk4\n');
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
  const staged = join(product, 'gtk4');
  const home = join(dir, 'home');
  cpSync(runtime, staged, { recursive: true });
  mkdirSync(join(product, 'default'));
  mkdirSync(join(home, 'config'), { recursive: true });
  writeFileSync(join(home, 'config/pavucontrol.ini'), 'private existing preferences\n');
  writeFileSync(join(product, 'resolve-current'), `#!/usr/bin/bash\nprintf '%s\\n' '${product}/default/gtk-4.0.css'\nexit "\u0024{TEST_RESOLVER_STATUS:-0}"\n`);
  writeFileSync(join(product, 'check-trusted-path'), 'fixture helper\n');
  const app = join(dir, 'pavucontrol');
  writeFileSync(app, `#!${process.execPath}\nimport { readFileSync, writeFileSync } from 'node:fs';\nconst keys = ['HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_DATA_DIRS', 'GTK_THEME', 'WAYLAND_DISPLAY', 'DBUS_SESSION_BUS_ADDRESS'];\nwriteFileSync(process.env.TEST_CAPTURE, JSON.stringify({ argv: process.argv.slice(2), env: Object.fromEntries(keys.map(k => [k, process.env[k]])), stdin: readFileSync(0, 'utf8') }));\nprocess.exit(Number(process.env.TEST_APP_STATUS || 0));\n`, { mode: 0o755 });
  // Redirect fixed system paths and ownership only in the disposable test copy; production has no root override.
  const uid = process.getuid();
  const source = read(join(runtime, 'launch')).replaceAll('/usr/share/mirroros/themes', product)
    .replace('for path in / /usr /usr/share /usr/share/mirroros ', `for path in '${dir}' `)
    .replaceAll('/usr/bin/pavucontrol', app).replace('"$owner" == 0', `"$owner" == ${uid}`).replace('! -uid 0', `! -uid ${uid}`);
  const launcher = join(staged, 'launch');
  writeFileSync(launcher, source);
  const capture = join(dir, 'capture.json');
  const env = { ...process.env, HOME: home, XDG_CONFIG_HOME: join(home, 'config'), XDG_DATA_HOME: join(home, 'data'),
    XDG_CACHE_HOME: join(home, 'cache'), XDG_STATE_HOME: join(home, 'state'), XDG_DATA_DIRS: '/extra/data:/usr/share',
    GTK_THEME: 'OtherTheme', WAYLAND_DISPLAY: 'wayland-test', DBUS_SESSION_BUS_ADDRESS: 'unix:path=/synthetic/session', TEST_CAPTURE: capture };
  const run = (args = ['pavucontrol'], extra = {}) => spawnSync('bash', [launcher, ...args], { env: { ...env, ...extra }, input: 'synthetic stdin', encoding: 'utf8' });
  return { dir, staged, home, capture, env, run };
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
  symlinkSync('control-states.css', css);
  assert.equal(fixture.run().status, 4);
  rmSync(css);
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
