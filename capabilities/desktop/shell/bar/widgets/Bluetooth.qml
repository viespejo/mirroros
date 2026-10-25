import QtQuick
import qs.Ui

// Adapted from Omarchy shell/plugins/panels/bluetooth/Panel.qml at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c) David Heinemeier
// Hansson), bar state and button only, plus Model.js name filters. New: non-activating provider inventory,
// unavailable glyph and actionable reason. Panel and radio control are
// integration points (DEC-016); neither click performs an action.
BarWidget {
  id: root
  moduleName: "omarchy.bluetooth"

  readonly property var providers: bar ? bar.providers : null
  readonly property var adapter: nativeState.item ? nativeState.item.adapter : null
  readonly property var devices: nativeState.item ? nativeState.item.devices : []

  Loader {
    id: nativeState
    active: !!root.providers && root.providers.ready && root.providers.bluezRunning
    source: "../BluetoothState.qml"
  }
  readonly property bool unavailable: providers && providers.ready && !providers.bluezRunning
  readonly property string unavailableReason: !providers || !providers.ready
    ? "Bluetooth availability unknown: provider inventory failed or is still loading; restart the shell to retry."
    : (!providers.bluezInstalled
      ? "Bluetooth unavailable: BlueZ is not installed; install bluez and start bluetooth.service."
      : "Bluetooth unavailable: BlueZ is installed but not running; start bluetooth.service.")
  function deviceLabel(device) {
    if (!device) return ""
    return String(device.deviceName || device.name || "").trim()
  }

  function isUuidLike(value) {
    var text = String(value || "").trim()
    if (text === "") return false
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(text)
      || /^[0-9a-f]{32}$/i.test(text)
      || /^0x[0-9a-f]{4,32}$/i.test(text)
      || /^0000[0-9a-f]{4}-0000-1000-8000-00805f9b34fb$/i.test(text)
  }

  function isAddressLike(value) {
    var text = String(value || "").trim()
    return /^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(text)
  }

  function hasHumanName(device) {
    var label = deviceLabel(device)
    return label !== "" && !isUuidLike(label) && !isAddressLike(label)
  }

  readonly property string icon: {
    if (!adapter) return ""
    if (!adapter.enabled) return "\u{f00b2}"
    for (var i = 0; i < devices.length; i++) {
      if (devices[i] && hasHumanName(devices[i]) && devices[i].connected) return "\u{f00b1}"
    }
    return "\u{f00af}"
  }

  visible: unavailable || !providers || !providers.ready || adapter !== null
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.unavailable || !root.providers || !root.providers.ready ? "\uf071" : root.icon
    tooltipText: root.unavailable || !root.providers || !root.providers.ready ? root.unavailableReason : ""
    // Left: Bluetooth panel; right: radio power integration point.
  }
}
