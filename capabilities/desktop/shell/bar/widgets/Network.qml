import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Ui
import "../NetworkModel.js" as Model

// Adapted from Omarchy shell/plugins/panels/network/Panel.qml at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c) David Heinemeier
// Hansson). Bar-only state, icon and signal fallback; no network panel or IPC.
// New: missing-provider glyph and actionable tooltip. Click is an integration point.
BarWidget {
  id: root
  moduleName: "omarchy.network"

  readonly property bool networkManagerAvailable: Networking.backend === NetworkBackendType.NetworkManager
  readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wifiNetworkObjects: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
  readonly property var connectedWifiNetwork: findConnectedWifiNetwork()
  // Bar pill state, derived from the native NetworkManager service so the
  // icon reflects connection changes without polling. Wired is preferred
  // when both are up, matching the default-route device.
  readonly property var wiredDevice: findDevice(DeviceType.Wired)
  readonly property string kind: {
    if (wiredDevice && wiredDevice.connected) return "ethernet"
    if (connectedWifiNetwork) return "wifi"
    // NetworkManager can leave the active profile out of the device's
    // AvailableConnections, and Quickshell only builds known networks from
    // that list. An OWE transition-mode network does this between scans: the
    // in-use access point carries the hidden "_owetm_" SSID, so the profile
    // for the open SSID looks out of range even while it is connected. Trust
    // the device's own state then instead of flickering to disconnected.
    if (wifiDevice && wifiDevice.connected) return "wifi"
    return "disconnected"
  }
  readonly property int signalStrength: kind === "wifi"
    ? Model.connectedSignalStrength(connectedWifiNetwork ? connectedWifiNetwork.signalStrength : 0, activeApSignal)
    : -1
  // Filled by activeApSignalPoll from nmcli while the connected network has no
  // strength of its own to report.
  property int activeApSignal: -1
  readonly property bool needsActiveApSignal: kind === "wifi"
    && !(connectedWifiNetwork && connectedWifiNetwork.signalStrength > 0)
  // Bumped whenever the cached reading stops describing the current link, so
  // an nmcli read still in flight from before cannot write a stale strength.
  property int activeApSignalGeneration: 0
  property int activeApSignalRequest: -1
  onKindChanged: if (kind !== "wifi") resetActiveApSignal()

  // Switching Wi-Fi networks always passes through a non-"wifi" kind (both the
  // device and the old network drop out of the connected state while the new
  // profile activates), so this also covers a change of network.
  function resetActiveApSignal() {
    activeApSignal = -1
    activeApSignalGeneration++
  }

  function pollActiveApSignal() {
    if (activeApSignalProc.running) return
    activeApSignalRequest = activeApSignalGeneration
    activeApSignalProc.running = true
  }

  function finishActiveApSignal(raw) {
    if (activeApSignalRequest !== activeApSignalGeneration) {
      // The link changed mid-read and the restarted poll skipped while this
      // one was running; read again now instead of a full interval later.
      if (needsActiveApSignal) activeApSignalPoll.restart()
      return
    }
    activeApSignal = Model.parseActiveApSignal(raw)
  }
  readonly property bool connectivityChecksEnabled: networkManagerAvailable
    && Networking.canCheckConnectivity && Networking.connectivityCheckEnabled
  readonly property string connectivity: Model.connectivityState(kind, Networking.connectivity, {
    Portal: NetworkConnectivity.Portal, Limited: NetworkConnectivity.Limited,
    Full: NetworkConnectivity.Full, None: NetworkConnectivity.None
  }, connectivityChecksEnabled)
  readonly property bool hasCaptivePortal: connectivity === "portal"
  readonly property bool restricted: hasCaptivePortal || connectivity === "limited"
  readonly property string icon: Model.connectionIcon(kind, signalStrength, connectivity)
  readonly property string connectionKey: kind === "wifi" && wifiDevice
    ? kind + ":" + wifiDevice.name
    : (kind === "ethernet" && wiredDevice ? kind + ":" + wiredDevice.name : "")

  onConnectionKeyChanged: Qt.callLater(checkConnectivity)
  onConnectivityChecksEnabledChanged: Qt.callLater(checkConnectivity)

  function checkConnectivity() {
    if (connectivityChecksEnabled && kind !== "disconnected") Networking.checkConnectivity()
  }
  Timer {
    id: connectivityPoll
    interval: 10000
    repeat: true
    running: root.restricted && root.connectivityChecksEnabled
    onTriggered: root.checkConnectivity()
  }
  // Prefer a connected device: a machine can expose several NICs of the
  // same type (e.g. an idle onboard port alongside the active adapter),
  // and the first-enumerated one may be carrierless.
  function findDevice(type) {
    var devices = networkDevices || []
    var fallback = null
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      if (!device || device.type !== type) continue
      if (device.connected) return device
      if (!fallback) fallback = device
    }
    return fallback
  }

  function findConnectedWifiNetwork() {
    var networks = wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      if (networks[i] && networks[i].connected) return networks[i]
    }
    return null
  }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: activeApSignalProc
    command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list", "ifname", root.wifiDevice ? root.wifiDevice.name : "", "--rescan", "no"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.finishActiveApSignal(text)
    }
  }

  Timer {
    id: activeApSignalPoll
    interval: 5000
    repeat: true
    triggeredOnStart: true
    running: root.needsActiveApSignal
    onTriggered: root.pollActiveApSignal()
  }
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.networkManagerAvailable ? root.icon : "\uf071"
    active: root.restricted
    tooltipText: !root.networkManagerAvailable
      ? "Network unavailable: NetworkManager backend is missing; install and start NetworkManager."
      : (root.hasCaptivePortal ? I18n.t("network.signInToNetwork")
        : (root.restricted ? I18n.t("network.limitedAccess") : ""))
    // Click: network panel integration point (DEC-016).
  }
}
