#!/usr/bin/bash
# Run under dbus-run-session on an isolated graphical session.
# Exercise the lock-marker contract without invoking the real lock hooks.
set -Eeuo pipefail
tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shell_dir=$(cd "$tests_dir/../../../../capabilities/desktop/shell" && pwd)
for tool in node qs busctl; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" || "$DBUS_SESSION_BUS_ADDRESS" == "unix:path=${XDG_RUNTIME_DIR:-/nonexistent}/bus" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED run with a private D-Bus and Wayland session\n'; exit 2
fi
bus_call() { busctl --address="$DBUS_SESSION_BUS_ADDRESS" call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus "$@"; }
[[ "$(bus_call NameHasOwner s org.freedesktop.Notifications)" == 'b false' ]] || { printf 'BLOCKED Notifications already owned\n'; exit 2; }
tmp=$(mktemp -d)
pid=""
cleanup() {
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
    rm -rf "$tmp"
}
trap cleanup EXIT
run_dir="$tmp/shell"
marker="$tmp/locked"
away="$tmp/state/notifications/while-away.json"
cp -r "$shell_dir" "$run_dir"
mkdir -p "$tmp/home/.local/state/mirroros/current" "$tmp/config" "$tmp/data/applications" "$(dirname "$away")"
ln -s /usr/share/mirroros/themes/default "$tmp/home/.local/state/mirroros/current/theme"
ln -s /usr/share/mirroros/themes/default/backgrounds/2-mirroros-jade.png "$tmp/home/.local/state/mirroros/current/background"
printf '{"version":1,"locked":true,"count":4}\n' > "$away"
cp "$away" "$tmp/expected.json"
node --input-type=module - "$run_dir" <<'JS'
import fs from 'node:fs';
const dir = process.argv[2];
const widget = `${dir}/bar/widgets/Weather.qml`;
const original = fs.readFileSync(widget, 'utf8');
const qml = original.replace('  moduleName: "omarchy.weather"', '  moduleName: "omarchy.weather"\n  readonly property var testPanel: panelLoader.item');
if (qml === original) throw new Error('Weather probe insertion failed');
fs.writeFileSync(widget, qml);
const file = `${dir}/shell.qml`;
const shell = fs.readFileSync(file, 'utf8').replace('import Quickshell\n', 'import Quickshell\nimport Quickshell.Io\n');
fs.writeFileSync(file, shell.trimEnd().slice(0, -1) + `
  IpcHandler {
    target: "weatherLockTest"
    function state(): string {
      var widgets = desktopShell.bar.moduleWidgets("omarchy.weather")
      var panel = widgets.length ? widgets[0].testPanel : null
      var s = desktopShell.notificationService
      return JSON.stringify({ ready: !!panel && s.liveLoaded, service: s.lockedNow,
        weather: panel ? panel.lockedNow : null, marker: s.lockMarkerPath })
    }
  }
}
`);
JS
expect() {
    local snapshot=""
    for ((i = 0; i < 100; i++)); do
        if snapshot=$(qs ipc -p "$run_dir" call weatherLockTest state 2>/dev/null) && \
           node -e 'const s=JSON.parse(process.argv[1]);const locked=process.argv[2]==="true";if(!s.ready||s.service!==locked||s.weather!==locked||s.marker!==process.argv[3])process.exit(1)' "$snapshot" "$1" "$marker"; then
            return
        fi
        if ! kill -0 "$pid" 2>/dev/null; then break; fi
        sleep 0.1
    done
    printf 'FAIL expected Weather lock state %s, got %s\n%s\n' "$1" "$snapshot" "$(<"$tmp/shell.log")"; exit 1
}
lock_changed() { qs ipc -p "$run_dir" call notifications lockChanged; }
touch "$marker"
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" \
    XDG_STATE_HOME="$tmp/home/.local/state" XDG_CACHE_HOME="$tmp/cache" \
    MIRROROS_SHELL_STATE_DIR="$tmp/state" MIRROROS_SHELL_LOCK_MARKER="$marker" \
    qs -p "$run_dir" > "$tmp/shell.log" 2>&1 &
pid=$!
expect true
[[ "$(bus_call GetConnectionUnixProcessID s org.freedesktop.Notifications)" == "u $pid" ]]
rm -- "$marker"
[[ "$(lock_changed)" == ok ]]
expect false
touch "$marker"
[[ "$(lock_changed)" == ok ]]
expect true
kill "$pid"; wait "$pid" 2>/dev/null || true; pid=""
cmp "$tmp/expected.json" "$away"
printf 'PASS Weather follows startup, unlock and relock without rewriting while-away.json\n'
