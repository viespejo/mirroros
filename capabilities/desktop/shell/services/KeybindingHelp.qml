import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard help source for the menu's Keybindings selector. New code; behavior
// reference: Omarchy bin/omarchy-menu-keybindings at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 ("KEYS → Description" rows shown in
// the menu's dmenu mode, the selection dispatches the binding).
//
// Rows list the bindings the compositor actually has (`hyprctl binds -j`).
// A description is shown only when the binding declares one; none is made up.
// A row is launchable only when the MirrorOS Lua binding helper registered the
// same keys under a stable id (compositor/providers/hyprland/shell-bindings.lua);
// it is then dispatched by id through `hyprctl eval`. Every other row stays
// visible and does nothing when chosen. Hyprland 0.56 reports no key for
// bindings declared as `code:N`; such a row is matched to the registry by its
// modifiers and description, and only when exactly one entry matches. `hyprctl eval` prints no returned
// values, so the helper exports its registry to a runtime file; a file from
// another Hyprland instance, or no file, leaves nothing launchable.
Item {
  id: root

  // Read once at startup. The override exists for prototype tests.
  readonly property string registryPath: Quickshell.env("MIRROROS_SHELL_KEYBINDINGS_REGISTRY")
    || ((Quickshell.env("XDG_RUNTIME_DIR") || "/nonexistent") + "/mirroros-keybindings.tsv")
  readonly property string instanceSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
  readonly property var modifierBits: [[64, "SUPER"], [1, "SHIFT"], [4, "CTRL"], [8, "ALT"], [2, "CAPS"], [16, "MOD2"], [32, "MOD3"], [128, "MOD5"]]

  property var records: []
  property string error: ""
  property var pendingCallback: null
  property var bindsJson: null

  function keysFor(bind) {
    var parts = []
    var mask = Number(bind.modmask || 0)
    for (var i = 0; i < root.modifierBits.length; i++) {
      if (mask & root.modifierBits[i][0]) parts.push(root.modifierBits[i][1])
    }
    var key = String(bind.key || "")
    if (!key && Number(bind.keycode || 0) > 0) key = "code:" + Number(bind.keycode)
    parts.push(key)
    return parts.join(" + ")
  }

  // Order-insensitive modifier comparison, case-insensitive key.
  function canonicalKeys(keys) {
    var parts = String(keys || "").split("+").map(function(p) { return p.trim().toUpperCase() }).filter(function(p) { return p.length > 0 })
    if (parts.length === 0) return ""
    var key = parts.pop()
    parts.sort()
    return parts.concat([key]).join("+")
  }

  function validId(id) {
    return /^[a-z0-9][a-z0-9._-]{0,63}$/.test(String(id || ""))
  }

  // Modifier part of a canonical key string (everything before the last key).
  function canonicalModifiers(canonical) {
    var parts = String(canonical || "").split("+")
    parts.pop()
    return parts.join("+")
  }

  // "# instance <signature>" header, then "<id>\t<keys>[\t<description>]" lines.
  // A missing or different signature means a stale registry: nothing is registered.
  // Returns the entries; `byKeys` maps canonical keys to ids.
  function parseRegistry(text) {
    var result = { byKeys: ({}), entries: [] }
    var lines = String(text || "").split("\n")
    if (!root.instanceSignature || lines[0] !== "# instance " + root.instanceSignature) return result
    for (var i = 1; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length < 2 || !root.validId(fields[0])) continue
      var canonical = root.canonicalKeys(fields[1])
      result.byKeys[canonical] = fields[0]
      result.entries.push({ id: fields[0], keys: fields[1], description: fields.length > 2 ? fields[2] : "",
                            modifiers: root.canonicalModifiers(canonical) })
    }
    return result
  }

  // The registry entry for a bind that has no key: same modifiers and same
  // non-empty description, accepted only when it is the single match.
  function matchWithoutKey(bind, entries) {
    var description = String(bind.description || "")
    if (!description) return null
    var modifiers = root.canonicalModifiers(root.canonicalKeys(root.keysFor(bind) + "X"))
    var found = null
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].description !== description || entries[i].modifiers !== modifiers) continue
      if (found) return null
      found = entries[i]
    }
    return found
  }

  function buildRecords(registryText) {
    var registry = root.parseRegistry(registryText)
    var list = Array.isArray(root.bindsJson) ? root.bindsJson : []
    var out = []
    for (var i = 0; i < list.length; i++) {
      var bind = list[i] || {}
      if (bind.submap) continue
      var keys = root.keysFor(bind)
      var id = registry.byKeys[root.canonicalKeys(keys)] || ""
      if (!String(bind.key || "") && !(Number(bind.keycode || 0) > 0)) {
        var match = root.matchWithoutKey(bind, registry.entries)
        if (match) { keys = match.keys; id = match.id }
      }
      out.push({ keys: keys, description: String(bind.description || ""), id: id, launchable: id !== "" })
    }
    root.records = out
  }

  // Selector options, in the menu's dmenu format "<glyph>\t<label>\t<subtext>".
  function options() {
    var out = []
    for (var i = 0; i < root.records.length; i++) out.push(root.optionFor(root.records[i]))
    return out
  }

  function optionFor(record) {
    var label = record.description ? record.keys + " → " + record.description : record.keys
    var notes = []
    if (!record.description) notes.push("No description")
    if (!record.launchable) notes.push("Not launchable from help")
    return notes.length ? "\t" + label + "\t" + notes.join(" · ") : label
  }

  // Maps a selector result (label, or label + TAB + subtext) back to its record.
  function recordForSelection(selection) {
    for (var i = 0; i < root.records.length; i++) {
      var option = root.optionFor(root.records[i])
      var parts = option.split("\t")
      if (parts.length > 1) parts.shift()
      if (parts.join("\t") === selection) return root.records[i]
    }
    return null
  }

  function dispatch(record) {
    if (!record || !record.launchable || !root.validId(record.id)) return false
    // The id passed validId, so it cannot leave the Lua string literal.
    Quickshell.execDetached(["hyprctl", "eval", 'MirrorOSKeys.dispatch("' + record.id + '")'])
    return true
  }

  // Loads binds, then the registry, then calls back with no arguments.
  function load(callback) {
    root.pendingCallback = callback
    root.error = ""
    root.bindsJson = null
    if (!bindsProc.running) bindsProc.running = true
  }

  function finish() {
    var callback = root.pendingCallback
    root.pendingCallback = null
    if (typeof callback === "function") callback()
  }

  Process {
    id: bindsProc
    command: ["hyprctl", "binds", "-j"]
    stdout: StdioCollector { id: bindsOut }
    onExited: function(exitCode) {
      var parsed = null
      if (exitCode === 0) {
        try { parsed = JSON.parse(bindsOut.text) } catch (e) { parsed = null }
      }
      if (!Array.isArray(parsed)) {
        root.records = []
        root.error = "Could not read the compositor's bindings (hyprctl binds -j)."
        root.finish()
        return
      }
      root.bindsJson = parsed
      registryProc.running = true
    }
  }

  Process {
    id: registryProc
    command: ["cat", root.registryPath]
    stdout: StdioCollector { id: registryOut }
    onExited: function(exitCode) {
      root.buildRecords(exitCode === 0 ? registryOut.text : "")
      root.finish()
    }
  }
}
