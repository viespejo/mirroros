#!/usr/bin/env bash
# Prototype-local read-only hardware widget smoke test. No volume, service,
# keyboard or brightness changes. Synthetic battery data tests glyph math only;
# it does not qualify real battery/audio controls (pending laptop validation).
set -euo pipefail

tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shell_dir=$(cd "$tests_dir/../../../../capabilities/desktop/shell" && pwd)
for tool in node qs hyprctl; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done

node "$tests_dir/qmllint-check.mjs"

node - "$shell_dir/bar/PowerModel.js" <<'JS'
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const m = {};
vm.createContext(m);
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), m);
const states = { Charging: 1, Discharging: 2, FullyCharged: 4, PendingCharge: 5 };
assert.equal(m.batteryFraction(null), 0);
assert.equal(m.batteryFraction({ isPresent: true, percentage: 1.2 }), 1);
assert.equal(m.batteryFraction({ isPresent: true, percentage: -0.2 }), 0);
assert.equal(m.batteryIcon({}, true, states), '');
const device = { isPresent: true, percentage: 0.5, state: states.Discharging };
assert.notEqual(m.batteryIcon(device, true, states), m.batteryIcon({ ...device, percentage: 0.9 }, true, states));
assert.notEqual(m.batteryIcon(device, true, states), m.batteryIcon({ ...device, state: states.Charging, changeRate: 5 }, false, states));
assert.equal(m.chargeThresholdActive({ ...device, state: states.PendingCharge }, false, states), true);
assert.equal(m.chargeThresholdActive(device, true, states), false);
console.log('PASS synthetic PowerModel fraction, glyph ladder and charge threshold');
JS

if [[ -z "${WAYLAND_DISPLAY:-}" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED no reachable Wayland session\n'
    exit 2
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
cp -r "$shell_dir/Commons" "$shell_dir/Ui" "$shell_dir/bar" "$tmp/"
cat > "$tmp/shell.qml" <<'QML'
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "bar"
import "bar/widgets" as Widgets
import qs.Commons as Commons

ShellRoot {
  ProviderState { id: providerInventory }
  QtObject {
    id: host
    property var providers: providerInventory
    property bool vertical: false
    property int barSize: 26
    property string fontFamily: Commons.Style.font.family
    property color barForeground: Commons.Color.foreground
    property color urgent: Commons.Color.urgent
    property bool foregroundAnimationEnabled: false
    function hideTooltip(target) { }
    function showTooltip(target, text) { }
  }
  PanelWindow {
    id: panel
    anchors { top: true; left: true; right: true }
    implicitHeight: 26
    WlrLayershell.namespace: "mirroros-hardware-widget-test"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    Row {
      Widgets.Audio { id: audio; bar: host }
      Widgets.Monitor { id: monitor; bar: host }
      Widgets.Power { id: power; bar: host }
      Widgets.Bluetooth { id: bluetooth; bar: host }
    }
  }
  IpcHandler {
    target: "hardwareTest"
    function state(): string {
      return JSON.stringify({
        inventoryReady: providerInventory.ready,
        bluezInstalled: providerInventory.bluezInstalled,
        bluezRunning: providerInventory.bluezRunning,
        upowerAvailable: providerInventory.upowerAvailable,
        pipewireReady: Pipewire.ready,
        audioUnavailable: audio.unavailable,
        audioHasOutput: audio.hasOutput,
        audioVisible: audio.visible,
        batteryPresent: power.batteryPresent,
        powerVisible: power.visible,
        powerUnavailable: power.unavailable,
        bluetoothAdapter: bluetooth.adapter !== null,
        bluetoothVisible: bluetooth.visible,
        bluetoothUnavailable: bluetooth.unavailable,
        monitorVisible: monitor.visible,
        screens: Quickshell.screens.length
      })
    }
  }
}
QML
qs -p "$tmp" > "$tmp/shell.log" 2>&1 &
pid=$!
state=""
for ((i = 0; i < 60; i++)); do
    if state=$(qs ipc -p "$tmp" call hardwareTest state 2>/dev/null); then break; fi
    if ! kill -0 "$pid" 2>/dev/null; then
        printf 'FAIL shell exited\n'; printf '%s\n' "$(<"$tmp/shell.log")"; exit 1
    fi
    sleep 0.1
done
# Wait beyond the audio startup grace without changing any real source.
sleep 3.5
state=$(qs ipc -p "$tmp" call hardwareTest state)
printf '%s\n' "$state"
node - "$state" <<'JS'
const assert = require('node:assert/strict');
const s = JSON.parse(process.argv[2]);
assert.equal(s.inventoryReady, true, 'startup inventory completed');
assert.equal(s.audioUnavailable, !s.pipewireReady);
assert.equal(s.audioVisible, s.audioUnavailable || (s.pipewireReady && s.audioHasOutput));
assert.equal(s.powerUnavailable, !s.upowerAvailable);
assert.equal(s.powerVisible, s.powerUnavailable || s.batteryPresent);
assert.equal(s.bluetoothUnavailable, !s.bluezRunning);
assert.equal(s.bluetoothVisible, s.bluetoothUnavailable || s.bluetoothAdapter);
assert.equal(s.monitorVisible, true);
assert.ok(s.screens > 0);
console.log('PASS actual provider inventory, absent-device visibility and monitor indicator');
JS
if ! hyprctl layers | grep -q 'mirroros-hardware-widget-test'; then
    printf 'FAIL test layer not mapped\n'; exit 1
fi
if grep -E 'WARN|ERROR|Warning|Error|TypeError|ReferenceError|Binding loop' "$tmp/shell.log"; then
    printf 'FAIL shell log is not quiet\n'; exit 1
fi
printf 'PASS mapped test layer and quiet shell log\n'
printf 'UNVERIFIED real volume/mute, battery percentage interaction and DSP sinks: laptop required\n'
