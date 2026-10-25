#!/usr/bin/env bash
# Prototype-local bar/config checks, using disposable state and synthetic
# layout edits. No package, service, volume, keyboard or brightness changes.
set -euo pipefail
tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shell_dir=$(cd "$tests_dir/../../../../capabilities/desktop/shell" && pwd)
for tool in node qs hyprctl busctl; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
node "$tests_dir/qmllint-check.mjs"
if [[ -z "${WAYLAND_DISPLAY:-}" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED no reachable Wayland session\n'; exit 2
fi

tmp=$(mktemp -d)
pid=""
cleanup() {
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi
    rm -rf "$tmp"
}
trap cleanup EXIT
run_dir="$tmp/shell"
cp -r "$shell_dir" "$run_dir"
mkdir -p "$tmp/home" "$tmp/config" "$tmp/data/applications" "$tmp/state"
prefs="$tmp/config/mirroros/shell.json"
# A test-only handler, never installed in the product shell.
node - "$run_dir/shell.qml" <<'JS'
const fs = require('node:fs');
const file = process.argv[2];
let qml = fs.readFileSync(file, 'utf8').replace('import Quickshell\n', 'import Quickshell\nimport Quickshell.Io\n');
qml = qml.trimEnd().slice(0, -1) + `
  IpcHandler {
    target: "barTest"
    function state(): string {
      return JSON.stringify({
        loaded: desktopShell.shellConfigStore.loaded,
        userStatus: desktopShell.shellConfigStore.userStatus,
        path: desktopShell.shellConfigStore.configPath,
        config: desktopShell.shellConfig,
        position: desktopShell.bar.position,
        barSize: desktopShell.bar.barSize,
        slots: desktopShell.bar.moduleSlots.map(function(slot) {
          var window = slot.QsWindow.window
          var point = window ? slot.mapToItem(window.contentItem, 0, 0) : { x: 0, y: 0 }
          return { id: slot.moduleName, region: slot.region, width: slot.width,
            x: point.x, visible: slot.activeItem ? slot.activeItem.visible : false,
            screenWidth: window ? window.width : 0 }
        })
      })
    }
    function cycleClock(): bool {
      var items = desktopShell.bar.moduleWidgets("omarchy.clock")
      if (!items.length) return false
      items[0].cycleFormat()
      return true
    }
    function noChange(): bool {
      var entry = desktopShell.shellConfig.bar.layout.center[0]
      return desktopShell.updateEntryInline(entry.id, entry)
    }
    function toggleMenu(): bool { return desktopShell.toggle("menu") }
  }
}
`;
fs.writeFileSync(file, qml);
JS

start() {
    local owner
    owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications)
    [[ "$owner" == 'b false' ]] || { printf 'BLOCKED Notifications already owned; no replacement attempted\n'; exit 2; }
    HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" \
        MIRROROS_SHELL_STATE_DIR="$tmp/state" qs -p "$run_dir" > "$tmp/shell.log" 2>&1 &
    pid=$!
    local state=""
    for ((i = 0; i < 80; i++)); do
        if state=$(ipc state 2>/dev/null) && node -e 'if (!JSON.parse(process.argv[1]).loaded) process.exit(1)' "$state"; then
            sleep 0.5
            return
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            printf 'FAIL shell exited\n'; printf '%s\n' "$(<"$tmp/shell.log")"; exit 1
        fi
        sleep 0.1
    done
    printf 'FAIL shell did not become ready\n'; printf '%s\n' "$(<"$tmp/shell.log")"; exit 1
}
ipc() { qs ipc -p "$run_dir" call barTest "$@"; }
quiet() {
    # The sole known Brief 1 Qt text-input warning is not shell noise.
    local warnings
    warnings=$(grep -E 'WARN|ERROR|Warning|Error|TypeError|ReferenceError|Binding loop' "$tmp/shell.log" \
        | grep -v 'qt.qpa.wayland.textinput.*has focus' || true)
    if [[ -n "$warnings" ]]; then printf 'FAIL shell log is not quiet\n%s\n' "$warnings"; exit 1; fi
}
stop() {
    kill "$pid"
    wait "$pid" 2>/dev/null || true
    pid=""
    quiet
}

start
ipc state > "$tmp/default.json"
node - "$tmp/default.json" <<'JS'
const fs = require('node:fs'), assert = require('node:assert/strict');
const s = JSON.parse(fs.readFileSync(process.argv[2]));
assert.equal(s.position, 'top');
assert.equal(s.config.version, 1);
assert.deepEqual(s.config.bar.layout.left.map(e => e.id), ['omarchy.menu', 'omarchy.workspaces']);
assert.deepEqual(s.config.bar.layout.right.map(e => e.id), ['omarchy.tray', 'omarchy.keyboard-layout', 'omarchy.bluetooth', 'omarchy.network', 'omarchy.audio', 'omarchy.monitor', 'omarchy.power']);
const clock = s.slots.find(e => e.id === 'omarchy.clock');
assert.ok(clock.width > 0);
assert.ok(Math.abs(clock.x + clock.width / 2 - clock.screenWidth / 2) <= 1, 'clock is centered');
console.log('PASS default static layout and centered clock');
JS
hyprctl layers | grep -q 'mirroros-bar'
[[ ! -e "$prefs" ]] || { printf 'FAIL defaults were unnecessarily persisted\n'; exit 1; }
[[ "$(ipc cycleClock)" == true ]]
sleep 0.8
[[ -s "$prefs" ]]
[[ "$(stat -c %a "$prefs")" == 600 ]]
node - "$prefs" <<'JS'
const fs = require('node:fs'), assert = require('node:assert/strict');
const saved = JSON.parse(fs.readFileSync(process.argv[2]));
assert.deepEqual(Object.keys(saved), ['version', 'bar']);
assert.deepEqual(Object.keys(saved.bar), ['layout']);
assert.deepEqual(Object.keys(saved.bar.layout), ['center']);
console.log('PASS saving one option stores only that list, no unrelated defaults');
JS
before=$(stat -c '%y' "$prefs")
[[ "$(ipc noChange)" == false ]]
sleep 0.4
[[ "$before" == "$(stat -c '%y' "$prefs")" ]]
printf 'PASS clock setting persisted privately; identical update does not rewrite shell.json\n'
[[ "$(ipc toggleMenu)" == true ]]
sleep 0.5
[[ "$(qs ipc -p "$run_dir" call menu isOpen)" == true ]]
[[ "$(ipc toggleMenu)" == true ]]
sleep 0.3
[[ "$(qs ipc -p "$run_dir" call menu isOpen)" == false ]]
printf 'PASS shell menu toggle delegation\n'
stop

start
ipc state > "$tmp/restart.json"
node - "$prefs" "$tmp/restart.json" <<'JS'
const fs = require('node:fs'), assert = require('node:assert/strict');
const config = JSON.parse(fs.readFileSync(process.argv[2]));
const s = JSON.parse(fs.readFileSync(process.argv[3]));
assert.equal(s.config.bar.layout.center[0].format, config.bar.layout.center[0].format);
console.log('PASS clock format survives shell restart');
config.bar.layout = {
  left: [{ id: 'omarchy.monitor' }, { id: 'synthetic.unknown' }],
  centerBegin: [], center: [{ id: 'omarchy.clock', format: 'HH:mm:ss' }],
  centerEnd: [], right: [{ id: 'omarchy.menu' }]
};
fs.writeFileSync(process.argv[2], JSON.stringify(config) + '\n');
JS
for ((i = 0; i < 50; i++)); do
    ipc state > "$tmp/live.json"
    if node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1])); if(s.config.bar.layout.left[0].id!=="omarchy.monitor")process.exit(1)' "$tmp/live.json"; then break; fi
    sleep 0.1
done
sleep 0.5
ipc state > "$tmp/live.json"
node - "$tmp/live.json" <<'JS'
const fs = require('node:fs'), assert = require('node:assert/strict');
const s = JSON.parse(fs.readFileSync(process.argv[2]));
assert.equal(s.config.bar.layout.center[0].format, 'HH:mm:ss');
assert.equal(s.slots.find(e => e.id === 'omarchy.monitor').region, 'left');
assert.equal(s.slots.find(e => e.id === 'omarchy.menu').region, 'right');
assert.equal(s.slots.find(e => e.id === 'synthetic.unknown').width, 0);
assert.equal(s.slots.find(e => e.id === 'synthetic.unknown').visible, false);
assert.equal(s.slots.length, 4);
console.log('PASS live layout change and silent zero-size unknown id');
JS
stop

# Updated common defaults: uncustomized options follow them, overrides survive,
# removing an override restores the current default.
node - "$run_dir/defaults.json" "$prefs" <<'JS'
const fs = require('node:fs');
const defaults = JSON.parse(fs.readFileSync(process.argv[2]));
defaults.bar.layout.right = [{ id: 'omarchy.power' }];
fs.writeFileSync(process.argv[2], JSON.stringify(defaults, null, 2) + '\n');
fs.writeFileSync(process.argv[3], JSON.stringify({ version: 1, bar: { layout: { left: [{ id: 'omarchy.monitor' }] } } }) + '\n');
JS
start
ipc state > "$tmp/updated.json"
node - "$tmp/updated.json" <<'JS'
const fs = require('node:fs'), assert = require('node:assert/strict');
const s = JSON.parse(fs.readFileSync(process.argv[2]));
assert.equal(s.userStatus, 'valid');
assert.deepEqual(s.config.bar.layout.left.map(e => e.id), ['omarchy.monitor']);
assert.deepEqual(s.config.bar.layout.right.map(e => e.id), ['omarchy.power']);
assert.equal(s.config.bar.layout.center[0].format, 'dddd HH:mm');
console.log('PASS updated defaults apply; explicit override kept; removed override restored default');
JS
stop

# Invalid personal file: defaults apply, nothing is saved, bytes are preserved.
printf '{"version":1,"bar":{"__proto__":{}}}\n' > "$prefs"
sum=$(sha256sum < "$prefs")
start
ipc state > "$tmp/invalid.json"
node - "$tmp/invalid.json" <<'JS'
const fs = require('node:fs'), assert = require('node:assert/strict');
const s = JSON.parse(fs.readFileSync(process.argv[2]));
assert.equal(s.userStatus, 'invalid');
assert.deepEqual(s.config.bar.layout.left.map(e => e.id), ['omarchy.menu', 'omarchy.workspaces']);
JS
[[ "$(ipc cycleClock)" == true ]]
sleep 0.8
[[ "$sum" == "$(sha256sum < "$prefs")" ]]
kill "$pid"; wait "$pid" 2>/dev/null || true; pid=""
grep -q 'Preserving unsupported' "$tmp/shell.log"
printf 'PASS invalid preferences preserved byte-for-byte and reported; defaults used\n'
printf 'PASS bar state, layer, restart, live config and quiet logs (known Qt warning excepted)\n'
