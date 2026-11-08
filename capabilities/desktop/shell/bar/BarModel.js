// Adapted from Omarchy shell/plugins/bar/BarModel.js at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c) David Heinemeier
// Hansson). Entry settings, fixed edge and bar thickness only. Panel navigation
// (centerSections, navigationRegions, isDrawnSlot, pickDrawnSlot) is adapted
// from the same file at v4.5.0 (ac2690cd7be4f47e4a255f5e2e78d904d436b068).
// MirrorOS divergence: panelAction replaces upstream's pickPanelSlot, whose
// open copy wins first, with "focused monitor wins"; panelSlots is the pure
// selection behind the bar's panelNavigationSlots.

// Panel tabbing and positional hotkeys take the center as one section.
var centerSections = ["centerBegin", "center", "centerEnd"]

function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value)
}

function normalizePosition(value) {
  var next = String(value || "").trim()
  return /^(top|bottom|left|right)$/.test(next) ? next : "top"
}

function entrySettings(entry) {
  if (!isPlainObject(entry)) return {}
  var copy = {}
  for (var key in entry) {
    if (key === "id") continue
    copy[key] = entry[key]
  }
  return copy
}

function entryId(entry) {
  if (typeof entry === "string") return entry
  if (isPlainObject(entry)) {
    var id = entry["id"]
    if (id !== undefined && id !== null && String(id) !== "") return String(id)
  }
  return ""
}

// Panel tabbing and positional hotkeys take the center as one section: the
// box and the two sections hanging off it, in the order they read.
function navigationRegions(region) {
  var name = String(region || "")
  return centerSections.indexOf(name) !== -1 ? centerSections.slice() : [name]
}

function slotEdge(count, index, fixedEdge, firstEdge, lastEdge) {
  if (count < 2) return fixedEdge
  if (firstEdge && index === 0) return firstEdge
  if (lastEdge && index === count - 1) return lastEdge
  return fixedEdge
}

// A slot the bar draws can anchor a popup, carry the open-panel mark, or be
// found again by switchPanelFrom; fall back to an undrawn one only when
// nothing is on screen.
function isDrawnSlot(slot) {
  return !!slot && slot.visible === true && slot.width > 0 && slot.height > 0
}

function pickDrawnSlot(slots) {
  var placeholder = null
  var list = slots || []
  for (var i = 0; i < list.length; i++) {
    if (!list[i]) continue
    if (isDrawnSlot(list[i])) return list[i]
    if (!placeholder) placeholder = list[i]
  }
  return placeholder
}

function firstDrawnSlot(rows) {
  for (var i = 0; i < rows.length; i++) if (isDrawnSlot(rows[i].slot)) return rows[i].slot
  return null
}

// A bar surface is built per monitor, so a panel request has one copy of the
// widget per screen. Candidates are `{ slot, screenName, opened }`; the result
// is `{ slot, method: "open" | "close" }`, or null when there is nothing to do.
// Focused monitor wins: open and toggle target the focused monitor's drawn
// copy (opening it there closes a copy open elsewhere), toggle closes only a
// copy open on that monitor, and close reaches the open copy wherever it is.
// When the focused monitor draws no copy, a drawn copy elsewhere is used,
// preferring one already open. Focus changes alone never call this.
function panelAction(candidates, focusedScreen, action) {
  var rows = (Array.isArray(candidates) ? candidates : []).filter(function(row) { return row && row.slot })
  var what = String(action || "toggle")
  var opened = rows.filter(function(row) { return row.opened === true })
  if (what === "close") {
    var open = pickDrawnSlot(opened.map(function(row) { return row.slot }))
    return open ? { slot: open, method: "close" } : null
  }
  if (what !== "open" && what !== "toggle") return null
  var focused = String(focusedScreen || "")
  var target = focused ? firstDrawnSlot(rows.filter(function(row) { return row.screenName === focused })) : null
  if (!target) target = firstDrawnSlot(opened) || pickDrawnSlot(rows.map(function(row) { return row.slot }))
  if (!target) return null
  var targetOpen = opened.some(function(row) { return row.slot === target })
  return { slot: target, method: what === "toggle" && targetOpen ? "close" : "open" }
}

// The panels of the given regions in layout order, one per layout entry.
// Slots are `{ region, moduleName, screenName, drawn, panel }`; only drawn
// panels count, so a widget with no panel (the tray) or one hiding itself is
// passed over. A screen name limits the walk to that monitor's bar surface.
function panelSlots(regions, entriesByRegion, slots, screenName) {
  var result = []
  var list = slots || []
  var screen = String(screenName || "")
  for (var r = 0; r < regions.length; r++) {
    var entries = entriesByRegion && Array.isArray(entriesByRegion[regions[r]]) ? entriesByRegion[regions[r]] : []
    for (var i = 0; i < entries.length; i++) {
      var id = entryId(entries[i])
      for (var j = 0; j < list.length; j++) {
        var slot = list[j]
        if (!slot || slot.region !== regions[r] || slot.moduleName !== id) continue
        if (screen && slot.screenName !== screen) continue
        if (!slot.drawn || !slot.panel) continue
        result.push(slot)
        break
      }
    }
  }
  return result
}

function barSizeFor(sizes, screenName, fallback) {
  var name = String(screenName || "")
  var size = sizes && Object.prototype.hasOwnProperty.call(sizes, name) ? Number(sizes[name]) : 0
  return size > 0 ? size : fallback
}
