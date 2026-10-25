// MirrorOS while-away notification count model (DEC-021/022). Pure functions;
// the caller owns lock signals, persistence and display.
//
// Conditional feature: this model is NOT wired into the runtime until a bounded
// guest proof shows reliable lock/unlock signals (hypridle on_lock_cmd /
// on_unlock_cmd through existing shell IPC) and startup/restart reconciliation.
// It stores only a count and lock flag, never notification content.
//
// - Arrivals are counted only while locked.
// - Unlocking does not clear the count; opening notification history does.
// - The count is shown only when unlocked (on return) and non-zero.
// - Reconciliation takes the externally observed lock state as the truth and
//   keeps a valid persisted count; anything malformed starts from zero.

var VERSION = 1
var MAX_COUNT = 999

function initial() {
  return { version: VERSION, locked: false, count: 0 }
}

function normalize(state) {
  if (state === null || typeof state !== "object" || Array.isArray(state) || state.version !== VERSION)
    return initial()
  var count = state.count
  return {
    version: VERSION,
    locked: state.locked === true,
    count: typeof count === "number" && Number.isInteger(count) && count > 0 ? Math.min(count, MAX_COUNT) : 0
  }
}

function lock(state) {
  var s = normalize(state)
  s.locked = true
  return s
}

function unlock(state) {
  var s = normalize(state)
  s.locked = false
  return s
}

function notified(state) {
  var s = normalize(state)
  if (s.locked) s.count = Math.min(s.count + 1, MAX_COUNT)
  return s
}

function historyOpened(state) {
  var s = normalize(state)
  s.count = 0
  return s
}

function reconcile(persisted, lockedNow) {
  var s = normalize(persisted)
  s.locked = lockedNow === true
  return s
}

function visibleCount(state) {
  var s = normalize(state)
  return s.locked ? 0 : s.count
}

function parse(text) {
  try {
    return normalize(JSON.parse(String(text || "")))
  } catch (e) {
    return initial()
  }
}

function serialize(state) {
  return JSON.stringify(normalize(state)) + "\n"
}

if (typeof module !== "undefined") {
  module.exports = {
    VERSION: VERSION, MAX_COUNT: MAX_COUNT, initial: initial, lock: lock, unlock: unlock,
    notified: notified, historyOpened: historyOpened, reconcile: reconcile,
    visibleCount: visibleCount, parse: parse, serialize: serialize
  }
}
