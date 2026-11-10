import QtQuick
import Quickshell.Bluetooth

// Adapted from Omarchy shell/plugins/panels/bluetooth/Panel.qml 25, 33 at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David Heinemeier
// Hansson). Native state loaded only after the name-only inventory sees an acquired
// org.bluez name. Importing the module with BlueZ stopped otherwise emits a
// DBusObjectManager warning and can request service activation.
QtObject {
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
}
