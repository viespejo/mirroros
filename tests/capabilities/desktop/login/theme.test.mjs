// MirrorOS SDDM theme: pure login logic, ADR 0014/0015 boundaries, qmllint baseline and synthetic-model UI behavior.
// The UI cases run tst_theme.qml with qmltestrunner on the offscreen platform; sddm.login is a recording stub, so
// these tests never authenticate and are not a substitute for the attended VM login checks.
// MIRROROS_QMLLINT_CAPTURE=1 prints candidate baseline keys for an explicit, reviewed update.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';

const testsDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(testsDir, '../../../..');
const themeDir = path.join(root, 'capabilities/desktop/login/sddm/mirroros');
const qtBin = '/usr/lib/qt6/bin';
const Model = createRequire(import.meta.url)(path.join(themeDir, 'LoginModel.js'));
const read = name => fs.readFileSync(path.join(themeDir, name), 'utf8');
const session = '/usr/share/mirroros/wayland-sessions/hyprland-uwsm.desktop';

test('the last user is selected only while still listed, otherwise the first', () => {
  assert.equal(Model.initialUserIndex(['alice', 'bob'], 'bob'), 1);
  assert.equal(Model.initialUserIndex(['alice', 'bob'], 'zed'), 0);
  assert.equal(Model.initialUserIndex(['alice', 'bob'], ''), 0);
  assert.equal(Model.initialUserIndex([], 'bob'), -1);
});

test('only the single exact configured session is used', () => {
  assert.equal(Model.sessionIndex(['/x/foot.desktop', session], session), 1);
  assert.equal(Model.sessionIndex(['/usr/share/wayland-sessions/hyprland-uwsm.desktop'], session), -1);
  assert.equal(Model.sessionIndex([session, session], session), -1);
  assert.equal(Model.sessionIndex([session], ''), -1);
});

test('the native layout wins and the configured layout is the fallback', () => {
  assert.equal(Model.layoutLabel([], 0, 'es'), 'es');
  assert.equal(Model.layoutLabel(['us', 'de'], 1, 'es'), 'de');
  assert.equal(Model.layoutLabel(['us'], 3, 'es'), 'es');
  assert.equal(Model.layoutLabel([''], 0, 'us'), 'us');
  assert.equal(Model.layoutLabel([], -1, undefined), '');
});

test('the layout state file yields a short validated label or nothing', () => {
  assert.equal(Model.stateLabel('Spanish\n'), 'Spanish');
  assert.equal(Model.stateLabel('  English (US)  \nextra'), 'English (US)');
  assert.equal(Model.stateLabel(''), '');
  assert.equal(Model.stateLabel(undefined), '');
  assert.equal(Model.stateLabel('<b>x</b>'), '');
  assert.equal(Model.stateLabel('x'.repeat(65)), '');
});

test('unavailable states are actionable and block submission', () => {
  assert.match(Model.unavailableReason(-1, 0), /No user account/);
  assert.match(Model.unavailableReason(0, -1), /mirroros-configure/);
  assert.equal(Model.unavailableReason(0, 0), '');
  assert.equal(Model.canSubmit(0, 0, false, 'pw'), true);
  assert.equal(Model.canSubmit(0, 0, true, 'pw'), false);
  assert.equal(Model.canSubmit(0, 0, false, ''), false);
  assert.equal(Model.canSubmit(-1, 0, false, 'pw'), false);
  assert.equal(Model.canSubmit(0, -1, false, 'pw'), false);
  assert.equal(Model.displayName('bob', ''), 'bob');
  assert.equal(Model.displayName('bob', 'Bob B'), 'Bob B');
});

test('the theme stays within the ADR 0014 and ADR 0015 presentation boundary', () => {
  const code = text => text.split('\n').filter(line => !/^\s*\/\//.test(line)).join('\n');
  const qml = code(read('Main.qml'));
  const js = code(read('LoginModel.js'));
  assert.deepEqual([...qml.matchAll(/^import\s+(\S+)/gm)].map(match => match[1]), ['QtQuick', '"LoginModel.js"']);
  assert.equal(qml.match(/\bsddm\.\w+/g).join(' '), 'sddm.login');
  // ADR 0015: one local GET of the configured layout state file; no other request or method.
  assert.equal(qml.match(/XMLHttpRequest\(\)/g).length, 1);
  assert.deepEqual([...qml.matchAll(/\.open\(([^)]*)\)/g)].map(match => match[1]), ['"GET", "file://" + layoutStatePath']);
  assert.doesNotMatch(js, /XMLHttpRequest/);
  for (const source of [qml, js]) {
    assert.doesNotMatch(source, /openUrlExternally|console\.|Quickshell|Process|FileView|Qt\.labs|import\s+QtCore/);
    assert.doesNotMatch(source, /powerOff|reboot|suspend|hibernate|hybridSleep/);
  }
  assert.doesNotMatch(qml, /avatar|icon|Clock|Date\(/i);
  const entries = fs.readdirSync(themeDir).sort();
  assert.deepEqual(entries, ['LoginModel.js', 'Main.qml', 'metadata.desktop', 'theme.conf']);
});

test('metadata selects the Qt 6 greeter and the configuration matches the lock screen palette', () => {
  const metadata = read('metadata.desktop');
  for (const line of ['MainScript=Main.qml', 'ConfigFile=theme.conf', 'Theme-Id=mirroros', 'QtVersion=6'])
    assert.match(metadata, new RegExp(`^${line}$`, 'm'));
  const lock = fs.readFileSync(path.join(root, 'capabilities/desktop/lock/hyprlock.conf'), 'utf8');
  const conf = read('theme.conf');
  const hex = rgb => '#' + rgb.split(',').map(value => Number(value).toString(16).padStart(2, '0')).join('');
  assert.match(lock, /color = rgb\(16, 19, 21\)/);
  assert.match(lock, /outer_color = rgb\(202, 204, 204\)/);
  assert.match(lock, /fail_color = rgb\(165, 85, 85\)/);
  assert.match(conf, new RegExp(`^background="${hex('16,19,21')}"$`, 'm'));
  assert.match(conf, new RegExp(`^foreground="${hex('202,204,204')}"$`, 'm'));
  assert.match(conf, new RegExp(`^failure="${hex('165,85,85')}"$`, 'm'));
  assert.match(conf, /^logo=\/usr\/share\/mirroros\/branding\/mirroros-wordmark\.png$/m);
  assert.match(conf, new RegExp(`^session=${session}$`, 'm'));
  assert.match(conf, /^keyboardLayout=$/m);
  assert.match(conf, /^layoutState=\/var\/lib\/sddm\/mirroros-greeter-layout$/m);
  assert.match(conf, /^layoutHint=Super\+I$/m);
  const indicator = fs.readFileSync(path.join(root,
    'capabilities/desktop/compositor/providers/hyprland/greeter/layout-indicator'), 'utf8');
  assert.match(indicator, /MIRROROS_LAYOUT_STATE:-\/var\/lib\/sddm\/mirroros-greeter-layout\}/);
});

test('qmllint diagnostics match the reviewed baseline entry by entry', t => {
  const qmllint = path.join(qtBin, 'qmllint');
  if (!fs.existsSync(qmllint)) return t.skip('qmllint is not installed');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mirroros-sddm-lint-'));
  try {
    const report = path.join(tmp, 'lint.json');
    const result = spawnSync(qmllint, ['--json', report, 'Main.qml'], { cwd: themeDir, encoding: 'utf8' });
    assert.equal(result.error, undefined);
    const lines = read('Main.qml').split('\n');
    const keys = JSON.parse(fs.readFileSync(report, 'utf8')).files.flatMap(file => file.warnings.map(warning =>
      JSON.stringify([warning.id, warning.message, (lines[warning.line - 1] || '').trim()]))).sort();
    if (process.env.MIRROROS_QMLLINT_CAPTURE) console.log(keys.join('\n'));
    const baseline = fs.readFileSync(path.join(testsDir, 'qmllint-baseline.txt'), 'utf8').split('\n')
      .filter(line => line && !line.startsWith('#')).sort();
    assert.deepEqual(keys, baseline);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('synthetic SDDM models drive selection, submission, failure and keyboard navigation', t => {
  const runner = path.join(qtBin, 'qmltestrunner');
  if (!fs.existsSync(runner)) return t.skip('qmltestrunner is not installed');
  const rsvg = spawnSync('rsvg-convert', ['--version'], { encoding: 'utf8' });
  if (rsvg.error) return t.skip('rsvg-convert is not installed');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mirroros-sddm-ui-'));
  try {
    const logo = path.join(tmp, 'mirroros-wordmark.png');
    const svg = fs.readFileSync(path.join(root, 'capabilities/visual/branding/mirroros-wordmark.svg'));
    const render = spawnSync('rsvg-convert', ['--width', '1580', '--height', '320'], { input: svg });
    assert.equal(render.status, 0);
    fs.writeFileSync(logo, render.stdout);
    const state = path.join(tmp, 'mirroros-greeter-layout');
    fs.writeFileSync(state, 'English (US)\n');
    const harness = fs.readFileSync(path.join(testsDir, 'tst_theme.qml'), 'utf8')
      .replaceAll('@THEME@', pathToFileURL(themeDir).href).replaceAll('@LOGO@', logo).replaceAll('@STATE@', state);
    fs.writeFileSync(path.join(tmp, 'tst_theme.qml'), harness);
    const result = spawnSync(runner, ['-input', path.join(tmp, 'tst_theme.qml')], {
      encoding: 'utf8', timeout: 120000,
      env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', QML_XHR_ALLOW_FILE_READ: '1' },
    });
    const output = (result.stdout || '') + (result.stderr || '');
    assert.equal(result.status, 0, output);
    assert.doesNotMatch(output, /^(QWARN|FAIL!)/m, output);
    assert.match(output, /Totals: \d+ passed, 0 failed/);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});
