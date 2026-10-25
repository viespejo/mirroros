#!/usr/bin/bash
# Prototype-local checks. All notification text and persisted state are synthetic.
set -Eeuo pipefail
tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shell_dir=$(cd "$tests_dir/../../../../capabilities/desktop/shell" && pwd)
for tool in node qs hyprctl busctl notify-send; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
node "$tests_dir/qmllint-check.mjs"
if [[ -z "${WAYLAND_DISPLAY:-}" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED no reachable Wayland session\n'; exit 2
fi
tmp=$(mktemp -d)
pid=""
sender=""
cleanup() {
    if [[ -n "$sender" ]]; then kill "$sender" 2>/dev/null || true; wait "$sender" 2>/dev/null || true; fi
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
    rm -rf "$tmp"
}
trap cleanup EXIT
run_dir="$tmp/shell"
cp -r "$shell_dir" "$run_dir"
mkdir -p "$tmp/home" "$tmp/config" "$tmp/data/applications" "$tmp/state"
node --input-type=module - "$run_dir/shell.qml" <<'JS'
import fs from 'node:fs';
const file = process.argv[2];
let qml = fs.readFileSync(file, 'utf8').replace('import Quickshell\n', 'import Quickshell\nimport Quickshell.Io\n');
qml = qml.trimEnd().slice(0, -1) + `
  IpcHandler {
    target: "notificationTest"
    function state(): string {
      var s = desktopShell.notificationService
      return JSON.stringify({ ready: s.liveLoaded && s.historyLoaded && s.quietLoaded,
        configLoaded: desktopShell.shellConfigStore.loaded,
        live: s.liveEntries, history: s.currentHistory(), recent: s.recentRows,
        panelOpen: !!s.openPanel, settings: s.openPanel ? s.openPanel.settingsView : false,
        panelHistory: s.openPanel ? s.openPanel.history : [],
        actions: Object.keys(s.liveKeys).map(function(key) { return s.actionsOf(key, s.refsRevision) }) })
    }
    function setting(key: string, json: string): string {
      desktopShell.notificationService.setSetting(key, JSON.parse(json))
      return "ok"
    }
  }
}
`;
fs.writeFileSync(file, qml);
JS
ipc() { qs ipc -p "$run_dir" call notifications "$@"; }
state() { qs ipc -p "$run_dir" call notificationTest state; }
setting() { qs ipc -p "$run_dir" call notificationTest setting "$@"; }
assert_state() {
    state > "$tmp/snapshot.json"
    node --input-type=module - "$tmp/snapshot.json" "$1" <<'JS'
import fs from 'node:fs';
import assert from 'node:assert/strict';
const s = JSON.parse(fs.readFileSync(process.argv[2]));
const check = new Function('s', 'assert', process.argv[3]);
check(s, assert);
JS
}
await_count() {
    local actual=""
    for ((i = 0; i < 300; i++)); do
        actual=$(ipc count)
        [[ "$actual" == "$1" ]] && return
        sleep 0.1
    done
    printf 'FAIL count expected %s, got %s\n' "$1" "$actual"; exit 1
}
start() {
    local owner
    owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications)
    [[ "$owner" == 'b false' ]] || { printf 'BLOCKED Notifications already owned; no replacement attempted\n'; exit 2; }
    HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" \
        MIRROROS_SHELL_STATE_DIR="$tmp/state" qs -p "$run_dir" > "$tmp/shell.log" 2>&1 &
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
stop() {
    kill "$pid"; wait "$pid" 2>/dev/null || true; pid=""
    local warnings
    warnings=$(grep -E 'WARN|ERROR|Warning|Error|TypeError|ReferenceError|Binding loop' "$tmp/shell.log" \
        | grep -vE 'qt.qpa.wayland.textinput.*(has focus|QWaylandTextInputv3::disableSurface.*Trying to disable .* but .* is focused)' || true)
    [[ -z "$warnings" ]] || { printf 'FAIL shell log not quiet\n%s\n' "$warnings"; exit 1; }
}
send() { notify-send --app-name=MirrorOS-Synthetic "$@"; }
settle() { sleep 0.8; }

start
[[ "$(ipc ping)" == ok ]]
ipc probe > "$tmp/probe.json"
node --input-type=module - "$tmp/probe.json" <<'JS'
import fs from 'node:fs'; import assert from 'node:assert/strict';
const s = JSON.parse(fs.readFileSync(process.argv[2]));
assert.equal(s.sharingActive, false); assert.equal(s.sharingOfferPending, false);
console.log('PASS no screen share, no snooze offer');
JS
if [[ "${1:-}" == --sharing-attempt ]]; then
    command -v pw-cli >/dev/null || { printf 'BLOCKED pw-cli missing\n'; exit 2; }
    # The upstream detector checks these properties, not frames or portal calls.
    # This temporary node is a detector fixture, NOT a working screen capture.
    timeout 6 pw-cli -m create-node adapter '{ factory.name = support.null-audio-sink node.name = mirroros-synthetic-share media.class = Video/Source media.name = xdph-streaming-mirroros-synthetic object.linger = false audio.position = [ MONO ] }' > "$tmp/sharing.log" 2>&1 &
    sender=$!
    detected=false
    for ((i = 0; i < 30; i++)); do
        ipc probe > "$tmp/sharing-probe.json"
        if node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1]));if(!s.sharingActive||!s.sharingOfferPending)process.exit(1)' "$tmp/sharing-probe.json"; then detected=true; break; fi
        sleep 0.1
    done
    if [[ "$detected" == true ]]; then
        printf 'PASS synthetic PipeWire node triggers screen-share snooze offer (not portal capture qualification)\n'
    else
        printf 'BLOCKED bounded synthetic sharing attempt did not trigger offer\n%s\n' "$(<"$tmp/sharing.log")"
    fi
    wait "$sender" 2>/dev/null || true; sender=""
    settle
    ipc probe > "$tmp/sharing-ended.json"
    node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1]));if(s.sharingActive||s.sharingOfferPending)process.exit(1)' "$tmp/sharing-ended.json"
    printf 'PASS synthetic sharing node removed; no offer remains\n'
fi
send --urgency=low 'Synthetic expiry' 'Disposable popup body'
await_count 1
hyprctl layers | grep -q mirroros-notifications
await_count 0
settle
assert_state 'assert.equal(s.history[0].closed_reason, "expired"); assert.equal(s.history[0].summary, "Synthetic expiry")'
printf 'PASS mapped popup expires using upstream low-urgency duration\n'
for title in One Two Three; do send --urgency=critical "Synthetic $title" 'Dismissal fixture'; done
await_count 3
ipc dismissOne >/dev/null; await_count 2
ipc dismissAll >/dev/null; await_count 0; settle
ipc openPanel >/dev/null; settle
assert_state 'assert.equal(s.panelOpen, true); assert.equal(s.panelHistory.length, 4)'
ipc closePanel >/dev/null; settle
ipc showHistory >/dev/null; await_count 4
ipc dismissAll >/dev/null; await_count 0
ipc clear >/dev/null; settle
node --input-type=module - "$tmp/state/notifications/history.json" <<'JS'
import fs from 'node:fs'; import assert from 'node:assert/strict';
assert.deepEqual(JSON.parse(fs.readFileSync(process.argv[2])), []);
JS
printf 'PASS dismiss one/all; panel history; clear removes history from disk (no per-entry delete upstream)\n'

ipc setDnd on >/dev/null
send 'Synthetic held by DND' 'Quiet fixture'
settle; await_count 0
assert_state 'assert.equal(s.history[0].closed_reason, "silenced")'
ipc setDnd off >/dev/null
send --urgency=critical 'Synthetic source snooze' 'Source fixture'
await_count 1
ipc snooze 1 >/dev/null; await_count 0
send 'Synthetic held by source' 'Source fixture'
settle; await_count 0
assert_state 'assert.equal(s.history[0].closed_reason, "snoozed")'
ipc unsnooze '' >/dev/null
ipc snoozeAll 1 >/dev/null
send 'Synthetic held globally' 'Global fixture'
settle; await_count 0
ipc snoozeAll 1 >/dev/null
send --urgency=critical 'Synthetic after quiet' 'Visible again'
await_count 1
ipc dismissAll >/dev/null; await_count 0
printf 'PASS DND on/off and source/global snooze\n'

ipc setDnd on >/dev/null
send --urgency=critical 'Synthetic verification code 482913' 'Your verification code is 482913'
await_count 1; settle
assert_state 'assert.equal(s.live[0].summary, "Verification notification"); assert.equal(s.live[0].body, "[redacted]"); assert.ok(!JSON.stringify([s.live,s.recent]).includes("482913"))'
ipc dismissAll >/dev/null; await_count 0; settle
assert_state 'assert.ok(!JSON.stringify(s.history).includes("482913"))'
ipc codes off >/dev/null
send 'Synthetic verification code 739216' 'Your verification code is 739216'
settle; await_count 0
printf 'PASS heuristic code redaction in live/history/recent and quiet-bypass toggle (not a privacy guarantee)\n'
ipc setDnd off >/dev/null
ipc clear >/dev/null

# Standard sender actions need the live sender object.
notify-send --app-name=MirrorOS-Synthetic --urgency=critical --wait --action=synthetic=Confirm 'Synthetic standard action' 'Harmless sender action' > "$tmp/action.txt" &
sender=$!
await_count 1
[[ "$(ipc act synthetic)" == synthetic ]]
await_count 0
wait "$sender"; sender=""
[[ "$(<"$tmp/action.txt")" == synthetic ]]
printf 'PASS standard freedesktop action reaches waiting sender\n'

# Exec-argv preserves arguments, including shell metacharacters, without reparsing.
argv=$(node -e 'console.log(JSON.stringify(["/usr/bin/touch","--",process.argv[1]]))' "$tmp/marker ; literal")
send --urgency=critical --hint="string:omarchy-exec-argv:$argv" 'Synthetic exec action' 'Harmless marker command'
await_count 1
ipc invokeLast >/dev/null; await_count 0
[[ -f "$tmp/marker ; literal" ]]
rm "$tmp/marker ; literal"
notify-send --app-name=MirrorOS-Synthetic-Snoozed --urgency=critical 'Synthetic persisted snooze' 'Separate source fixture'
await_count 1
ipc snooze 10 >/dev/null; await_count 0
send --urgency=critical --hint="string:omarchy-exec-argv:$argv" 'Synthetic restored exec action' 'Harmless marker after restart'
notify-send --app-name=MirrorOS-Synthetic --urgency=critical --wait --action=synthetic=Confirm 'Synthetic lost action' 'Sender action cannot survive daemon restart' > "$tmp/lost-action.txt" &
sender=$!
await_count 2
send 'Synthetic restored normal' 'Receives upstream restore grace'
await_count 3
setting stacking '"all"' >/dev/null
ipc setDnd on >/dev/null
settle
stop
# notify-send --wait can remain waiting after its daemon disappears.
kill "$sender" 2>/dev/null || true
wait "$sender" 2>/dev/null || true; sender=""
start
await_count 3
# Restored normal rows expire after 20 seconds; critical rows remain.
await_count 2
[[ "$(ipc dndState)" == on ]]
[[ "$(ipc codes '')" == off ]]
ipc snoozes > "$tmp/snoozes.json"
node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1]));if(s.length!==1||s[0].label!=="MirrorOS-Synthetic-Snoozed")process.exit(1)' "$tmp/snoozes.json"
ipc unsnooze '' >/dev/null
assert_state 'assert.equal(s.live.length, 2); assert.equal(s.recent.length, 0); assert.ok(s.history.length > 0); assert.ok(s.actions.every(a => a.length === 0))'
node --input-type=module - "$tmp/config/mirroros/shell.json" <<'JS'
import fs from 'node:fs'; import assert from 'node:assert/strict';
const saved = JSON.parse(fs.readFileSync(process.argv[2]));
assert.equal(saved.notifications.stacking, 'all');
assert.equal('bar' in saved, false, 'notification preference saved without bar defaults');
JS
[[ "$(ipc act '')" == 'no actions' ]]
ipc dismissOne >/dev/null; await_count 1
ipc invokeLast >/dev/null; await_count 0
[[ -f "$tmp/marker ; literal" ]]
printf 'PASS restart keeps live/history/quiet/settings; sender actions lost; exec-argv survives and executes literally\n'

ipc setDnd off >/dev/null
ipc clear >/dev/null
ipc openSettings >/dev/null; settle
assert_state 'assert.equal(s.panelOpen, true); assert.equal(s.settings, true)'
ipc closePanel >/dev/null
for file in live.json history.json quiet.json; do
    [[ "$(stat -c %a "$tmp/state/notifications/$file")" == 600 ]]
done
[[ "$(stat -c %a "$tmp/state/notifications")" == 700 ]]
printf 'PASS preferences page opens; prototype state directory 0700/files 0600 after atomic writes\n'
stop

# Seed only disposable synthetic history; the source retention constants stay unchanged.
node --input-type=module - "$tmp/state/notifications/history.json" <<'JS'
import fs from 'node:fs';
const now = Date.now()/1000;
fs.writeFileSync(process.argv[2], JSON.stringify([
 {key:'synthetic-old', summary:'Synthetic aged history', ts:now-172800, closed_ts:now-172800,closed_reason:'dismissed'},
 {key:'synthetic-new', summary:'Synthetic fresh history',ts:now,closed_ts:now,closed_reason:'dismissed'}]));
JS
start
assert_state 'assert.equal(s.history.length, 1); assert.equal(s.history[0].key, "synthetic-new")'
settle
node --input-type=module - "$tmp/state/notifications/history.json" <<'JS'
import fs from 'node:fs'; import assert from 'node:assert/strict';
assert.equal(JSON.parse(fs.readFileSync(process.argv[2])).length, 1);
JS
ipc setDnd on >/dev/null
for ((n = 1; n <= 105; n++)); do send "Synthetic retention $n" 'Bounded history fixture'; done
settle
assert_state 'assert.equal(s.history.length,100); assert.equal(s.history[0].summary,"Synthetic retention 105"); assert.equal(s.history[99].summary,"Synthetic retention 6")'
setting historyHours 0 >/dev/null; settle
assert_state 'assert.equal(s.history.length,0)'
node --input-type=module - "$tmp/state/notifications/history.json" <<'JS'
import fs from 'node:fs'; import assert from 'node:assert/strict';
assert.deepEqual(JSON.parse(fs.readFileSync(process.argv[2])), []);
JS
printf 'PASS aged history expires on load; 105 arrivals retain newest 100; zero retention deletes persisted history\n'
stop
printf 'PASS synthetic notification matrix and quiet runtime logs (known Qt focus warning excepted)\n'
