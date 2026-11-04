// Runtime display contracts with a recording hyprctl; no compositor or physical output is changed.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
const provider = path.join(root, 'capabilities/desktop/compositor/providers/hyprland');
const internal = { name: 'eDP-1', disabled: false, mirrorOf: 'none', focused: true, width: 1920, height: 1080, scale: 1 };
const external = { ...internal, name: 'HDMI-A-1', focused: false };
function run(args, monitors = [internal, external], options = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mirroros-display-'));
  try {
    fs.writeFileSync(path.join(dir, 'monitors.json'), typeof monitors === 'string' ? monitors : JSON.stringify(monitors));
    fs.writeFileSync(path.join(dir, 'hyprctl'), `#!/usr/bin/bash
set -Eeuo pipefail
printf '%s\\n' "$*" >> "$TEST_DIR/calls"
case "$1" in
  monitors) [[ "$*" == 'monitors all -j' ]] || exit 9
    [[ "\${QUERY_FAIL:-0}" == 0 ]] || exit 1
    /usr/bin/cat "$TEST_DIR/monitors.json" ;;
  eval) printf '%s' "$2" >> "$TEST_DIR/actions"
    [[ "\${EVAL_FAIL:-0}" == 0 ]] || exit 1
    printf '%s\\n' "\${EVAL_RESULT:-ok}" ;;
  *) exit 9 ;;
esac
`, { mode: 0o755 });
    const personal = path.join(dir, '.config/hypr');
    fs.mkdirSync(personal, { recursive: true });
    for (const file of ['monitors.lua', 'personal-monitors.lua']) fs.writeFileSync(path.join(personal, file), '-- personal\n');
    const result = spawnSync('bash', [path.join(provider, 'display'), ...args], {
      encoding: 'utf8', env: { ...process.env, HOME: dir, PATH: `${dir}:${process.env.PATH}`, TEST_DIR: dir, ...options },
    });
    for (const file of ['monitors.lua', 'personal-monitors.lua']) assert.equal(fs.readFileSync(path.join(personal, file), 'utf8'), '-- personal\n');
    assert.deepEqual(fs.readdirSync(personal).sort(), ['monitors.lua', 'personal-monitors.lua']);
    return { ...result, actions: fs.existsSync(path.join(dir, 'actions')) ? fs.readFileSync(path.join(dir, 'actions'), 'utf8') : '',
      calls: fs.existsSync(path.join(dir, 'calls')) ? fs.readFileSync(path.join(dir, 'calls'), 'utf8') : '' };
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}

test('invalid argv is rejected before contacting Hyprland', () => {
  for (const args of [[], ['unknown'], ['laptop', 'extra'], ['mirror', 'extra'], ['scale'], ['scale', '2'], ['scale', 'up', 'extra'], ['clamshell'], ['clamshell', 'toggle'], ['clamshell', 'open', 'extra']]) {
    const result = run(args);
    assert.equal(result.status, 2, args.join(' '));
    assert.equal(result.calls, '');
  }
});

test('all unsafe connectors and malformed monitor data are rejected without effect', () => {
  for (const name of ['HDMI-1\"); os.execute("bad") --', 'bad\nname', 'HDMI-A-1\n', 'bad name', '', '../bad', 'bad/name', 'éDP-1']) {
    const result = run(['laptop'], [internal, { ...external, name }]);
    assert.equal(result.status, 2, name);
    assert.equal(result.actions, '');
  }
  for (const data of ['invalid JSON', '{}', '[null]', [internal, internal], [{ ...internal, disabled: 'false' }]]) {
    const result = run(['laptop'], data);
    assert.equal(result.status, 2);
    assert.equal(result.actions, '');
  }
});

test('laptop toggle disables only the internal display and restores it explicitly', () => {
  const off = run(['laptop']);
  assert.equal(off.status, 0, off.stderr);
  assert.equal(off.actions, 'hl.monitor({ output = "eDP-1", disabled = true }); ');
  const on = run(['laptop'], [{ ...internal, disabled: true }, external]);
  assert.equal(on.status, 0, on.stderr);
  assert.match(on.actions, /output = "eDP-1", disabled = false, mirror = ""/);
});

test('clamshell leaves undocked suspend to logind, disables docked panel, and restores on open', () => {
  const undocked = run(['clamshell', 'close'], [internal]);
  assert.equal(undocked.status, 0, undocked.stderr);
  assert.equal(undocked.actions, '');
  const closed = run(['clamshell', 'close']);
  assert.equal(closed.status, 0, closed.stderr);
  assert.match(closed.actions, /output = "eDP-1", disabled = true/);
  assert.doesNotMatch(closed.actions, /lock|suspend|reload|dpms/);
  const opened = run(['clamshell', 'open'], [{ ...internal, disabled: true }, external]);
  assert.equal(opened.status, 0, opened.stderr);
  assert.match(opened.actions, /disabled = false/);
});

test('no internal display or usable external display is reported unavailable rather than blanking', () => {
  for (const monitors of [[], [external], [internal], [internal, { ...external, disabled: true }]]) {
    const result = run(['laptop'], monitors);
    assert.equal(result.status, 4);
    assert.equal(result.actions, '');
    assert.match(result.stderr, /unavailable/);
  }
  for (const monitors of [[], [internal], [external]]) {
    const result = run(['mirror'], monitors);
    assert.equal(result.status, 4);
    assert.equal(result.actions, '');
  }
});

test('mirroring restores the source before enabling the mirror and toggles back to extended', () => {
  const enabled = run(['mirror'], [{ ...internal, disabled: true }, external]);
  assert.equal(enabled.status, 0, enabled.stderr);
  assert.ok(enabled.actions.indexOf('output = "eDP-1", disabled = false') < enabled.actions.indexOf('mirror = "eDP-1"'));
  const disabled = run(['mirror'], [internal, { ...external, mirrorOf: '0' }]);
  assert.equal(disabled.status, 0, disabled.stderr);
  assert.match(disabled.actions, /output = "HDMI-A-1", disabled = false, mirror = ""/);
  assert.doesNotMatch(disabled.actions, /mirror = "eDP-1"/);
});

test('disabling a mirrored source first makes external outputs independent', () => {
  for (const args of [['laptop'], ['clamshell', 'close']]) {
    const result = run(args, [internal, { ...external, mirrorOf: '0' }]);
    assert.equal(result.status, 0, result.stderr);
    assert.ok(result.actions.indexOf('output = "HDMI-A-1", disabled = false, mirror = ""') < result.actions.indexOf('disabled = true'));
  }
});

test('scaling targets the focused display, uses clean presets, and stops at boundaries', () => {
  for (const [current, direction, expected] of [[1, 'up', 1.25], [1.6, 'down', 1.25], [1.25, 'up', 1.6]]) {
    const result = run(['scale', direction], [{ ...internal, scale: current }, external]);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.actions, `hl.monitor({ output = "eDP-1", scale = ${expected} }); `);
  }
  const rounded = run(['scale', 'up'], [{ ...internal, width: 1366, height: 768 }]);
  assert.equal(rounded.status, 0, rounded.stderr);
  assert.match(rounded.actions, /scale = 2/);
  for (const [scale, direction] of [[1, 'down'], [4, 'up']]) {
    const result = run(['scale', direction], [{ ...internal, scale }]);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.actions, '');
  }
  const tiny = run(['scale', 'up'], [{ ...internal, width: 1, height: 1 }]);
  assert.equal(tiny.status, 0, tiny.stderr);
  assert.equal(tiny.actions, '');
  const focused = run(['scale', 'up'], [{ ...internal, focused: false }, { ...external, focused: true }]);
  assert.equal(focused.status, 0, focused.stderr);
  assert.match(focused.actions, /output = "HDMI-A-1"/);
});

test('absent focus or invalid scale data has no effect', () => {
  for (const monitors of [[], [external], [{ ...internal, width: 0 }], [{ ...internal, height: 'bad' }], [{ ...internal, scale: '1;bad()' }]]) {
    const result = run(['scale', 'up'], monitors);
    assert.equal(result.status, 4);
    assert.equal(result.actions, '');
  }
});

test('session query and mutation failures remain failures', () => {
  assert.equal(run(['laptop'], undefined, { QUERY_FAIL: '1' }).status, 4);
  assert.equal(run(['laptop'], undefined, { EVAL_FAIL: '1' }).status, 5);
  assert.equal(run(['laptop'], undefined, { EVAL_RESULT: 'Lua error' }).status, 5);
});

test('delivery declares the parser, owned helper and tracked bindings with postconditions', () => {
  const apply = fs.readFileSync(path.join(provider, 'apply'), 'utf8');
  assert.match(apply, /cfg_system_file "\$STEP_DIR\/display" \/usr\/share\/mirroros\/hardware\/display 0755/);
  assert.match(apply, /cfg_require cfg_system_file_present \/usr\/share\/mirroros\/hardware\/display/);
  assert.match(apply, /cfg_tracked_file "\$STEP_DIR\/hardware-bindings.lua"/);
  assert.match(apply, /cfg_require cfg_tracked_file_present \/usr\/share\/mirroros\/hypr\/hardware-bindings.lua/);
  assert.match(fs.readFileSync(path.join(provider, 'packages'), 'utf8'), /^jq extra$/m);
  const helper = fs.readFileSync(path.join(provider, 'display'), 'utf8');
  assert.doesNotMatch(helper, /hyprctl reload|monitors\.lua|personal-monitors\.lua/);
});
