import QtQuick
import Quickshell
import Quickshell.Io

// MirrorOS reminders service. New code; behavior reference: the Omarchy
// v4.5.0 (ac2690cd7be4f47e4a255f5e2e78d904d436b068) Reminder bar indicator.
//
// One `reminder show --json` run per refresh, shared by the Reminder indicator
// of every bar: at shell start and on each `reminders refresh` IPC call, which
// the reminder command makes after it sets, delivers or clears a reminder.
// Nothing polls and nothing is read from or written to disk here.
QtObject {
  id: root

  readonly property string fallbackTooltip: "Set Reminder"
  property int count: 0
  property string tooltip: fallbackTooltip

  function refresh() {
    if (!root.process.running) root.process.running = true
  }

  function update(code, raw) {
    var data = null
    if (code === 0) {
      try { data = JSON.parse(String(raw || "")) } catch (error) { data = null }
    }
    var valid = data !== null && typeof data === "object" && !Array.isArray(data)
    var next = valid ? Number(data.count) : 0
    root.count = isFinite(next) && next > 0 ? Math.floor(next) : 0
    root.tooltip = valid && data.tooltip ? String(data.tooltip) : root.fallbackTooltip
  }

  property Process process: Process {
    command: ["/usr/share/mirroros/reminders/reminder", "show", "--json"]
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: function(code) { root.update(code, output.text) }
  }

  Component.onCompleted: refresh()
}
