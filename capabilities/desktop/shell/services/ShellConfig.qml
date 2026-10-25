import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "ShellPreferences.js" as Preferences

// Adapted from Omarchy shell/shell.qml 36-149, 168-172, 1096-1140 and
// config/omarchy/shell.json at 7075b61c6aaa5d8589f6e816867508fc96dc49d9
// (MIT, Copyright (c) David Heinemeier Hansson). No plugin registry.
// MirrorOS (DEC-024/025): versioned defaults.json beside shell.qml plus sparse
// per-option user overrides in $XDG_CONFIG_HOME/mirroros/shell.json, resolved by
// ShellPreferences.js. Saving records only the changed paths; invalid user files
// are preserved and never overwritten. Private runtime state lives elsewhere.
QtObject {
  id: root

  readonly property string configHome: {
    var xdg = Quickshell.env("XDG_CONFIG_HOME") || ""
    return xdg.charAt(0) === "/" ? xdg : Quickshell.env("HOME") + "/.config"
  }
  readonly property string configPath: configHome + "/mirroros/shell.json"

  property var defaultsConfig: ({ version: 1 })
  property string defaultsError: ""
  property var overrides: ({ version: 1 })
  // "pending" | "absent" | "valid" | "invalid" | "unreadable"
  property string userStatus: "pending"
  property string userError: ""
  property bool userPresent: false
  property string diskText: ""
  property bool loaded: false
  readonly property bool writable: loaded && (userStatus === "absent" || userStatus === "valid")

  property var shellConfig: Preferences.resolve(defaultsConfig, {})
  readonly property var barConfig: shellConfig && Util.isPlainObject(shellConfig.bar)
    ? shellConfig.bar : ({})

  function refresh() {
    shellConfig = Preferences.resolve(defaultsConfig, overrides)
  }

  function applyDefaults(text) {
    var value = null
    var error = ""
    try {
      value = JSON.parse(text || "")
      error = Preferences.validateDefaults(value)
    } catch (e) {
      error = "malformed JSON"
    }
    defaultsError = error
    if (error) {
      console.warn("Shell defaults.json unusable (" + error + "); running with empty defaults")
      value = { version: 1 }
    }
    defaultsConfig = value
    if (userPresent) applyUserText(diskText, true)
    else refresh()
  }

  function applyUserText(text, present) {
    var result = Preferences.parse(present ? text : "", defaultsConfig)
    userPresent = present
    diskText = present ? text : ""
    userStatus = present && result.status === "absent" ? "valid" : result.status
    userError = result.error
    if (result.status === "invalid")
      console.warn("Preserving unsupported " + configPath + " (" + result.error + "); using defaults, preferences will not be saved")
    overrides = result.overrides
    refresh()
    loaded = true
  }

  // Compute the paths a mutation actually changed and record only those.
  function commit(nextEffective) {
    var changes = Preferences.diff(shellConfig, nextEffective)
    if (!changes.length) return false
    return persistOverrides(Preferences.applyChanges(overrides, changes))
  }

  function persistOverrides(nextOverrides) {
    if (!writable) {
      console.warn("Not saving shell preferences: " + configPath + " is " + userStatus
        + (userError ? " (" + userError + ")" : ""))
      return false
    }
    var text = Preferences.serialize(nextOverrides)
    if (userPresent && text === diskText && !writer.running) return false
    overrides = Preferences.parse(text, defaultsConfig).overrides
    refresh()
    writer.queue(text)
    return true
  }

  function mutateShellConfig(mutator) {
    var copy = JSON.parse(JSON.stringify(shellConfig))
    mutator(copy)
    return commit(copy)
  }

  // Remove one explicit override (path array or dotted string); the current
  // default applies again.
  function resetOverride(path) {
    var parts = Array.isArray(path) ? path : String(path || "").split(".").filter(function(p) { return p.length })
    if (!parts.length || parts[0] === "version") return false
    return persistOverrides(Preferences.removeOverride(overrides, parts))
  }

  // Only persist an actual inline-settings change, matching Omarchy.
  function updateEntryInline(moduleName, settings) {
    var stripped = Util.canonicalWidgetId(moduleName)
    var copy = JSON.parse(JSON.stringify(shellConfig))
    if (!Util.isPlainObject(copy.bar)) copy.bar = { layout: {} }
    if (!Util.isPlainObject(copy.bar.layout)) copy.bar.layout = {}
    if (!Array.isArray(copy.plugins)) copy.plugins = []

    var sections = Util.barSections
    var foundInLayout = false
    var dirty = false
    for (var s = 0; s < sections.length; s++) {
      var arr = copy.bar.layout[sections[s]] || []
      for (var i = 0; i < arr.length; i++) {
        if (arr[i] && Util.canonicalWidgetId(arr[i].id) === stripped) {
          var next = { id: stripped }
          for (var k in settings) if (k !== "id") next[k] = settings[k]
          if (JSON.stringify(arr[i]) !== JSON.stringify(next)) {
            arr[i] = next
            dirty = true
          }
          foundInLayout = true
        }
      }
    }
    if (!foundInLayout) {
      for (var j = 0; j < copy.plugins.length; j++) {
        if (copy.plugins[j] && copy.plugins[j].id === stripped) {
          var pnext = { id: stripped }
          for (var pk in settings) if (pk !== "id") pnext[pk] = settings[pk]
          if (JSON.stringify(copy.plugins[j]) !== JSON.stringify(pnext)) {
            copy.plugins[j] = pnext
            dirty = true
          }
        }
      }
    }
    if (!dirty) return false
    return commit(copy)
  }

  property FileView defaultsFile: FileView {
    path: Quickshell.shellPath("defaults.json")
    blockLoading: true
    printErrors: false
    onLoaded: root.applyDefaults(text())
    onLoadFailed: function(error) { root.applyDefaults("") }
  }

  property FileView userConfigFile: FileView {
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: if (!root.writer.busy) root.applyUserText(text(), true)
    onLoadFailed: function(error) {
      if (root.writer.busy) return
      if (error === FileViewError.FileNotFound) {
        root.applyUserText("", false)
      } else {
        root.userStatus = "unreadable"
        root.userError = "read error " + String(error)
        root.loaded = true
        console.warn("Cannot read " + root.configPath + "; using defaults, preferences will not be saved")
      }
    }
    onFileChanged: reload()
  }

  // Single serialized writer: private mode, atomic rename beside the resolved
  // target (symlinks are kept), and no write if the file changed on disk since
  // it was last read. Rapid saves coalesce to the latest text.
  property Process writer: Process {
    property string pendingText: ""
    property bool hasPending: false
    readonly property bool busy: running || hasPending

    function queue(text) {
      pendingText = text
      hasPending = true
      if (!running) launch()
    }

    function launch() {
      command = ["bash", "-c",
        'umask 077; target=$(realpath -m -- "$1") || exit 1; mkdir -p -- "${target%/*}" || exit 1; '
        + 'if [ -e "$target" ]; then [ "$4" = present ] && [ "$(cat -- "$target"; printf x)" = "$3x" ] || exit 3; '
        + 'elif [ "$4" = present ]; then exit 3; fi; '
        + 'tmp=$(mktemp -- "$target.XXXXXX") || exit 1; '
        + 'if printf "%s" "$2" > "$tmp" && mv -f -- "$tmp" "$target"; then exit 0; fi; rm -f -- "$tmp"; exit 1',
        "mirroros-shell-preferences", root.configPath, pendingText, root.diskText,
        root.userPresent ? "present" : "absent"]
      writing = pendingText
      hasPending = false
      running = true
    }

    property string writing: ""
    onExited: function(code) {
      if (code === 0) {
        root.diskText = writing
        root.userPresent = true
        root.userStatus = "valid"
        if (hasPending) { launch(); return }
      } else {
        hasPending = false
        console.warn(code === 3
          ? "Not saving shell preferences: " + root.configPath + " changed on disk; reloading it"
          : "Cannot save shell preferences to " + root.configPath)
      }
      root.userConfigFile.reload()
    }
  }
}
