#!/usr/bin/env node
// Native theme indexing regressions; fixtures never use host package contents.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';

const helper = path.resolve('capabilities/desktop/shell/services/app-icons');

function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mirroros-app-icons-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const put = (relative, text = '<svg/>') => {
    const dest = path.join(dir, relative);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, text);
    return dest;
  };
  put('bin/gsettings', '#!/bin/sh\nprintf "\\047%s\\047\\n" "${TEST_THEME:-MirrorOS-default}"\n');
  fs.chmodSync(path.join(dir, 'bin/gsettings'), 0o755);
  const env = { ...process.env, HOME: path.join(dir, 'home'), XDG_DATA_HOME: path.join(dir, 'user data'),
    XDG_DATA_DIRS: path.join(dir, 'system'), PATH: `${path.join(dir, 'bin')}:${process.env.PATH}` };
  const theme = (name, inherits = '', base = 'system', directories = ['scalable/apps', '32x32/apps', '256x256/apps', 'scalable/devices']) => {
    put(`${base}/icons/${name}/index.theme`, `[Icon Theme]\nName=${name}\nInherits=${inherits}\nDirectories=${directories.join(',')}\n` +
      directories.map(d => `[${d}]\nSize=128\nContext=${d.endsWith('/devices') ? 'Devices' : 'Applications'}\n`).join(''));
  };
  const scan = (extra = {}) => {
    const result = spawnSync('bash', [helper], { env: { ...env, ...extra }, encoding: 'utf8', timeout: 5000 });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.trim().split('\n').filter(Boolean).map(line => {
      const tab = line.indexOf('\t');
      assert.ok(tab > 0, line);
      return { signature: line.slice(0, tab), path: line.slice(tab + 1) };
    });
  };
  return { dir, put, theme, scan };
}

test('selected native theme precedes inherited themes; unrelated themes and actions are excluded', t => {
  const f = fixture(t);
  f.theme('MirrorOS-default', 'Adwaita');
  f.theme('Adwaita');
  f.theme('hicolor');
  f.theme('Other');
  const selected = f.put('system/icons/MirrorOS-default/32x32/apps/foot.png');
  f.put('system/icons/Adwaita/scalable/apps/foot.svg');
  f.put('system/icons/hicolor/scalable/apps/omasnap.svg');
  f.put('system/icons/Other/scalable/apps/unrelated.svg');
  f.put('system/icons/MirrorOS-default/scalable/actions/zoom.svg');
  const printer = f.put('system/icons/MirrorOS-default/scalable/devices/printer.svg');
  const rows = f.scan();
  assert.equal(rows.find(r => path.basename(r.path).startsWith('foot.')).path, selected);
  assert.ok(rows.some(r => r.path === printer));
  assert.ok(rows.some(r => r.path.endsWith('/omasnap.svg')));
  assert.ok(!rows.some(r => /unrelated|actions/.test(r.path)));
});

test('SVG wins within a theme root and PNG candidates use the largest nominal size', t => {
  const f = fixture(t);
  f.theme('MirrorOS-default');
  const small = f.put('system/icons/MirrorOS-default/32x32/apps/video.png');
  const large = f.put('system/icons/MirrorOS-default/256x256/apps/video.png');
  f.put('system/icons/MirrorOS-default/256x256/apps/audio.png');
  const vector = f.put('system/icons/MirrorOS-default/scalable/apps/audio.svg');
  const rows = f.scan();
  assert.ok(rows.findIndex(r => r.path === large) < rows.findIndex(r => r.path === small));
  assert.equal(rows.find(r => path.basename(r.path).startsWith('audio.')).path, vector);
});

test('XDG user theme roots, spaces and symlinked icons are supported', t => {
  const f = fixture(t);
  f.theme('MirrorOS-default', 'Adwaita', 'user data');
  f.theme('MirrorOS-default', 'Adwaita');
  f.theme('Adwaita');
  const user = f.put('user data/icons/MirrorOS-default/scalable/apps/foot.svg');
  f.put('system/icons/MirrorOS-default/scalable/apps/foot.svg');
  f.put('artwork/real.svg');
  fs.symlinkSync(path.join(f.dir, 'artwork/real.svg'), path.join(path.dirname(user), 'linked.svg'));
  const rows = f.scan();
  assert.equal(rows.find(r => r.path.endsWith('/foot.svg')).path, user);
  assert.ok(rows.some(r => r.path.endsWith('/linked.svg')));
});

test('inheritance cycles terminate and hicolor/pixmaps remain final fallbacks', t => {
  const f = fixture(t);
  f.theme('MirrorOS-default', 'Parent');
  f.theme('Parent', 'MirrorOS-default');
  f.theme('hicolor');
  f.put('system/icons/Parent/scalable/apps/a.svg');
  f.put('system/icons/hicolor/scalable/apps/a.svg');
  f.put('system/pixmaps/a.svg');
  assert.deepEqual(f.scan().map(r => path.relative(f.dir, r.path)), [
    'system/icons/Parent/scalable/apps/a.svg', 'system/icons/hicolor/scalable/apps/a.svg', 'system/pixmaps/a.svg',
  ]);
  assert.ok(f.scan({ TEST_THEME: 'Missing' }).some(r => r.path.includes('/hicolor/')));
});

test('file signatures stay stable across reads and change when artwork is replaced', t => {
  const f = fixture(t);
  f.theme('MirrorOS-default');
  f.put('system/icons/MirrorOS-default/scalable/apps/a.svg');
  const first = f.scan()[0];
  assert.deepEqual(f.scan()[0], first);
  fs.writeFileSync(first.path, '<svg>changed artwork</svg>');
  const next = f.scan()[0];
  assert.equal(next.path, first.path);
  assert.notEqual(next.signature, first.signature);
});

test('changing the native preference changes the indexed artwork', t => {
  const f = fixture(t);
  f.theme('MirrorOS-default');
  f.theme('Personal');
  f.put('system/icons/MirrorOS-default/scalable/apps/a.svg');
  f.put('system/icons/Personal/scalable/apps/a.svg');
  assert.match(f.scan()[0].path, /MirrorOS-default/);
  assert.match(f.scan({ TEST_THEME: 'Personal' })[0].path, /Personal/);
  assert.match(f.scan({ TEST_THEME: '../unsafe' })[0].path, /MirrorOS-default/);
});
