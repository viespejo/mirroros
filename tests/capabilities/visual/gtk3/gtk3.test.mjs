import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const runtime = join(root, 'capabilities/visual/gtk3');
const read = path => readFileSync(path, 'utf8');
const sha256 = data => createHash('sha256').update(data).digest('hex');
const palette = new Map([...read(join(root, 'capabilities/visual/theme/default/gtk-3.0.css'))
  .matchAll(/^@define-color (mirroros_osaka_gtk3_\d+) ([^;]+);$/gm)].map(match => [match[1], match[2]]));

function files(path) {
  return readdirSync(path, { withFileTypes: true }).flatMap(entry =>
    entry.isDirectory() ? files(join(path, entry.name)) : [join(path, entry.name)]);
}

test('GTK3 palette tokens reconstruct the pinned Osaka CSS byte for byte', () => {
  assert.equal(palette.size, 211);
  const original = read(join(runtime, 'base.css')).replace(/^\/\* Adapted[\s\S]*?\*\/\n/, '')
    .replace(/@(mirroros_osaka_gtk3_\d+)/g, (_, name) => {
      assert.ok(palette.has(name), name);
      return palette.get(name);
    });
  assert.equal(sha256(original), '44a62ba35af01c67ae163fe400e882dac001efc165e3ae84b075416b0dd7ea5a');
  for (const match of original.matchAll(/url\(["']?([^"')]+)["']?\)/g)) {
    assert.ok(match[1].startsWith('assets/'), match[1]);
    assert.ok(existsSync(join(runtime, match[1])), match[1]);
  }
  for (const layer of ['base.css', 'typography.css']) {
    const text = read(join(runtime, layer));
    const declarations = [...text.matchAll(/(^[ \t]*[-\w]+:\s*|^@define-color \w+ )([^;\n]+)/gm)].map(match => match[2]).join('\n');
    assert.doesNotMatch(declarations, /#[a-f0-9]{3,8}\b|rgba?\(\s*\d|\b(?:white|black)\b/i, layer);
    for (const match of text.matchAll(/@(mirroros_\w+)/g)) assert.ok(palette.has(match[1]), match[1]);
  }
});

test('GTK3 widget assets and upstream notices retain their exact bytes', () => {
  const assets = files(join(runtime, 'assets')).sort();
  assert.equal(assets.length, 126);
  const inventory = assets.map(path => `${sha256(readFileSync(path))}  ${path.slice(join(runtime, 'assets').length + 1)}`).join('\n') + '\n';
  assert.equal(sha256(inventory), '6af5d41a81db3d34cecde09fe4b44bf89fa79ffb29edda15e415b241ca4899d1');
  const licenses = {
    'AUTHORS.yaru': 'eb5e3c27ba894f34d2cab78093fb1bf54cfba7da29e5febf70416e67584db30b',
    'COPYING.yaru': 'cb4392586efcf6ade8315f08e392b3eaf2ab37565f3c6ce8ef03aa3d76ed23ff',
    'LICENSE_CCBYSA.yaru': '7a8af68d18de818e54697230278c0ade42e6bac15d4116ef9560f74176431118',
    'LICENSE.osaka-jade': '5ce556535ed37e7061075c5ec86afc07a5199c804db70b1814795e7002980129',
  };
  for (const [name, hash] of Object.entries(licenses)) assert.equal(sha256(readFileSync(join(runtime, 'licenses', name))), hash, name);
  assert.equal(sha256(readFileSync(join(runtime, 'STRATA-LICENSE'))), '9f7b0c37b47dc21925dae3176ebb065c4a8581331fbacb1ca939acc23a82a640');
});

test('GTK3 entries load only their palette, base and shared typography in both variants', () => {
  const entry = join(runtime, 'entries/default/gtk.css');
  const imports = [...read(entry).matchAll(/@import url\("([^"]+)"\);/g)].map(match => match[1]);
  assert.equal(imports[0], '/usr/share/mirroros/themes/default/gtk-3.0.css');
  assert.deepEqual(imports.slice(1), ['base.css', 'typography.css'].map(path => `/usr/share/mirroros/gtk3/${path}`));
  assert.match(read(join(dirname(entry), 'gtk-dark.css')), /@import url\("gtk.css"\);/);
  assert.equal(read(join(runtime, 'typography.css')), read(join(root, 'capabilities/visual/gtk4/typography.css')));
  assert.match(read(join(runtime, 'typography.css')), /font-size: 13px;/);
  assert.match(read(join(runtime, 'typography.css')), /font-family: "JetBrains Mono", "JetBrainsMono Nerd Font", monospace;/);
});

test('GTK3 delivery is inert and contains no application icon overlay or unrelated upstream components', () => {
  for (const name of ['launch', 'theme.name', 'apps', 'share', 'gtk-2.0', 'xfwm4']) assert.equal(existsSync(join(runtime, name)), false, name);
  for (const path of files(runtime)) {
    if (path.endsWith('.css')) assert.doesNotMatch(read(path), /\/tmp\/|pavucontrol-window|@lab_/);
  }
  assert.doesNotMatch(read(join(runtime, 'apply')), /gsettings|dconf|systemctl|GTK_THEME=|XDG_DATA_DIRS=|cfg_user_/);
  assert.doesNotMatch(read(join(runtime, 'packages')), /^[^#\s]/m);
  const steps = read(join(root, 'capabilities/configure-steps'));
  assert.match(steps, /visual\/theme\s+visual\/gtk4\s+visual\/gtk3\s+desktop\/terminal/);
});

test('each native entry MirrorOS-<theme> imports its published theme palette and the installed GTK3 layers in both variants', () => {
  const names = readdirSync(join(runtime, 'entries'));
  assert.deepEqual(names, ['default']);
  for (const name of names) {
    assert.match(name, /^[a-z0-9]+(-[a-z0-9]+)*$/);
    const dir = join(runtime, 'entries', name);
    assert.deepEqual(readdirSync(dir).sort(), ['gtk-dark.css', 'gtk.css']);
    assert.ok(existsSync(join(root, 'capabilities/visual/theme', name, 'gtk-3.0.css')), name);
    const imports = [...read(join(dir, 'gtk.css')).matchAll(/@import url\("([^"]+)"\);/g)].map(match => match[1]);
    assert.deepEqual(imports, [`/usr/share/mirroros/themes/${name}/gtk-3.0.css`,
      '/usr/share/mirroros/gtk3/base.css', '/usr/share/mirroros/gtk3/typography.css']);
    assert.match(read(join(dir, 'gtk-dark.css')), /@import url\("gtk.css"\);/);
  }
  assert.match(read(join(runtime, 'install-runtime')), /-o -path \.\/entries/);
});
