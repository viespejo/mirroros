// Runtime display contracts with a recording hyprctl; no compositor or physical output is changed.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
const provider = path.join(root, 'capabilities/desktop/compositor/providers/hyprland');
const internal = { name: 'eDP-1', disabled: false, mirrorOf: 'none', focused: true, width: 1920, height: 1080, scale: 1 };
const external = { ...internal, name: 'HDMI-A-1', focused: false };
function fixture(monitors) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mirroros-display-'));
  fs.writeFileSync(path.join(dir, 'monitors.json'), typeof monitors === 'string' ? monitors : JSON.stringify(monitors));
  // eval applies runtime disables, enables and scales to a pending state that monitors queries report only after
  // SETTLE_QUERIES further queries, as Hyprland applies monitor changes asynchronously.
  fs.writeFileSync(path.join(dir, 'hyprctl'), `#!/usr/bin/bash
set -Eeuo pipefail
printf '%s\\n' "$*" >> "$TEST_DIR/calls"
case "$1" in
  monitors) [[ "$*" == 'monitors all -j' ]] || exit 9
    [[ "\${QUERY_FAIL:-0}" == 0 ]] || exit 1
    if [[ -f "$TEST_DIR/pending.json" ]]; then
      left=$(<"$TEST_DIR/settle")
      if (( left > 0 )); then printf '%s' $((left - 1)) > "$TEST_DIR/settle"
      else mv "$TEST_DIR/pending.json" "$TEST_DIR/monitors.json"; fi
    fi
    /usr/bin/cat "$TEST_DIR/monitors.json" ;;
  -j) [[ "$*" == '-j getoption cursor:no_hardware_cursors' ]] || exit 9
    [[ "\${CURSOR_FAIL:-0}" == 0 ]] || exit 1
    option='{"option":"cursor:no_hardware_cursors","int":2,"set":true}'
    printf '%s\\n' "\${CURSOR_OPTION:-$option}" ;;
  eval) sleep "\${EVAL_DELAY:-0}"
    printf '%s' "$2" >> "$TEST_DIR/actions"
    [[ "\${EVAL_FAIL:-0}" == 0 ]] || exit 1
    cp "$TEST_DIR/monitors.json" "$TEST_DIR/next.json"
    while read -r name field value; do
      [[ -n "$name" ]] || continue
      jq --arg name "$name" --arg field "$field" --argjson value "$value" \\
        'map(if .name == $name then .[$field] = $value else . end)' "$TEST_DIR/next.json" > "$TEST_DIR/next.tmp"
      mv "$TEST_DIR/next.tmp" "$TEST_DIR/next.json"
    done < <({ grep -oP 'output = "[^"]+", (disabled|scale) = [a-z0-9.]+' <<< "$2" | sed -E 's/^output = "([^"]+)", ([a-z]+) = (.*)$/\\1 \\2 \\3/'
      grep -oP 'output = "[^"]+", [^}]*?scale = [0-9.]+' <<< "$2" | sed -E 's/^output = "([^"]+)", .*scale = ([0-9.]+)$/\\1 scale \\2/'; } || true)
    mv "$TEST_DIR/next.json" "$TEST_DIR/pending.json"
    printf '%s' "\${SETTLE_QUERIES:-0}" > "$TEST_DIR/settle"
    printf '%s\\n' "\${EVAL_RESULT:-ok}" ;;
  *) exit 9 ;;
esac
`, { mode: 0o755 });
  fs.writeFileSync(path.join(dir, 'brightnessctl'), `#!/usr/bin/bash
[[ "\${BACKLIGHT:-}" != '' ]] || exit 1
printf 'intel_backlight,backlight,48000,%s%%,96000\\n' "$BACKLIGHT"
`, { mode: 0o755 });
  return dir;
}
function env(dir, options = {}) {
  return { ...process.env, HOME: dir, PATH: `${dir}:${process.env.PATH}`, TEST_DIR: dir, XDG_RUNTIME_DIR: dir, ...options };
}
function run(args, monitors = [internal, external], options = {}, record) {
  const dir = fixture(monitors);
  const recordFile = path.join(dir, 'mirroros-display-mirror.json');
  try {
    if (typeof record === 'function') record(recordFile);
    else if (record !== undefined) fs.writeFileSync(recordFile, typeof record === 'string' ? record : JSON.stringify(record));
    const personal = path.join(dir, '.config/hypr');
    fs.mkdirSync(personal, { recursive: true });
    for (const file of ['monitors.lua', 'personal-monitors.lua']) fs.writeFileSync(path.join(personal, file), '-- personal\n');
    const result = spawnSync('bash', [path.join(provider, 'display'), ...args], { encoding: 'utf8', env: env(dir, options) });
    for (const file of ['monitors.lua', 'personal-monitors.lua']) assert.equal(fs.readFileSync(path.join(personal, file), 'utf8'), '-- personal\n');
    assert.deepEqual(fs.readdirSync(personal).sort(), ['monitors.lua', 'personal-monitors.lua']);
    return { ...result, actions: fs.existsSync(path.join(dir, 'actions')) ? fs.readFileSync(path.join(dir, 'actions'), 'utf8') : '',
      calls: fs.existsSync(path.join(dir, 'calls')) ? fs.readFileSync(path.join(dir, 'calls'), 'utf8') : '',
      record: fs.existsSync(recordFile) ? fs.readFileSync(recordFile, 'utf8') : null,
      recordMode: fs.existsSync(recordFile) ? fs.statSync(recordFile).mode & 0o777 : null };
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}

test('invalid argv is rejected before contacting Hyprland', () => {
  for (const args of [[], ['unknown'], ['laptop', 'extra'], ['mirror', 'extra'], ['scale'], ['scale', 'up', 'extra'], ['scale', '5'], ['scale', '0.5'], ['scale', '1.25;bad()'], ['clamshell'], ['clamshell', 'toggle'],
    ['clamshell', 'open', 'extra'], ['output'], ['output', 'eDP-1'], ['output', 'eDP-1', 'toggle'], ['output', 'bad name', 'off'],
    ['output', 'HDMI-A-1")', 'off'], ['output', 'eDP-1', 'off', 'extra'], ['state', 'extra']]) {
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

const layout = { name: 'HDMI-A-1', width: 3440, height: 1440, refreshRate: 59.973, x: 0, y: 0, scale: 1.6 };
const restore = 'hl.monitor({ output = "HDMI-A-1", disabled = false, mirror = "", mode = "3440x1440@59.973", position = "0x0", scale = 1.6 }); ';

test('mirroring records the external layout privately only once Hyprland confirms it', () => {
  const placed = { ...external, ...layout, mirrorOf: 'none', focused: false };
  const result = run(['mirror'], [internal, placed]);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.record), { ...layout, cursor: 2 });
  assert.equal(result.recordMode, 0o600);
  const failed = run(['mirror'], [internal, placed], { EVAL_FAIL: '1' });
  assert.equal(failed.status, 5);
  assert.equal(failed.record, null);
});

test('ending a mirror restores the recorded layout from the toggle or before disabling its source', () => {
  const mirrored = { ...mirrorOutput, scale: 1, x: 1200 };
  const toggled = run(['mirror'], [mirrorSource, mirrored], {}, layout);
  assert.equal(toggled.status, 0, toggled.stderr);
  assert.ok(toggled.actions.endsWith(restore), toggled.actions);
  assert.equal(toggled.record, null);
  for (const args of [['output', 'eDP-1', 'off'], ['laptop']]) {
    const result = run(args, [mirrorSource, mirrored], {}, layout);
    assert.equal(result.status, 0, result.stderr);
    assert.ok(result.actions.startsWith(restore), result.actions);
    assert.ok(result.actions.indexOf(restore) < result.actions.indexOf('output = "eDP-1", disabled = true'));
    assert.equal(result.record, null);
  }
});

test('missing, foreign, malformed or linked mirror records only detach the mirror', () => {
  const linked = (file) => { fs.writeFileSync(`${file}.target`, JSON.stringify(layout)); fs.symlinkSync(`${file}.target`, file); };
  for (const record of [undefined, { ...layout, name: 'DP-2' }, '{bad', { ...layout, x: '0"); os.execute("bad") --' },
    { ...layout, refreshRate: '60' }, { ...layout, scale: 0 }, { ...layout, width: 1.5 }, [layout], linked]) {
    const result = run(['mirror'], [mirrorSource, mirrorOutput], {}, record);
    assert.equal(result.status, 0, result.stderr);
    assert.ok(result.actions.endsWith('hl.monitor({ output = "HDMI-A-1", disabled = false, mirror = "" }); '), result.actions);
    assert.doesNotMatch(result.actions, /position = |bad/);
  }
});

const software = 'hl.config({ cursor = { no_hardware_cursors = 1 } }); ';

test('mirroring sets software cursors first and ending it restores the recorded cursor setting', () => {
  const placed = { ...external, ...layout, mirrorOf: 'none', focused: false };
  const result = run(['mirror'], [internal, placed], { CURSOR_OPTION: '{"option":"cursor:no_hardware_cursors","int":0,"set":true}' });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.record).cursor, 0);
  assert.ok(result.actions.includes(software), result.actions);
  assert.ok(result.actions.indexOf(software) < result.actions.indexOf('mirror = "eDP-1"'));
  const mirrored = { ...mirrorOutput, scale: 1, x: 1200 };
  for (const args of [['mirror'], ['output', 'eDP-1', 'off'], ['laptop']]) {
    const detached = run(args, [mirrorSource, mirrored], {}, { ...layout, cursor: 0 });
    assert.equal(detached.status, 0, detached.stderr);
    assert.ok(detached.actions.includes(`${restore}hl.config({ cursor = { no_hardware_cursors = 0 } }); `), detached.actions);
    assert.equal(detached.record, null);
  }
});

test('an unreadable cursor setting leaves the cursor untouched and a malformed recorded one is ignored', () => {
  const placed = { ...external, ...layout, mirrorOf: 'none', focused: false };
  for (const options of [{ CURSOR_FAIL: '1' }, { CURSOR_OPTION: '{bad' }, { CURSOR_OPTION: '{"int":"1"}' },
    { CURSOR_OPTION: '{"int":7}' }, { CURSOR_OPTION: '{"str":"2"}' }]) {
    const result = run(['mirror'], [internal, placed], options);
    assert.equal(result.status, 0, result.stderr);
    assert.doesNotMatch(result.actions, /cursor/);
    assert.deepEqual(JSON.parse(result.record), layout);
  }
  const mirrored = { ...mirrorOutput, scale: 1, x: 1200 };
  for (const cursor of ['1 } }); os.execute("bad") --', 7, -1, 1.5, null, true]) {
    const result = run(['mirror'], [mirrorSource, mirrored], {}, { ...layout, cursor });
    assert.equal(result.status, 0, result.stderr);
    assert.ok(result.actions.endsWith(restore), result.actions);
    assert.doesNotMatch(result.actions, /cursor|bad/);
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

const mirrorSource = { ...internal, id: 0 };
const mirrorOutput = { ...external, id: 1, mirrorOf: '0' };
const third = { ...external, id: 2, name: 'DP-2', focused: false };

test('output toggles enable or disable a named output at runtime only', () => {
  const off = run(['output', 'HDMI-A-1', 'off']);
  assert.equal(off.status, 0, off.stderr);
  assert.equal(off.actions, 'hl.monitor({ output = "HDMI-A-1", disabled = true }); ');
  const on = run(['output', 'HDMI-A-1', 'on'], [internal, { ...external, disabled: true }]);
  assert.equal(on.status, 0, on.stderr);
  assert.equal(on.actions, 'hl.monitor({ output = "HDMI-A-1", disabled = false }); ');
  for (const [args, monitors] of [[['output', 'HDMI-A-1', 'on'], [internal, external]], [['output', 'HDMI-A-1', 'off'], [internal, { ...external, disabled: true }]]]) {
    const unchanged = run(args, monitors);
    assert.equal(unchanged.status, 0, unchanged.stderr);
    assert.equal(unchanged.actions, '');
  }
  const missing = run(['output', 'DP-9', 'on']);
  assert.equal(missing.status, 4);
  assert.equal(missing.actions, '');
});

test('the last enabled or independent output is never disabled', () => {
  for (const monitors of [[internal], [internal, { ...external, disabled: true }]]) {
    const result = run(['output', 'eDP-1', 'off'], monitors);
    assert.equal(result.status, 4);
    assert.equal(result.actions, '');
    assert.match(result.stderr, /last enabled display/);
  }
  // HDMI-A-1 mirrors eDP-1 and DP-2 mirrors HDMI-A-1: disabling HDMI-A-1 leaves eDP-1 independent.
  const chained = run(['output', 'HDMI-A-1', 'off'], [mirrorSource, mirrorOutput, { ...third, mirrorOf: '1' }]);
  assert.equal(chained.status, 0, chained.stderr);
  // DP-3 mirrors DP-2, not eDP-1, so it is not independent and eDP-1 is the last independent output.
  const single = run(['output', 'eDP-1', 'off'], [mirrorSource, { ...third, disabled: true }, { ...mirrorOutput, id: 3, name: 'DP-3', mirrorOf: '2' }]);
  assert.equal(single.status, 4);
  assert.equal(single.actions, '');
});

test('disabling a mirror source detaches its mirrors first and keeps an image', () => {
  const result = run(['output', 'eDP-1', 'off'], [mirrorSource, mirrorOutput]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.actions, 'hl.monitor({ output = "HDMI-A-1", disabled = false, mirror = "" }); hl.monitor({ output = "eDP-1", disabled = true }); ');
  const unrelated = run(['output', 'DP-2', 'off'], [mirrorSource, mirrorOutput, third]);
  assert.equal(unrelated.status, 0, unrelated.stderr);
  assert.equal(unrelated.actions, 'hl.monitor({ output = "DP-2", disabled = true }); ');
});

test('concurrent output disables are serialized and leave one output enabled', async () => {
  const dir = fixture([internal, external]);
  try {
    const start = (name) => new Promise((resolve) => {
      const child = spawn('bash', [path.join(provider, 'display'), 'output', name, 'off'], { env: env(dir, { EVAL_DELAY: '0.5', SETTLE_QUERIES: '3' }) });
      let stderr = '';
      child.stderr.on('data', (chunk) => { stderr += chunk; });
      child.on('close', (status) => resolve({ status, stderr }));
    });
    const results = await Promise.all([start('eDP-1'), start('HDMI-A-1')]);
    assert.deepEqual(results.map((result) => result.status).sort(), [0, 4]);
    const monitors = JSON.parse(fs.readFileSync(path.join(dir, 'monitors.json'), 'utf8'));
    assert.equal(monitors.filter((monitor) => monitor.disabled !== true).length, 1);
    assert.equal(fs.readFileSync(path.join(dir, 'calls'), 'utf8').match(/^eval /gm).length, 1);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('mutations hold until Hyprland reports the change and fail when it never does', () => {
  for (const [args, monitors] of [[['scale', '2'], [internal, external]], [['output', 'HDMI-A-1', 'on'], [internal, { ...external, disabled: true }]],
    [['output', 'HDMI-A-1', 'off'], [internal, external]]]) {
    const result = run(args, monitors, { SETTLE_QUERIES: '3' });
    assert.equal(result.status, 0, result.stderr);
    const after = result.calls.slice(result.calls.indexOf('eval '));
    assert.equal(after.match(/^monitors all -j$/gm).length, 4, args.join(' '));
  }
  const stuck = run(['scale', '2'], [internal, external], { SETTLE_QUERIES: '1000' });
  assert.equal(stuck.status, 5);
  assert.match(stuck.stderr, /not confirmed/);
});

test('absolute scale applies only clean scales to the focused display', () => {
  for (const [value, expected] of [['2', '2'], ['1.25', '1.25'], ['1.6', '1.6']]) {
    const result = run(['scale', value], [internal, external]);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.actions, `hl.monitor({ output = "eDP-1", scale = ${expected} }); `);
  }
  const unchanged = run(['scale', '1']);
  assert.equal(unchanged.status, 0, unchanged.stderr);
  assert.equal(unchanged.actions, '');
  // 1366x768 has no clean 1.25 or 1.6; the refusal happens after the read, without mutation.
  for (const value of ['1.25', '1.6', '1.3']) {
    const result = run(['scale', value], [{ ...internal, width: 1366, height: 768 }]);
    assert.equal(result.status, 2, value);
    assert.equal(result.actions, '');
  }
});

test('state reports outputs, focus, mirrors and backlight without mutation', () => {
  const result = run(['state'], [mirrorSource, mirrorOutput, { ...third, disabled: true }], { BACKLIGHT: '42' });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.actions, '');
  assert.doesNotMatch(result.calls, /^eval/m);
  const state = JSON.parse(result.stdout);
  assert.equal(state.focused, 'eDP-1');
  assert.equal(state.internal, 'eDP-1');
  assert.equal(state.external, 'HDMI-A-1');
  assert.equal(state.backlight, 42);
  assert.deepEqual(state.outputs.map((output) => [output.name, output.enabled, output.internal, output.mirror]),
    [['eDP-1', true, true, null], ['HDMI-A-1', true, false, 'eDP-1'], ['DP-2', false, false, null]]);
  assert.deepEqual(Object.keys(state.outputs[0]).sort(), ['enabled', 'focused', 'height', 'internal', 'mirror', 'name', 'scale', 'width']);
  const dark = run(['state'], [external]);
  assert.equal(dark.status, 0, dark.stderr);
  assert.equal(JSON.parse(dark.stdout).backlight, null);
  assert.equal(JSON.parse(dark.stdout).internal, null);
  assert.equal(run(['state'], undefined, { QUERY_FAIL: '1' }).status, 4);
});

test('mutations without a user runtime directory are unavailable and state still works', () => {
  const result = run(['output', 'HDMI-A-1', 'off'], undefined, { XDG_RUNTIME_DIR: '' });
  assert.equal(result.status, 4);
  assert.equal(result.calls, '');
  assert.equal(run(['state'], undefined, { XDG_RUNTIME_DIR: '' }).status, 0);
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
