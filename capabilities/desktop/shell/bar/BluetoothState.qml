import QtQuick
import Quickshell.Bluetooth

// Adapted from Omarchy shell/plugins/panels/bluetooth/Panel.qml 25, 33 at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c) David Heinemeier
// Hansson). Native state loaded only after the name-only inventory sees an acquired
// org.bluez name. Importing the module with BlueZ stopped otherwise emits a
// DBusObjectManager warning and can request service activation.
QtObject {
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
}
