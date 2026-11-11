// MirrorOS weather locations (ADR 0029). Pure list and schedule decisions for
// the weather pill and panel; no file, process or network access.
//
// The saved shape, stored per widget under bar.widgets["omarchy.weather"]:
//   { locations: [{ name, latitude, longitude }], active: <index> }
// The active location is the one the pill and the panel's hero report. It is
// never removed, and neither is the last location.

// Weather is refreshed every 30 minutes (ADR 0029).
var REFRESH_MS = 30 * 60 * 1000

function finite(value, limit) {
  if (value === null || value === undefined || value === "") return null
  var n = Number(value)
  return isFinite(n) && Math.abs(n) <= limit ? n : null
}

// A clean { name, latitude, longitude } record, or null when unusable.
function location(value) {
  if (!value || typeof value !== "object") return null
  var name = typeof value.name === "string" ? value.name.replace(/^\s+|\s+$/g, "") : ""
  var latitude = finite(value.latitude, 90)
  var longitude = finite(value.longitude, 180)
  if (name === "" || latitude === null || longitude === null) return null
  return { name: name, latitude: latitude, longitude: longitude }
}

// Settings -> { locations, active }: unusable records are dropped and the
// active index is clamped into the list (0 when empty).
function normalize(settings) {
  var source = settings && Array.isArray(settings.locations) ? settings.locations : []
  var locations = []
  for (var i = 0; i < source.length; i++) {
    var record = location(source[i])
    if (record) locations.push(record)
  }
  var active = parseInt(settings ? settings.active : 0, 10)
  if (isNaN(active) || active < 0 || active >= locations.length) active = 0
  return { locations: locations, active: active }
}

function hasLocation(state) {
  return !!(state && state.locations && state.locations.length > 0)
}

function activeLocation(state) {
  return hasLocation(state) ? state.locations[state.active] : null
}

// Appends a record; the first one added becomes active, later ones leave the
// active location as it is.
function add(state, value) {
  var current = normalize(state)
  var record = location(value)
  if (!record) return current
  current.locations.push(record)
  return current
}

// Replaces the active record in place; with none saved this is the first add.
function replaceActive(state, value) {
  var current = normalize(state)
  var record = location(value)
  if (!record) return current
  if (!hasLocation(current)) return add(current, record)
  current.locations[current.active] = record
  return current
}

// The previously active location stays where it is in the list, so it shows
// among the other rows again.
function activate(state, index) {
  var current = normalize(state)
  var i = parseInt(index, 10)
  if (!isNaN(i) && i >= 0 && i < current.locations.length) current.active = i
  return current
}

function canRemove(state, index) {
  var current = normalize(state)
  var i = parseInt(index, 10)
  return !isNaN(i) && i >= 0 && i < current.locations.length
    && i !== current.active && current.locations.length > 1
}

function remove(state, index) {
  var current = normalize(state)
  if (!canRemove(current, index)) return current
  var i = parseInt(index, 10)
  current.locations.splice(i, 1)
  if (i < current.active) current.active--
  return current
}

// The non-active locations in saved order, with their index in the list.
function others(state) {
  var current = normalize(state)
  var out = []
  for (var i = 0; i < current.locations.length; i++)
    if (i !== current.active) out.push({ index: i, location: current.locations[i] })
  return out
}

// The entry keys written through updateEntryInline.
function toSettings(state) {
  var current = normalize(state)
  return { locations: current.locations, active: current.active }
}

// What one refresh fetches: "none", "active" (the active location alone) or
// "all" (every location in one combined request). Nothing without a location
// or while the session is locked; every location only while the panel is open.
// reason is "timer", "open", "unlock" or "change".
function fetchScope(state, opened, locked, reason) {
  if (!hasLocation(state) || locked) return "none"
  if (reason === "open") return "all"
  return opened ? "all" : "active"
}

// The locations a scope fetches, in request order.
function fetchLocations(state, scope) {
  var current = normalize(state)
  if (scope === "all") return current.locations
  if (scope === "active" && hasLocation(current)) return [current.locations[current.active]]
  return []
}

// True on the locked -> unlocked transition, which is the resume refresh:
// hypridle locks before sleep.
function unlocked(wasLocked, lockedNow) {
  return wasLocked === true && lockedNow !== true
}

// Keyboard focus in the open panel, over count rows of other locations:
// -1 rests on the hero, 0..count-1 on a row and count on "+ Add location".
// Up and down walk these positions and wrap round, as in Elsewhen.
function moveFocus(at, step, count) {
  var size = count + 2
  var from = clampFocus(at, count) + 1
  return ((from + step) % size + size) % size - 1
}

// Keeps a focus position inside the current list.
function clampFocus(at, count) {
  var value = Math.floor(Number(at))
  if (!isFinite(value) || value < 0) return -1
  return Math.min(value, count)
}

if (typeof module !== "undefined") {
  module.exports = {
    REFRESH_MS: REFRESH_MS,
    location: location,
    normalize: normalize,
    hasLocation: hasLocation,
    activeLocation: activeLocation,
    add: add,
    replaceActive: replaceActive,
    activate: activate,
    canRemove: canRemove,
    remove: remove,
    others: others,
    toSettings: toSettings,
    fetchScope: fetchScope,
    fetchLocations: fetchLocations,
    unlocked: unlocked,
    moveFocus: moveFocus,
    clampFocus: clampFocus
  }
}
