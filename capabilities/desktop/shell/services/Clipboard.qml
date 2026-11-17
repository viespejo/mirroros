import QtQuick
import Quickshell
import Quickshell.Io
import "../clipboard/ClipboardHistoryModel.js" as History

// MirrorOS-owned on-demand adapter. No startup capture, file I/O or polling.
QtObject {
  id: root

  readonly property string executable: "/usr/share/mirroros/clipboard/clipboard-history"
  property var history: []
  property var previews: ({})
  property var previewQueue: []
  property var requested: ({})
  property int generation: 0
  property int listGeneration: 0
  property int previewGeneration: 0
  property int actionGeneration: 0
  property string previewId: ""
  property string actionId: ""
  property string actionName: ""
  property bool active: false
  property bool loading: false
  property bool failed: false
  readonly property bool busy: loading || root.actionProcess.running

  function open() {
    root.generation++
    root.active = true
    root.history = []
    root.previews = ({})
    root.requested = ({})
    root.previewQueue = []
    root.failed = false
    root.loading = true
    if (!root.listProcess.running) root.startList()
  }

  function close() {
    root.active = false
    root.previewQueue = []
    root.history = []
    root.previews = ({})
  }

  function startList() {
    root.listGeneration = root.generation
    root.listProcess.running = true
  }

  function act(name, id) {
    if (root.busy || ["copy", "open", "delete", "clear"].indexOf(name) < 0) return false
    if (name !== "clear" && !/^[0-9]{1,19}$/.test(id)) return false
    root.actionGeneration = root.generation
    root.actionName = name
    root.actionId = id || ""
    root.actionProcess.command = [root.executable, name].concat(name === "clear" ? [] : [id])
    root.actionProcess.running = true
    return true
  }

  function requestPreview(id) {
    if (!root.active || root.busy || !/^[0-9]{1,19}$/.test(id) || root.requested[id]) return
    if (!root.history.some(function(entry) { return entry.id === id && entry.image })) return
    var requested = Object.assign({}, root.requested)
    requested[id] = true
    root.requested = requested
    root.previewQueue = root.previewQueue.concat([id])
    root.nextPreview()
  }

  function nextPreview() {
    if (!root.active || root.previewProcess.running || root.previewQueue.length === 0) return
    root.previewId = root.previewQueue[0]
    root.previewQueue = root.previewQueue.slice(1)
    root.previewGeneration = root.generation
    root.previewProcess.command = [root.executable, "preview", root.previewId]
    root.previewProcess.running = true
  }

  property Process listProcess: Process {
    command: [root.executable, "list"]
    stdout: StdioCollector { id: listing; waitForEnd: true }
    onExited: function(code) {
      if (root.active && root.listGeneration !== root.generation) {
        root.startList()
        return
      }
      if (!root.active) return
      root.loading = false
      root.failed = code !== 0
      root.history = code === 0 ? History.parseHistory(listing.text) : []
    }
  }

  property Process actionProcess: Process {
    onExited: function(code) {
      if (root.actionGeneration !== root.generation || !root.active) return
      root.failed = code !== 0
      if (code !== 0) return
      if (root.actionName === "clear") {
        root.history = []
        root.previews = ({})
        root.previewQueue = []
      } else if (root.actionName === "delete") {
        root.history = History.removeEntry(root.history, root.actionId)
        const previews = Object.assign({}, root.previews)
        delete previews[root.actionId]
        root.previews = previews
        root.previewQueue = root.previewQueue.filter(function(id) { return id !== root.actionId })
      }
    }
  }

  property Process previewProcess: Process {
    stdout: StdioCollector { id: previewOutput; waitForEnd: true }
    onExited: function(code) {
      if (code === 0 && root.active && root.previewGeneration === root.generation &&
          root.history.some(function(entry) { return entry.id === root.previewId })) {
        const expected = root.runtimePreviewPath(root.previewId)
        if (previewOutput.text.trim() === expected) {
          const previews = Object.assign({}, root.previews)
          previews[root.previewId] = expected
          root.previews = previews
        }
      }
      root.nextPreview()
    }
  }

  function runtimePreviewPath(id) {
    return Quickshell.env("XDG_RUNTIME_DIR") + "/mirroros/clipboard/previews/" + id + ".png"
  }
}
