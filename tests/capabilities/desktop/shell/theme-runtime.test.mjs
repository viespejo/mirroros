// Run on a system with Quickshell and its offscreen Qt platform plugin.
import test from 'node:test';
import assert from 'node:assert/strict';
import { chmodSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const available = existsSync('/usr/bin/qs') && existsSync('/usr/bin/dbus-run-session') &&
  existsSync('/usr/lib/qt6/plugins/platforms/libqoffscreen.so');
const shell = resolve('capabilities/desktop/shell');
const theme = resolve('capabilities/visual/theme');

for (const scenario of ['valid', 'unknown', 'missing-link', 'unsafe', 'invalid-palette', 'missing-helper', 'personal', 'unsafe-surface']) {
  test(`offscreen shell palette: ${scenario}`, { skip: !available }, (t) => {
    const dir = mkdtempSync(join(tmpdir(), 'mirroros-theme-runtime-'));
    t.after(() => rmSync(dir, { recursive: true, force: true }));
    const copy = join(dir, 'qs');
    const helpers = join(dir, 'helpers');
    const root = join(dir, 'root');
    const state = join(dir, 'state');
    const runtime = join(dir, 'runtime');
    const config = join(dir, 'config');
    const paletteDir = join(root, 'usr/share/mirroros/themes/default');
    cpSync(shell, copy, { recursive: true });
    mkdirSync(helpers);
    mkdirSync(paletteDir, { recursive: true });
    mkdirSync(join(state, 'mirroros/current'), { recursive: true });
    mkdirSync(runtime, { mode: 0o700 });
    mkdirSync(join(config, 'mirroros'), { recursive: true });
    if (scenario === 'personal' || scenario === 'unsafe-surface') writeFileSync(join(config, 'mirroros/shell.toml'), '[menu]\ntext = "#123456"\nborder-alpha = 2\n');
    cpSync(join(theme, 'check-trusted-path'), join(helpers, 'check-trusted-path'));
    if (scenario !== 'missing-helper') cpSync(join(theme, 'resolve-current'), join(helpers, 'resolve-current'));
    cpSync(join(theme, 'default/colors.toml'), join(paletteDir, 'colors.toml'));
    cpSync(join(theme, 'default/shell.toml'), join(paletteDir, 'shell.toml'));
    if (scenario === 'invalid-palette') writeFileSync(join(paletteDir, 'colors.toml'), 'background = "invalid"\n');
    if (scenario === 'unsafe') chmodSync(paletteDir, 0o777);
    if (scenario === 'unsafe-surface') {
      writeFileSync(join(paletteDir, 'shell.toml'), '[bar]\ntext = "#abcdef"\n');
      chmodSync(join(paletteDir, 'shell.toml'), 0o666);
    }
    if (scenario !== 'missing-link') symlinkSync(scenario === 'unknown' ? '/unknown/theme' : '/usr/share/mirroros/themes/default',
      join(state, 'mirroros/current/theme'));

    const qml = join(copy, 'Commons/Color.qml');
    let source = readFileSync(qml, 'utf8');
    for (const [oldText, newText] of [
      ['/usr/share/mirroros/themes/resolve-current', join(helpers, 'resolve-current')],
      ['"/", root.stateHome, "0"', `${JSON.stringify(root)}, root.stateHome, "${process.getuid()}"`],
      ['root.palettePath = lines[0] +', `root.palettePath = ${JSON.stringify(root)} + lines[0] +`],
    ]) {
      assert.ok(source.includes(oldText), `missing probe substitution: ${oldText}`);
      source = source.replace(oldText, newText);
    }
    writeFileSync(qml, source);
    const probe = join(dir, 'probe.qml');
    writeFileSync(probe, `import Quickshell\nimport QtQuick\nimport qs.Commons as Commons\nShellRoot {\n  Component.onCompleted: console.log("INITIAL " + Commons.Color.background)\n  Timer { interval: 2000; running: true; onTriggered: { console.log("RESULT " + Commons.Color.background); console.log("MENU " + Commons.Color.menu.text); console.log("BAR " + Commons.Color.bar.text); Qt.quit() } }\n}\n`);
    const result = spawnSync('/usr/bin/dbus-run-session', ['--', '/usr/bin/qs', '-p', probe], {
      env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', QML_IMPORT_PATH: dir,
        XDG_RUNTIME_DIR: runtime, XDG_STATE_HOME: state, XDG_CONFIG_HOME: config, NO_COLOR: '1' },
      encoding: 'utf8', timeout: 12000,
    });
    const output = (result.stdout || '') + (result.stderr || '');
    assert.equal(result.status, 0, output);
    assert.match(output, /INITIAL #101315/);
    assert.match(output, ['valid', 'unknown', 'missing-link', 'personal', 'unsafe-surface'].includes(scenario) ? /RESULT #111c18/ : /RESULT #101315/);
    if (scenario === 'personal' || scenario === 'unsafe-surface') {
      assert.match(output, /MENU #123456/);
      assert.match(output, /user:menu.border-alpha/);
    }
    if (scenario === 'unknown' || scenario === 'missing-link') assert.match(output, /Invalid or missing theme selection/);
    if (scenario === 'unsafe' || scenario === 'missing-helper') assert.match(output, /Cannot resolve MirrorOS shell theme/);
    if (scenario === 'invalid-palette') assert.match(output, /Invalid MirrorOS shell palette/);
    if (scenario === 'unsafe-surface') {
      assert.match(output, /surface settings.*untrusted/);
      assert.match(output, /BAR #c1c497/i);
    }
  });
}
