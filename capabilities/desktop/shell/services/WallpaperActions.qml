import QtQuick
import Quickshell
import Quickshell.Io
import "../Commons/WallpaperCatalog.js" as Catalog

QtObject {
  id: root
  property var picker: null
  property var library: null
  property var wallpaper: null
  property var notifications: null
  property string currentPath: ""
  property string operation: ""
  property var targetOutput: null
  property bool openCancelled: false
  readonly property bool busy: operation !== ""
  readonly property string backgroundLink: library
    ? library.stateHome + "/mirroros/current/background" : ""

  function display(path) {
    currentPath = path
    if (wallpaper) wallpaper.setBackground(path, false)
  }

  function readSelection(action, output) {
    if (busy) return "error: wallpaper operation in progress"
    if (!library) return "error: catalog unavailable"
    operation = action
    openCancelled = false
    targetOutput = output || null
    readlink.running = true
    return "accepted"
  }

  function openPicker(output) { return readSelection("open", output) }
  function next() { return readSelection("next", null) }
  function install() { return readSelection("install", null) }

  function selectPath(path) {
    if (busy) return "error: wallpaper operation in progress"
    operation = "set"
    setter.command = ["bash", Quickshell.shellPath("services/wallpaper-set"), path]
    setter.running = true
    return "accepted"
  }

  function libraryCompleted() {
    if (operation !== "open" && operation !== "next" && operation !== "install") return
    var action = operation
    var path
    operation = ""
    if (library.error) {
      console.warn(library.error)
      return
    }
    if (action === "open") {
      if (picker && !openCancelled) picker.open(targetOutput, currentPath)
    } else if (action === "install") {
      mkdir.command = ["mkdir", "-p", "--", library.personalDirectory]
      operation = "install-directory"
      mkdir.running = true
    } else {
      path = Catalog.next(library.paths, currentPath)
      if (path === null) {
        if (notifications) notifications.showPlaceholder("No background was found for theme", 2000)
      } else selectPath(path)
    }
  }

  Component.onCompleted: readSelection("refresh", null)

  property Connections libraryEvents: Connections {
    target: root.library
    function onCompleted() { root.libraryCompleted() }
  }
  property Process readlink: Process {
    command: ["readlink", "-f", root.backgroundLink]
    stdout: StdioCollector { id: selectionOutput; waitForEnd: true }
    onExited: function(code) {
      var path = code === 0 ? selectionOutput.text.replace(/\n$/, "") : ""
      if (root.operation === "refresh") {
        root.display(path)
        root.operation = ""
      } else {
        root.currentPath = path
        if (!root.library.refresh(root.operation === "open", root.operation === "install")) {
          console.warn("Wallpaper catalog is busy")
          root.operation = ""
        }
      }
    }
  }
  property Process setter: Process {
    stdout: StdioCollector { id: setterOutput; waitForEnd: true }
    stderr: StdioCollector { id: setterError; waitForEnd: true }
    onExited: function(code) {
      if (code === 0) root.display(setterOutput.text)
      else console.warn(setterError.text)
      root.operation = ""
    }
  }
  property Process mkdir: Process {
    onExited: function(code) {
      root.operation = ""
      if (code === 0) Quickshell.execDetached(["nautilus", root.library.personalDirectory])
      else console.warn("Cannot create personal background directory")
    }
  }
  property IpcHandler ipc: IpcHandler {
    target: "wallpaper"
    function open(): string { return root.openPicker(null) }
    function close(): void {
      root.openCancelled = true
      if (root.picker) root.picker.cancel()
    }
    function next(): string { return root.next() }
    function set(path: string): string { return root.selectPath(path) }
    function refresh(): string { return root.readSelection("refresh", null) }
  }
}
