import QtQuick
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "../PowerModel.js" as Model

// Adapted from Omarchy shell/plugins/panels/power/Panel.qml at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c) David Heinemeier
// Hansson). Bar-only battery glyph and persisted percentage toggle; no panel
// or power-profile control. New: unavailable state from the provider inventory.
BarWidget {
  id: root
  moduleName: "omarchy.power"

  readonly property var providers: bar ? bar.providers : null
  readonly property bool unavailable: providers && providers.ready && !providers.upowerAvailable
  readonly property bool inventoryUnknown: !providers || !providers.ready
  readonly property bool batteryPresent: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent)
  }
  readonly property bool showPercentage: setting("showPercentage", false) === true
  readonly property bool discharging: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent && UPower.onBattery)
  }
  readonly property real batteryFraction: Model.batteryFraction(UPower.displayDevice)
  readonly property real openPanelIndicatorWidth: showPercentage && !button.vertical ? button.glyphPaintedWidth : 0

  function upowerStates() {
    return {
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    }
  }

  function batteryIcon() {
    var device = UPower.displayDevice
    return Model.batteryIcon(device, root.discharging, upowerStates())
  }

  function togglePercentage() {
    root.settings = Object.assign({}, root.settings, { showPercentage: !root.showPercentage })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  visible: unavailable || inventoryUnknown || batteryPresent
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.unavailable || root.inventoryUnknown ? "\uf071" : root.batteryIcon()
    labelText: !root.unavailable && !root.inventoryUnknown && root.showPercentage && !vertical
      ? I18n.formatNumber(Math.round(root.batteryFraction * 100)) + "%" : ""
    slotSize: Style.bar.iconSlot * (root.showPercentage && !vertical ? 2 : 1)
    tooltipText: root.inventoryUnknown
      ? "Power availability unknown: provider inventory failed or is still loading; restart the shell to retry."
      : (root.unavailable ? "Power unavailable: UPower has no bus service; install upower and check its D-Bus service registration." : "")
    onPressed: function(b) {
      if (root.unavailable || root.inventoryUnknown || !root.batteryPresent) return
      if (b === Qt.RightButton) root.togglePercentage()
      // Other buttons: power panel integration point (DEC-016).
    }
  }
}
