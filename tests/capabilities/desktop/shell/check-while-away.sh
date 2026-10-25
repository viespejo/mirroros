#!/usr/bin/bash
# DEC-021/022 while-away count checks. Synthetic notifications only, isolated
# HOME/XDG and state, and a synthetic lock marker (MIRROROS_SHELL_LOCK_MARKER):
# the session is never locked here and no input is injected. The real
# compositor-backed lock signals are exercised by the attended lock procedure.
#
# Usage: tests/capabilities/desktop/shell/check-while-away.sh
# Exit codes: 0 pass, 1 a check failed, 2 blocked.
set -Eeuo pipefail
tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shell_dir=$(cd "$tests_dir/../../../../capabilities/desktop/shell" && pwd)
for tool in node qs busctl notify-send; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
if [[ -z "${WAYLAND_DISPLAY:-}" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED no reachable Wayland session\n'; exit 2
fi
tmp=$(mktemp -d)
pid=""
cleanup() {
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
    rm -rf "$tmp"
}
trap cleanup EXIT
run_dir="$tmp/shell"
cp -r "$shell_dir" "$run_dir"
mkdir -p "$tmp/home" "$tmp/config" "$tmp/data/applications" "$tmp/state"
marker="$tmp/locked"
away="$tmp/state/notifications/while-away.json"
node --input-type=module - "$run_dir/shell.qml" <<'JS'
import fs from 'node:fs';
const file = process.argv[2];
let qml = fs.readFileSync(file, 'utf8').replace('import Quickshell\n', 'import Quickshell\nimport Quickshell.Io\n');
qml = qml.trimEnd().slice(0, -1) + `
  IpcHandler {
    target: "whileAwayTest"
    function state(): string {
      var s = desktopShell.notificationService
      var p = s.openPanel
      return JSON.stringify({ ready: s.liveLoaded && s.historyLoaded && s.quietLoaded && s.awayLoaded && s.lockKnown,
        configLoaded: desktopShell.shellConfigStore.loaded, locked: s.lockedNow, count: s.whileAwayCount,
        panelOpen: !!p, settings: p ? p.settingsView : false, historyExpanded: p ? p.historyExpanded : false })
    }
    function expandHistory(): string {
      var p = desktopShell.notificationService.openPanel
      if (!p) return "no panel"
      p.historyExpanded = true
      return "ok"
    }
  }
}
`;
fs.writeFileSync(file, qml);
JS
ipc() { qs ipc -p "$run_dir" call notifications "$@"; }
state() { qs ipc -p "$run_dir" call whileAwayTest state; }
pass() { printf 'PASS %s\n' "$1"; }
# expect JS-EXPRESSION DESCRIPTION: waits up to 5 s for the shell state to satisfy it.
expect() {
    for ((i = 0; i < 50; i++)); do
        state > "$tmp/snapshot.json" 2>/dev/null || true
        if node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1]));if(!(new Function("s","return "+process.argv[2]))(s))process.exit(1)' \
            "$tmp/snapshot.json" "$1" 2>/dev/null; then pass "$2"; return; fi
        sleep 0.1
    done
    printf 'FAIL %s (state: %s)\n' "$2" "$(cat "$tmp/snapshot.json")"; exit 1
}
# saved COUNT LOCKED: the persisted state, after the save delay.
saved() {
    sleep 0.6
    node --input-type=module - "$away" "$1" "$2" <<'JS'
import fs from 'node:fs'; import assert from 'node:assert/strict';
const [file, count, locked] = process.argv.slice(2);
assert.deepEqual(JSON.parse(fs.readFileSync(file, 'utf8')), { version: 1, locked: locked === 'true', count: Number(count) });
JS
}
start() {
    local owner
    owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications)
    [[ "$owner" == 'b false' ]] || { printf 'BLOCKED Notifications already owned; no replacement attempted\n'; exit 2; }
    HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" \
        MIRROROS_SHELL_STATE_DIR="$tmp/state" MIRROROS_SHELL_LOCK_MARKER="$marker" \
        qs -p "$run_dir" >> "$tmp/shell.log" 2>&1 &
    pid=$!
    for ((i = 0; i < 100; i++)); do
        if state > "$tmp/ready.json" 2>/dev/null && node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1]));if(!s.ready||!s.configLoaded)process.exit(1)' "$tmp/ready.json"; then
            sleep 0.5; return
        fi
        if ! kill -0 "$pid" 2>/dev/null; then printf 'FAIL shell exited\n%s\n' "$(<"$tmp/shell.log")"; exit 1; fi
        sleep 0.1
    done
    printf 'FAIL shell not ready\n%s\n' "$(<"$tmp/shell.log")"; exit 1
}
stop() { kill "$pid"; wait "$pid" 2>/dev/null || true; pid=""; }
send() { notify-send --app-name=MirrorOS-Synthetic "$@"; }
lock() { : > "$marker"; ipc lockChanged >/dev/null; }
unlock() { rm -f -- "$marker"; ipc lockChanged >/dev/null; }

start
expect 's.locked === false && s.count === 0' 'unlocked start: no count'
send 'Synthetic unlocked arrival' 'Not counted'
saved 0 false
pass 'arrivals while unlocked are not counted'

lock
expect 's.locked === true' 'lock marker reread through lockChanged'
send 'Synthetic away one' 'Counted'
send --urgency=critical 'Synthetic away two' 'Counted'
id=$(send --print-id 'Synthetic away three' 'Counted once')
send --replace-id="$id" 'Synthetic away three updated' 'Replacement is not a new arrival'
send --transient 'Synthetic transient' 'Ephemeral, not counted'
expect 's.count === 0' 'count hidden while locked'
saved 3 true
pass 'locked arrivals counted once; replacement and transient excluded'

stop
start
expect 's.locked === true && s.count === 0' 'restart while locked reconciles from the marker'
send 'Synthetic away after restart' 'Counted'
saved 4 true
pass 'counting continues after a restart during the lock'

unlock
expect 's.locked === false && s.count === 4' 'count shown on return; unlock does not clear it'
stop
start
expect 's.locked === false && s.count === 4' 'count survives a restart after return'

ipc openPanel >/dev/null
expect 's.panelOpen === true && s.historyExpanded === false && s.count === 4' 'opening the panel alone keeps the count'
ipc openSettings >/dev/null
expect 's.settings === true && s.count === 4' 'preferences view keeps the count'
ipc closePanel >/dev/null
expect 's.panelOpen === false' 'panel closed'
ipc openPanel >/dev/null
expect 's.panelOpen === true' 'panel reopened'
[[ "$(qs ipc -p "$run_dir" call whileAwayTest expandHistory)" == ok ]]
expect 's.panelOpen === true && s.historyExpanded === true && s.count === 4' 'expanding history keeps the panel and count while viewing'
ipc closePanel >/dev/null
expect 's.panelOpen === false && s.count === 0' 'closing the panel after viewing history clears the count'
saved 0 false

lock
send 'Synthetic second absence' 'Counted afresh'
unlock
expect 's.count === 1' 'a later lock accumulates afresh'
saved 1 false

[[ "$(stat -c %a "$away")" == 600 ]]
if grep -q Synthetic "$away"; then printf 'FAIL while-away state contains notification content\n'; exit 1; fi
pass 'while-away.json is 0600 and holds only version, lock flag and count'
stop
warnings=$(grep -E 'WARN|ERROR|Warning|Error|TypeError|ReferenceError|Binding loop' "$tmp/shell.log" \
    | grep -vE 'qt.qpa.wayland.textinput.*(has focus|QWaylandTextInputv3::disableSurface.*Trying to disable .* but .* is focused)' || true)
[[ -z "$warnings" ]] || { printf 'FAIL shell log not quiet\n%s\n' "$warnings"; exit 1; }
printf 'PASS synthetic while-away matrix and quiet runtime logs\n'
