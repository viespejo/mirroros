import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "AppSearch.js" as AppSearch

// Adapted from Omarchy shell/services/AppLibrary.qml at 7075b61c6aaa5d8589f6e816867508fc96dc49d9
// (MIT, Copyright (c) David Heinemeier Hansson). Kept: sorted entry list,
// hidden-entry filtering, icon fallback index. Removed: launch-feedback OSD,
// entry removal, launcher.hides, OMARCHY_PATH, gtk-launch and omarchy-launch-tui.
// New: launch through `uwsm app`, and a settled/unavailable state.

// Shared desktop-application library: the sorted entry list with hidden-entry
// filtering and the icon fallback index. Injected as shell.appLibrary; the
// launcher is the consumer.
Item {
  id: root

  property var desktopHiddenEntryIds: ({})

  // Maps an icon name to a file on disk (e.g. "omacut" -> ".../apps/omacut.svg").
  // Used as a fallback for icons that Qt's themed lookup misses because they were
  // installed after this process started (its icon cache never re-scans). Refreshed
  // whenever the app list changes, so newly installed apps get their icon live.
  property var iconIndex: ({})
  property var pendingIconIndex: ({})

  // DesktopEntries fills in asynchronously, from zero, once something binds to
  // it. The binding below starts the scan; `settled` turns true once the list
  // has been quiet for a moment, so an empty list is only reported as a missing
  // capability after loading, never during it.
  readonly property int entryCount: DesktopEntries.applications.values.length
  property bool settled: false
  onEntryCountChanged: settleTimer.restart()

  // Every entry is launched through uwsm; without it nothing can start.
  property bool uwsmAvailable: true

  readonly property string unavailableReason: !root.uwsmAvailable
    ? "uwsm not found. Install the uwsm package; the launcher starts applications with `uwsm app`."
    : root.settled && root.entryCount === 0
    ? "No desktop entries found. Install applications that ship .desktop files and check that XDG_DATA_DIRS lists their share directories."
    : ""

  // Emitted whenever the visible application set may have changed: desktop
  // entries appeared or vanished, or the hidden-entry filters reloaded.
  signal appsChanged()

  function entryName(entry) {
    return AppSearch.entryName(entry)
  }

  function entrySubtext(entry) {
    return AppSearch.entrySubtext(entry)
  }

  function isHiddenEntry(entry) {
    var id = String((entry && entry.id) || "")
    return root.desktopHiddenEntryIds[id] === true
  }

  function sortedEntries(query) {
    var values = DesktopEntries.applications.values || []
    return AppSearch.sortedEntries(values, query, function(entry) { return root.isHiddenEntry(entry) })
  }

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return Quickshell.iconPath("application-x-executable", true)
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    // Prefer the context-limited app/device index. An unconstrained themed
    // lookup can resolve an app name such as "zoom" to an action icon instead.
    var found = root.iconIndex[value]
    if (found) return Util.fileUrl(found)
    var themed = Quickshell.iconPath(value, true)
    if (themed.length > 0) return themed
    return Quickshell.iconPath("application-x-executable", true)
  }

  // The shell may start before first-install packages have finished placing
  // their icons; consumers call this when they open so icons appear live.
  function refreshIcons() {
    if (!iconIndexScan.running) iconIndexScan.running = true
  }

  // Launch through uwsm so each app gets its own systemd scope under
  // app-graphical.slice. uwsm resolves the entry itself, including
  // Terminal=true entries, which it wraps in the preferred terminal.
  // Keep the .desktop suffix or ids like org.telegram.desktop won't resolve.
  function launch(desktopId) {
    var id = String(desktopId || "")
    if (!id || !root.uwsmAvailable) return
    Quickshell.execDetached(["uwsm", "app", "--", id + ".desktop"])
  }

  function normalizeDesktopId(id) {
    var value = String(id || "").trim()
    if (value.slice(-8) === ".desktop") value = value.slice(0, -8)
    return value
  }

  function loadDesktopHiddenEntries(rawText) {
    var next = ({})
    var lines = String(rawText || "").split(/\n/)
    for (var i = 0; i < lines.length; i++) {
      var id = root.normalizeDesktopId(lines[i])
      if (id.length > 0) next[id] = true
    }
    root.desktopHiddenEntryIds = next
    root.appsChanged()
  }

  function iconIndexScanCommand() {
    // List app/device icons across the XDG icon dirs and /usr/share/pixmaps as
    // "<path>" lines. Some desktop entries, such as Print Settings, use device
    // icons like "printer" instead of app icons. SVGs are emitted before PNGs
    // so the parser, which keeps the first hit per name, prefers scalable icons.
    return [
      'dirs="$HOME/.icons $HOME/.local/share/icons";',
      'IFS=":"; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS;',
      '{',
      '  for base in $dirs; do',
      '    [[ -d $base ]] && find "$base" \\( -path "*/apps/*" -o -path "*/devices/*" \\) \\( -name "*.svg" -o -name "*.png" \\) 2>/dev/null;',
      '  done;',
      '  find /usr/share/pixmaps -maxdepth 1 \\( -name "*.svg" -o -name "*.png" \\) 2>/dev/null;',
      '} | awk \'/\\.svg$/ { print; next } { png[++n] = $0 } END { for (i = 1; i <= n; i++) print png[i] }\''
    ].join(' ')
  }

  function indexIconLine(path) {
    var value = String(path || "").trim()
    if (value.length === 0) return
    var slash = value.lastIndexOf("/")
    var file = slash >= 0 ? value.slice(slash + 1) : value
    var dot = file.lastIndexOf(".")
    var name = dot > 0 ? file.slice(0, dot) : file
    if (name.length > 0 && root.pendingIconIndex[name] === undefined)
      root.pendingIconIndex[name] = value
  }

  function hiddenEntryScanCommand() {
    var desktop = [Quickshell.env("XDG_CURRENT_DESKTOP"), Quickshell.env("XDG_SESSION_DESKTOP"), Quickshell.env("DESKTOP_SESSION")].filter(function(v) { return String(v || "").length > 0 }).join(":")
    var script = Quickshell.shellPath("services/hidden-entries.sh")
    return Util.shellQuote(script) + " " + Util.shellQuote(desktop)
  }

  QtObject {
    id: hiddenEntryOutput
    property string text: ""
  }

  // Both scans must run in non-login shells. A login shell sources the user's
  // profile, and tools like mise touch ~/.local/share on activation — a
  // directory the desktop-entry watcher monitors — so every scan would
  // trigger the next one, pinning a core at idle.
  Process {
    id: hiddenEntryScan
    command: ["bash", "-c", root.hiddenEntryScanCommand()]
    stdout: SplitParser { onRead: function(line) { hiddenEntryOutput.text += line + "\n" } }
    onStarted: hiddenEntryOutput.text = ""
    onExited: root.loadDesktopHiddenEntries(hiddenEntryOutput.text)
  }

  Process {
    id: uwsmCheck
    command: ["sh", "-c", "command -v uwsm"]
    onExited: function(exitCode) { root.uwsmAvailable = exitCode === 0 }
  }

  Process {
    id: iconIndexScan
    command: ["bash", "-c", root.iconIndexScanCommand()]
    stdout: SplitParser { onRead: function(line) { root.indexIconLine(line) } }
    onStarted: root.pendingIconIndex = ({})
    // Swapping the property re-evaluates every iconSource() binding, so
    // newly found icons appear without rebuilding the list.
    onExited: root.iconIndex = root.pendingIconIndex
  }

  // Coalesces bursts of app-list changes (a package install touches many
  // entries) into a single rescan.
  Timer {
    id: iconIndexDebounce
    interval: 750
    onTriggered: if (!iconIndexScan.running) iconIndexScan.running = true
  }

  Timer {
    id: settleTimer
    interval: 1500
    running: true
    onTriggered: root.settled = true
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() {
      hiddenEntryScan.running = true
      iconIndexDebounce.restart()
      root.appsChanged()
    }
  }

  Component.onCompleted: {
    uwsmCheck.running = true
    hiddenEntryScan.running = true
    iconIndexScan.running = true
  }
}
