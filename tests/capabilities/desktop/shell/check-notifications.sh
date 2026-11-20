#!/usr/bin/bash
# Run under dbus-run-session on an isolated graphical session.
set -Eeuo pipefail
tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shell_dir=$(cd "$tests_dir/../../../../capabilities/desktop/shell" && pwd)
for tool in node qs busctl notify-send; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" || "$DBUS_SESSION_BUS_ADDRESS" == "unix:path=${XDG_RUNTIME_DIR:-/nonexistent}/bus" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED run with a private D-Bus and Wayland session\n'; exit 2
fi
bus() { busctl --address="$DBUS_SESSION_BUS_ADDRESS" "$@"; }
dbus_call() { bus call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus "$@"; }
[[ "$(dbus_call NameHasOwner s org.freedesktop.Notifications)" == 'b false' ]] || { printf 'BLOCKED Notifications already owned\n'; exit 2; }
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
node --input-type=module - "$run_dir/shell.qml" <<'JS'
import fs from 'node:fs';
const file = process.argv[2];
let qml = fs.readFileSync(file, 'utf8').replace('import Quickshell\n', 'import Quickshell\nimport Quickshell.Io\n');
qml = qml.trimEnd().slice(0, -1) + `
  IpcHandler {
    target: "notificationTest"
    function state(): string {
      var s = desktopShell.notificationService
      return JSON.stringify({ ready: s.liveLoaded && s.historyLoaded && s.quietLoaded && desktopShell.shellConfigStore.loaded,
        path: s.stateDir, lock: s.lockMarkerPath, live: s.liveEntries, history: s.currentHistory(),
        actions: s.actionsOf(s.newestLive(), s.refsRevision) })
    }
    function invokeButton(identifier: string): void {
      var s = desktopShell.notificationService
      s.invokeAction(s.newestLive(), identifier)
    }
  }
}
`;
fs.writeFileSync(file, qml);
JS
ipc() { qs ipc -p "$run_dir" call notifications "$@"; }
state() { qs ipc -p "$run_dir" call notificationTest state; }
expect() {
    for ((i = 0; i < 120; i++)); do
        if state > "$tmp/snapshot.json" 2>/dev/null && node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1]));if(!(new Function("s","return ("+process.argv[2]+")"))(s))process.exit(1)' "$tmp/snapshot.json" "$1" 2>/dev/null; then
            return
        fi
        if ! kill -0 "$pid" 2>/dev/null; then break; fi
        sleep 0.1
    done
    printf 'FAIL expected %s\n%s\n' "$1" "$(<"$tmp/shell.log")"; exit 1
}
await_count() {
    local actual=""
    for ((i = 0; i < 100; i++)); do
        actual=$(ipc count)
        [[ "$actual" == "$1" ]] && return
        sleep 0.1
    done
    printf 'FAIL expected %s cards, got %s\n' "$1" "$actual"; exit 1
}
start() {
    [[ "$(dbus_call NameHasOwner s org.freedesktop.Notifications)" == 'b false' ]]
    HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" \
        XDG_STATE_HOME="$tmp/home/.local/state" XDG_CACHE_HOME="$tmp/cache" \
        MIRROROS_SHELL_STATE_DIR="$state_root" MIRROROS_SHELL_LOCK_MARKER="$tmp/locked" \
        qs -p "$run_dir" > "$tmp/shell.log" 2>&1 &
    pid=$!
    expect 's.ready'
    local actual owner
    actual=$(state)
    node -e 'const s=JSON.parse(process.argv[1]);if(s.path!==process.argv[2]||s.lock!==process.argv[3])process.exit(1)' "$actual" "$store" "$tmp/locked"
    owner=$(dbus_call GetConnectionUnixProcessID s org.freedesktop.Notifications)
    [[ "$owner" == "u $pid" ]] || { printf 'FAIL private owner PID: %s (wanted %s)\n' "$owner" "$pid"; exit 1; }
}
stop() {
    kill "$pid"; wait "$pid" 2>/dev/null || true; pid=""
    local warnings
    warnings=$(grep -E 'WARN|ERROR|Warning|Error|TypeError|ReferenceError|Binding loop' "$tmp/shell.log" \
        | grep -vE 'qt.qpa.wayland.textinput.*(has focus|QWaylandTextInputv3::disableSurface.*Trying to disable .* but .* is focused)' || true)
    [[ -z "$warnings" ]] || { printf 'FAIL shell log not quiet\n%s\n' "$warnings"; exit 1; }
}
send() { notify-send --app-name=MirrorOS-Synthetic "$@"; }
mkdir -p "$tmp/home/.local/state/mirroros/current" "$tmp/config/mirroros" "$tmp/data/applications"
ln -s /usr/share/mirroros/themes/default "$tmp/home/.local/state/mirroros/current/theme"
ln -s /usr/share/mirroros/themes/default/backgrounds/2-mirroros-jade.png "$tmp/home/.local/state/mirroros/current/background"
prefs="$tmp/config/mirroros/shell.json"
for hours in 168 0; do
    state_root="$tmp/state-$hours"
    store="$state_root/notifications"
    mkdir -p "$store"
    legacy_dnd=false
    if [[ "$hours" == 0 ]]; then legacy_dnd=true; fi
    printf '{"version":1,"notifications":{"historyHours":%s}}\n' "$hours" > "$prefs"
    cp "$prefs" "$tmp/config-expected.json"
    node --input-type=module - "$store" "$legacy_dnd" <<'JS'
import fs from 'node:fs';
const [dir, dnd] = process.argv.slice(2);
const now = Date.now() / 1000;
const legacy = { key: 'legacy-live', app: 'Legacy App', summary: 'Legacy live', body: 'Preserved message', urgency: 2,
  ts: now, execArgv: '["fixture-command"]', execActions: '[{"label":"Fixture","argv":["fixture-command"]}]' };
const history = Array.from({length: 99}, (_, i) => ({...legacy, key: `history-${i}`, summary: `Legacy history ${i}`, closed_ts: now - i - 1}));
history.push({...legacy, key: 'old', summary: 'Too old', closed_ts: now - 25 * 3600});
for (const [name, data] of Object.entries({live: [legacy], history,
  quiet: {dnd: dnd === 'true', snoozes: {'*': {until: now + 3600}}, silencedSince: now, codesBypassQuiet: false}})) {
  fs.writeFileSync(`${dir}/${name}.json`, JSON.stringify(data));
}
JS
    start
    expect 's.live.length === 1 && s.live[0].body === "Preserved message" && s.history.length === 99 && !JSON.stringify([s.live, s.history]).includes("fixture-command")'
    [[ "$(ipc isDnd)" == "$(if [[ "$legacy_dnd" == true ]]; then echo on; else echo off; fi)" ]]
    [[ "$(ipc invokeLast)" == ok ]]
    await_count 0
    expect 's.history.length === 100 && s.history[0].summary === "Legacy live"'
    ipc showHistory >/dev/null
    await_count 6
    ipc dismissAll >/dev/null
    await_count 0
    if [[ "$legacy_dnd" == false ]]; then ipc setDnd on >/dev/null; else ipc setDnd off >/dev/null; fi
    sleep 0.5
    node -e 'const a=require("node:assert/strict");a.deepEqual(JSON.parse(require("node:fs").readFileSync(process.argv[1])),{dnd:process.argv[2]!=="true"})' "$store/quiet.json" "$legacy_dnd"
    cmp "$tmp/config-expected.json" "$prefs"
    if [[ "$hours" == 168 ]]; then stop; fi
done
printf 'PASS private owner, scratch paths, legacy rows and preferences, retention, replay and DND save\n'

id=$(send --print-id --urgency=critical 'Replace me' 'Persistent until replaced')
expect 's.live.some(x => x.summary === "Replace me")'
send --replace-id="$id" --urgency=critical --hint=boolean:transient:true 'Transient replacement' 'Must not persist'
await_count 1
expect 's.live.length === 0'
ipc dismissAll >/dev/null
await_count 0
expect '!s.history.some(x => x.summary === "Replace me" || x.summary === "Transient replacement")'

send --urgency=critical --hint='string:omarchy-exec-argv:["fixture-command"]' 'Executable hint' 'No live action'
await_count 1
[[ "$(ipc act)" == ok ]]
await_count 0
expect 's.history[0].closed_reason === "dismissed" && !JSON.stringify(s.history[0]).includes("fixture-command")'
for route in body button shortcut named; do
    action=default
    if [[ "$route" == named ]]; then action=setup; fi
    send --urgency=critical --wait --action="$action=Test action" "Synthetic $route" 'Live D-Bus action' > "$tmp/action" &
    sender=$!
    await_count 1
    expect "s.actions.length === 1 && s.actions[0].id === '$action' && s.actions[0].text === 'Test action'"
    case "$route" in
        body) ipc invokeLast >/dev/null ;;
        button) qs ipc -p "$run_dir" call notificationTest invokeButton "$action" >/dev/null ;;
        *) ipc act >/dev/null ;;
    esac
    await_count 0
    for ((i = 0; i < 50; i++)); do [[ -s "$tmp/action" ]] && break; sleep 0.1; done
    [[ "$(<"$tmp/action")" == "$action" ]]
    wait "$sender"; sender=""
done
stop
printf 'PASS transient replacement, inert executable hint and live D-Bus actions\n'
