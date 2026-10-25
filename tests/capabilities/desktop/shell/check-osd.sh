#!/usr/bin/bash
# Controlled OSD events do not qualify audio or brightness hardware.
set -Eeuo pipefail
tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shell_dir=$(cd "$tests_dir/../../../../capabilities/desktop/shell" && pwd)
for tool in node qs hyprctl busctl notify-send; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
node "$tests_dir/qmllint-check.mjs"
node --input-type=module - "$shell_dir/osd/OsdModel.js" <<'JS'
import fs from 'node:fs'; import vm from 'node:vm'; import assert from 'node:assert/strict';
const context = vm.createContext({ module: {exports:{}} });
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), context);
const {stateForShow, iconFor} = context.module.exports;
const progress = stateForShow('', '', '37', '100', '', '500');
assert.equal(progress.hasProgress, true); assert.equal(progress.message, '37%');
assert.equal(progress.value, 37); assert.equal(progress.duration, 500);
assert.equal(stateForShow('', '', '150', '100', '', '0').value, 100);
assert.equal(stateForShow('', '', '-5', '100', '', '0').value, 0);
assert.equal(stateForShow('media', 'Synthetic media', '', '100', '', '0').hasProgress, false);
assert.notEqual(iconFor('', 0), iconFor('', 100));
console.log('PASS upstream model: progress, clamp, message mode and icon ladder');
JS
if [[ -z "${WAYLAND_DISPLAY:-}" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED no reachable Wayland session\n'; exit 2
fi
owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications)
[[ "$owner" == 'b false' ]] || { printf 'BLOCKED Notifications already owned; no replacement attempted\n'; exit 2; }
tmp=$(mktemp -d)
pid=""
cleanup() {
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
    rm -rf "$tmp"
}
trap cleanup EXIT
cp -r "$shell_dir" "$tmp/shell"
mkdir -p "$tmp/home" "$tmp/config" "$tmp/data/applications" "$tmp/state"
node --input-type=module - "$tmp/shell/osd/Osd.qml" "$tmp/shell/shell.qml" <<'JS'
import fs from 'node:fs';
const file = process.argv[2];
let qml = fs.readFileSync(file, 'utf8');
qml = qml.replace('  IpcHandler {', `
  IpcHandler {
    target: "osdTest"
    function snapshot(): string {
      return JSON.stringify({ opened: root.opened, value: root.value, max: root.maxValue,
        message: root.message, icon: root.icon, hasProgress: root.hasProgress,
        visible: panel.visible, width: card.width, contentWidth: root.contentWidth,
        keyboardFocus: panel.shownKeyboardFocus })
    }
  }
  IpcHandler {`);
fs.writeFileSync(file, qml);
const entry = process.argv[3];
qml = fs.readFileSync(entry, 'utf8').replace('import Quickshell\n', 'import Quickshell\nimport Quickshell.Io\n');
qml = qml.trimEnd().slice(0, -1) + `
  IpcHandler {
    target: "osdRootTest"
    function summon(): bool { return desktopShell.summon("omarchy.osd", '{"value":62,"duration":0}') }
  }
}
`;
fs.writeFileSync(entry, qml);
JS
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" \
    MIRROROS_SHELL_STATE_DIR="$tmp/state" qs -p "$tmp/shell" > "$tmp/shell.log" 2>&1 &
pid=$!
# -- keeps method names such as show from being parsed as CLI subcommands.
ipc() { qs ipc -p "$tmp/shell" call -- osd "$@"; }
snapshot() { qs ipc -p "$tmp/shell" call osdTest snapshot; }
for ((i = 0; i < 100; i++)); do
    if ipc ping > /dev/null 2>&1; then break; fi
    if ! kill -0 "$pid" 2>/dev/null; then printf 'FAIL shell exited\n%s\n' "$(<"$tmp/shell.log")"; exit 1; fi
    sleep 0.1
done
[[ "$(ipc state)" == closed ]]
ipc show '{"value":37,"duration":800}' >/dev/null
sleep 0.3
snapshot > "$tmp/progress.json"
node --input-type=module - "$tmp/progress.json" <<'JS'
import fs from 'node:fs'; import assert from 'node:assert/strict';
const s = JSON.parse(fs.readFileSync(process.argv[2]));
assert.equal(s.opened, true); assert.equal(s.visible, true); assert.equal(s.hasProgress, true);
assert.equal(s.value,37); assert.equal(s.message,'37%');
assert.ok(s.width > s.contentWidth); assert.equal(s.keyboardFocus,0);
JS
hyprctl layers | grep -q mirroros-osd
sleep 1
[[ "$(ipc state)" == closed ]]
if hyprctl layers | grep -q mirroros-osd; then printf 'FAIL expired OSD layer still mapped\n'; exit 1; fi
printf 'PASS controlled progress maps the OSD without keyboard focus; timer closes and unmaps it\n'
ipc show '{"icon":"media","message":"Synthetic media title","duration":0}' >/dev/null
sleep 1.4
snapshot > "$tmp/message.json"
node --input-type=module - "$tmp/message.json" <<'JS'
import fs from 'node:fs'; import assert from 'node:assert/strict';
const s = JSON.parse(fs.readFileSync(process.argv[2]));
assert.equal(s.opened,true); assert.equal(s.hasProgress,false); assert.equal(s.message,'Synthetic media title');
JS
ipc close >/dev/null
[[ "$(ipc state)" == closed ]]
[[ "$(qs ipc -p "$tmp/shell" call osdRootTest summon)" == true ]]
snapshot > "$tmp/root.json"
node -e 'if(JSON.parse(require("fs").readFileSync(process.argv[1])).value!==62)process.exit(1)' "$tmp/root.json"
ipc close >/dev/null
printf 'PASS message mode, duration zero, explicit close and shell.summon delegation\n'
for source in volume brightness; do
    ipc showSource "$source" >/dev/null
    sleep 0.6
    ipc source "$source" > "$tmp/source.json"
    snapshot > "$tmp/source-osd.json"
    node --input-type=module - "$source" "$tmp/source.json" "$tmp/source-osd.json" <<'JS'
import fs from 'node:fs'; import assert from 'node:assert/strict';
const source=process.argv[2], s=JSON.parse(fs.readFileSync(process.argv[3]));
const shown=JSON.parse(fs.readFileSync(process.argv[4]));
assert.equal(shown.opened,true);
if(s.available) {
 assert.equal(shown.hasProgress,true); assert.equal(shown.value,Math.min(100,Math.max(0,s.value)));
 console.log(`PASS ${source} read-only native level; hardware controls NOT exercised`);
} else {
 assert.equal(shown.hasProgress,false); assert.ok(s.reason.length > 0); assert.equal(shown.message,s.reason);
 console.log(`PASS ${source} unavailable: ${s.reason}; hardware validation pending`);
}
JS
    ipc close >/dev/null
done
# Whole-shell smoke in this same instance, with synthetic notification text only.
hyprctl layers | grep -q mirroros-bar
notify-send --app-name=MirrorOS-Synthetic --urgency=critical 'Synthetic composed shell' 'Disposable smoke fixture'
for ((i = 0; i < 50; i++)); do
    [[ "$(qs ipc -p "$tmp/shell" call notifications count)" == 1 ]] && break
    sleep 0.1
done
[[ "$(qs ipc -p "$tmp/shell" call notifications count)" == 1 ]]
hyprctl layers | grep -q mirroros-notifications
qs ipc -p "$tmp/shell" call notifications dismissAll >/dev/null
sleep 0.6
[[ "$(qs ipc -p "$tmp/shell" call notifications count)" == 0 ]]
qs ipc -p "$tmp/shell" call menu toggle root >/dev/null
sleep 0.4
hyprctl layers | grep -q mirroros-menu
qs ipc -p "$tmp/shell" call menu toggle root >/dev/null
[[ "$(qs ipc -p "$tmp/shell" call menu isOpen)" == false ]]
printf 'PASS composed smoke: bar, synthetic notification/dismissal, OSD and menu\n'
kill "$pid"; wait "$pid" 2>/dev/null || true; pid=""
warnings=$(grep -E 'WARN|ERROR|Warning|Error|TypeError|ReferenceError|Binding loop' "$tmp/shell.log" \
    | grep -vE 'qt.qpa.wayland.textinput.*(has focus|QWaylandTextInputv3::disableSurface.*Trying to disable .* but .* is focused)' || true)
[[ -z "$warnings" ]] || { printf 'FAIL OSD log not quiet\n%s\n' "$warnings"; exit 1; }
printf 'PASS OSD synthetic events and real-source availability; no volume/brightness changed\n'
