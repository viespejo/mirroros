import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
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
  const entry = join(runtime, 'entries/default/gtk.css');
  const imports = [...read(entry).matchAll(/@import url\("([^"]+)"\);/g)].map(match => match[1]);
  assert.equal(imports[0], '/usr/share/mirroros/themes/default/gtk-4.0.css');
  assert.deepEqual(imports.slice(1), layers.map(path => `/usr/share/mirroros/gtk4/${path}`));
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

test('the runtime has no launcher, application icon overlay or palette identity', () => {
  for (const name of ['launch', 'icon-aliases.json', 'share']) assert.equal(existsSync(join(runtime, name)), false, name);
  assert.equal(existsSync(join(runtime, 'theme.name')), false);
  assert.match(read(join(runtime, 'STRATA-LICENSE')), /Copyright \(c\) 2026 LGSE Ltd\./);
  assert.equal(createHash('sha256').update(readFileSync(join(runtime, 'STRATA-LICENSE'))).digest('hex'),
    '9f7b0c37b47dc21925dae3176ebb065c4a8581331fbacb1ca939acc23a82a640');
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

test('each native icon theme MirrorOS-<theme> holds the neutral check and exactly the generated icons over Adwaita', async () => {
  const generator = await import(join(runtime, 'icon-sources/generate.mjs'));
  const names = readdirSync(join(runtime, 'icons'));
  assert.deepEqual(names, ['default']);
  const check = ['16x16/status/emblem-default.svg', 'scalable/status/emblem-default.svg',
    'symbolic/status/emblem-default-symbolic.svg'];
  for (const name of names) {
    const icons = join(runtime, 'icons', name);
    const generated = generator.generate(name);
    // Committed output must equal a fresh generation: no hand edits and no stale output.
    assert.deepEqual(files(icons).map(path => path.slice(icons.length + 1)).sort(), [...check, ...generated.keys()].sort());
    for (const [path, content] of generated) assert.equal(read(join(icons, path)), content, path);
    const palette = new Set(Object.values(generator.parseColors(read(join(theme, name, 'colors.toml')))));
    const applicationPalette = new Set(Object.values(generator.applicationPalette(name)).map(value => value.toLowerCase()));
    for (const path of generated.keys()) {
      if (!path.endsWith('.svg')) continue;
      assert.match(path, /^scalable\/(places|mimetypes|devices|apps)\/[a-zA-Z0-9._-]+\.svg$/, path);
      const text = generated.get(path);
      assert.doesNotMatch(text, /var\(|currentColor/, path);
      const allowed = path.startsWith('scalable/apps/') ? applicationPalette : palette;
      assert.doesNotMatch(text, /\{\{|\}\}/, path);
      for (const [hex] of text.matchAll(/#[0-9a-fA-F]{6}\b/g)) assert.ok(allowed.has(hex.toLowerCase()), `${path}: ${hex}`);
    }
    // The reviewed original drawing, identical in every variant.
    for (const path of check) {
      assert.equal(sha256(readFileSync(join(icons, path))), 'feef50a3157c69a478fa2c730a635aa503ce445a71529e6354eb4717dd8f089e', path);
      assert.match(read(join(icons, path)), /fill="currentColor"/);
    }
    const index = read(join(icons, 'index.theme'));
    const sections = new Map([...index.matchAll(/^\[([^\]]+)\]\n((?:[A-Za-z]+=.*\n)+)/gm)]
      .map(match => [match[1], Object.fromEntries(match[2].trim().split('\n').map(line => line.split('=')))]));
    assert.deepEqual(sections.get('Icon Theme'), {
      Name: `MirrorOS-${name}`, Comment: 'MirrorOS check, folders, file types, devices and applications over Adwaita',
      Inherits: 'Adwaita,hicolor',
      Directories: '16x16/status,scalable/status,symbolic/status,scalable/places,scalable/mimetypes,scalable/devices,scalable/apps',
    });
    assert.deepEqual(sections.get('16x16/status'), { Context: 'Status', Size: '16', Type: 'Fixed' });
    assert.deepEqual(sections.get('scalable/status'),
      { Context: 'Status', Size: '128', MinSize: '8', MaxSize: '512', Type: 'Scalable' });
    assert.deepEqual(sections.get('symbolic/status'),
      { Context: 'Status', Size: '16', MinSize: '8', MaxSize: '512', Type: 'Scalable' });
    for (const [dir, context] of [['scalable/places', 'Places'], ['scalable/mimetypes', 'MimeTypes'], ['scalable/devices', 'Devices'], ['scalable/apps', 'Applications']])
      assert.deepEqual(sections.get(dir), { Context: context, Size: '128', MinSize: '8', MaxSize: '512', Type: 'Scalable' });
    assert.equal(sections.size, 8);
    const apps = [...generated.keys()].filter(path => path.startsWith('scalable/apps/'));
    assert.equal(apps.length, 97);
    assert.ok(!apps.includes('scalable/apps/printer.svg'));
    for (const icon of ['foot', 'omasnap', 'org.pulseaudio.pavucontrol', 'io.github.lgse.Strata'])
      assert.ok(apps.includes(`scalable/apps/${icon}.svg`));
  }
  assert.match(read(join(runtime, 'install-runtime')), /-o -path \.\/icons/);
  assert.match(read(join(runtime, 'install-runtime')), /-o -path \.\/icon-sources/);
});

test('application source hashes and distributed licenses retain the reviewed inputs', () => {
  const sources = join(runtime, 'icon-sources');
  const sums = read(join(sources, 'application-sources.sha256')).trim().split('\n').map(line => line.split(/  /));
  const inputs = files(sources).map(path => path.slice(sources.length + 1))
    .filter(path => /^(papercraft|papercraft-tools)\//.test(path) && !path.endsWith('ATTRIBUTION.md'));
  assert.deepEqual(sums.map(([, path]) => path).sort(), inputs.sort());
  for (const [hash, path] of sums) assert.equal(sha256(readFileSync(join(sources, path))), hash, path);
  assert.match(read(join(runtime, 'icons/default/licenses/papercraft/ATTRIBUTION.md')), /Lennard Hofmann, CC BY-SA 4.0/);
  assert.match(read(join(runtime, 'icons/default/licenses/papercraft/ATTRIBUTION.md')), /Jason Long, CC BY 3.0/);
});

test('icon sources are the pinned unmodified upstream files and every drawn color keeps its contrast', async () => {
  const sources = join(runtime, 'icon-sources');
  const sums = read(join(sources, 'SHA256SUMS')).trim().split('\n').map(line => line.split(/  /));
  assert.deepEqual(sums.map(([, path]) => path).sort(),
    files(sources).map(path => path.slice(sources.length + 1)).filter(path => /^(lucide|catppuccin)\//.test(path)).sort());
  for (const [hash, path] of sums) assert.equal(sha256(readFileSync(join(sources, path))), hash, path);
  const generator = await import(join(sources, 'generate.mjs'));
  const colors = generator.parseColors(read(join(theme, 'default/colors.toml')));
  for (const key of new Set(['bright_blue', ...Object.values(generator.CATPPUCCIN_COLORS)])) {
    assert.ok(generator.contrast(colors[key], colors.background) >= generator.MIN_BACKGROUND_CONTRAST, key);
    assert.ok(generator.contrast(colors[key], colors.accent) >= generator.MIN_SELECTED_CONTRAST, key);
  }
  // A palette whose shape color matches the selected-row accent is rejected.
  const clash = read(join(theme, 'default/colors.toml')).replace(/^bright_blue = "#[0-9a-fA-F]{6}"$/m, `bright_blue = "${colors.accent}"`);
  assert.throws(() => generator.generate('default', {
    read: path => (path.endsWith('colors.toml') ? clash : readFileSync(path, 'utf8')),
  }), /bright_blue/);
});
