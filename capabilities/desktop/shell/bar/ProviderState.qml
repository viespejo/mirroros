import QtQuick
import Quickshell.Io

// New prototype-only provider inventory. Listing bus names never activates
// BlueZ or UPower. No timer: a service installed/started later needs a shell
// restart. The native service objects remain responsible for device state.
QtObject {
  id: root

  property var acquiredNames: []
  property var activatableNames: []
  property var packages: []
  property bool acquiredRead: false
  property bool activatableRead: false
  property bool packagesRead: false
  readonly property bool ready: acquiredRead && activatableRead && packagesRead
  readonly property bool bluezInstalled: packages.indexOf("bluez") !== -1
  readonly property bool bluezRunning: acquiredNames.indexOf("org.bluez") !== -1
  readonly property bool upowerAvailable: acquiredNames.indexOf("org.freedesktop.UPower") !== -1
    || activatableNames.indexOf("org.freedesktop.UPower") !== -1

  function names(raw) {
    return String(raw || "").trim().split(/\s+/).filter(function(name) { return name !== "" })
  }

  property Process acquiredProbe: Process {
    command: ["bash", "-o", "pipefail", "-c", "busctl --system --no-pager --no-legend --acquired list | awk '{print $1}'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.acquiredNames = root.names(text)
    }
    onExited: function(code) { root.acquiredRead = code === 0 }
  }

  property Process activatableProbe: Process {
    command: ["bash", "-o", "pipefail", "-c", "busctl --system --no-pager --no-legend --activatable list | awk '{print $1}'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.activatableNames = root.names(text)
    }
    onExited: function(code) { root.activatableRead = code === 0 }
  }

  property Process packageProbe: Process {
    command: ["pacman", "-Qq", "bluez", "upower"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.packages = root.names(text)
    }
    stderr: StdioCollector { }
    // pacman returns 1 if either package is absent; its output still lists
    // installed packages. A missing package is not a probe failure.
    onExited: function(code) { root.packagesRead = code === 0 || code === 1 }
  }
}
