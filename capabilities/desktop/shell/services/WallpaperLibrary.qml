import QtQuick
import Quickshell
import Quickshell.Io
import "../Commons/WallpaperCatalog.js" as Catalog

QtObject {
  id: root
  readonly property string stateHome: {
    var xdg = Quickshell.env("XDG_STATE_HOME") || ""
    return xdg.charAt(0) === "/" ? xdg : Quickshell.env("HOME") + "/.local/state"
  }
  readonly property string configHome: {
    var xdg = Quickshell.env("XDG_CONFIG_HOME") || ""
    return xdg.charAt(0) === "/" ? xdg : Quickshell.env("HOME") + "/.config"
  }
  property string themePath: ""
  readonly property string personalDirectory: themePath
    ? configHome + "/mirroros/backgrounds/" + themePath.split("/").pop() : ""
  property var paths: []
  property var images: []
  property string error: ""
  property bool busy: false
  property bool forPicker: false
  property bool directoriesOnly: false
  signal completed()

  function refresh(picker, resolveOnly) {
    if (busy) return false
    busy = true
    forPicker = !!picker
    directoriesOnly = !!resolveOnly
    resolver.running = true
    return true
  }

  property Process resolver: Process {
    command: ["readlink", "-f", root.stateHome + "/mirroros/current/theme"]
    stdout: StdioCollector { id: themeOutput; waitForEnd: true }
    onExited: function(code) {
      root.themePath = code === 0 ? themeOutput.text.replace(/\n$/, "") : ""
      if (!root.themePath) {
        root.error = "cannot resolve current theme"
        root.busy = false
        root.completed()
        return
      }
      if (root.directoriesOnly) {
        root.error = ""
        root.busy = false
        root.completed()
        return
      }
      root.scanner.command = ["bash", Quickshell.shellPath(root.forPicker
        ? "services/wallpaper-thumbnails" : "services/list-wallpapers"),
        root.themePath + "/backgrounds", root.personalDirectory]
      root.scanner.running = true
    }
  }

  property Process scanner: Process {
    stdout: StdioCollector { id: catalogOutput; waitForEnd: true }
    stderr: StdioCollector { id: catalogError; waitForEnd: true }
    onExited: function(code) {
      var parsed = code === 0 ? (root.forPicker
        ? Catalog.loadRows(catalogOutput.text) : Catalog.parse(catalogOutput.text)) : null
      root.error = parsed === null ? "wallpaper catalog scan failed" : ""
      if (parsed !== null) {
        if (root.forPicker) root.images = parsed
        else root.paths = parsed
      }
      if (catalogError.text) console.warn(catalogError.text)
      root.busy = false
      root.completed()
    }
  }
}
