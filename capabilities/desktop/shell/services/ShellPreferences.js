// MirrorOS shell preference resolver (DEC-024/025). Pure functions shared by
// ShellConfig.qml and the Node tests; no file or process access.
//
// - defaults.json beside shell.qml holds the versioned common defaults.
// - The user's shell.json holds only explicit, sparse overrides of that shape.
// - Plain objects merge by explicitly present keys; arrays and scalars replace
//   the default value completely. Removing an override restores the current default.
// - Saving computes the paths an interface change actually touched and records
//   only those, so unrelated effective defaults are never copied.
// - Invalid or unsupported user files are reported and preserved; callers must
//   not write over them.

var VERSION = 1
var TOP_LEVEL = ["version", "bar", "plugins", "notifications"]
var UNSAFE_KEYS = ["__proto__", "constructor", "prototype"]

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function has(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key)
}

function clone(value) {
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value))
}

function equal(a, b) {
  return JSON.stringify(a) === JSON.stringify(b)
}

function kind(value) {
  if (Array.isArray(value)) return "array"
  if (value === null) return "null"
  return typeof value
}

function unsafeKeyPath(value, path) {
  if (Array.isArray(value)) {
    for (var i = 0; i < value.length; i++) {
      var found = unsafeKeyPath(value[i], path.concat([String(i)]))
      if (found) return found
    }
  } else if (isPlainObject(value)) {
    var keys = Object.keys(value)
    for (var k = 0; k < keys.length; k++) {
      if (UNSAFE_KEYS.indexOf(keys[k]) >= 0) return path.concat([keys[k]]).join(".")
      var nested = unsafeKeyPath(value[keys[k]], path.concat([keys[k]]))
      if (nested) return nested
    }
  }
  return ""
}

// Each override value must keep the kind of the default it replaces. Keys
// without a default are left to their consumer's own validation.
function typeError(override, defaults, path) {
  var keys = Object.keys(override)
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i]
    if (!isPlainObject(defaults) || !has(defaults, key) || defaults[key] === null) continue
    var expected = kind(defaults[key]), actual = kind(override[key])
    var where = path.concat([key]).join(".")
    if (expected !== actual) return where + ": expected " + expected + ", found " + actual
    if (expected === "object") {
      var nested = typeError(override[key], defaults[key], path.concat([key]))
      if (nested) return nested
    }
  }
  return ""
}

// Returns "" when valid, otherwise a short reason.
function validate(value, defaults) {
  if (!isPlainObject(value)) return "top level must be a JSON object"
  var unsafe = unsafeKeyPath(value, [])
  if (unsafe) return "forbidden key " + unsafe
  if (value.version !== VERSION) return "unsupported version (expected " + VERSION + ")"
  var keys = Object.keys(value)
  for (var i = 0; i < keys.length; i++)
    if (TOP_LEVEL.indexOf(keys[i]) < 0) return "unsupported key " + keys[i]
  if (has(value, "notifications") && !isPlainObject(value.notifications))
    return "notifications: expected object, found " + kind(value.notifications)
  return typeError(value, defaults, [])
}

function validateDefaults(value) {
  if (!isPlainObject(value)) return "top level must be a JSON object"
  var unsafe = unsafeKeyPath(value, [])
  if (unsafe) return "forbidden key " + unsafe
  if (value.version !== VERSION) return "unsupported version (expected " + VERSION + ")"
  return ""
}

// status: "absent" (no text), "valid" or "invalid" (error set; preserve file).
function parse(text, defaults) {
  if (text === null || text === undefined || String(text).trim() === "")
    return { status: "absent", overrides: { version: VERSION }, error: "" }
  var value
  try {
    value = JSON.parse(String(text))
  } catch (e) {
    return { status: "invalid", overrides: { version: VERSION }, error: "malformed JSON" }
  }
  var error = validate(value, defaults)
  if (error) return { status: "invalid", overrides: { version: VERSION }, error: error }
  return { status: "valid", overrides: value, error: "" }
}

function merge(base, override) {
  if (!isPlainObject(base) || !isPlainObject(override)) return clone(override)
  var out = clone(base)
  var keys = Object.keys(override)
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i]
    if (UNSAFE_KEYS.indexOf(key) >= 0) continue
    out[key] = has(out, key) ? merge(out[key], override[key]) : clone(override[key])
  }
  return out
}

function resolve(defaults, overrides) {
  var out = merge(isPlainObject(defaults) ? defaults : {}, isPlainObject(overrides) ? overrides : {})
  out.version = VERSION
  return out
}

// Paths whose value differs between two effective configurations. Objects are
// compared key by key; any other value (including arrays) is a single leaf.
function diff(before, after, path) {
  path = path || []
  if (isPlainObject(before) && isPlainObject(after)) {
    var changes = []
    var keys = Object.keys(before).concat(Object.keys(after).filter(function(k) { return !has(before, k) }))
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i]
      if (UNSAFE_KEYS.indexOf(key) >= 0 || (path.length === 0 && key === "version")) continue
      if (!has(after, key)) changes.push({ path: path.concat([key]), removed: true })
      else if (!has(before, key)) changes.push({ path: path.concat([key]), value: clone(after[key]) })
      else changes = changes.concat(diff(before[key], after[key], path.concat([key])))
    }
    return changes
  }
  return equal(before, after) ? [] : [{ path: path, value: clone(after) }]
}

function removeOverride(overrides, path) {
  var out = clone(isPlainObject(overrides) ? overrides : {})
  var parents = [out]
  for (var i = 0; i < path.length - 1; i++) {
    var next = parents[i][path[i]]
    if (!isPlainObject(next)) return withVersion(out)
    parents.push(next)
  }
  delete parents[path.length - 1][path[path.length - 1]]
  // Prune objects emptied by the removal so the file stays sparse.
  for (var j = path.length - 2; j >= 0; j--) {
    if (Object.keys(parents[j + 1]).length) break
    delete parents[j][path[j]]
  }
  return withVersion(out)
}

function setOverride(overrides, path, value) {
  var out = clone(isPlainObject(overrides) ? overrides : {})
  var node = out
  for (var i = 0; i < path.length - 1; i++) {
    if (!isPlainObject(node[path[i]])) node[path[i]] = {}
    node = node[path[i]]
  }
  node[path[path.length - 1]] = clone(value)
  return withVersion(out)
}

// A removed effective key cannot hide a default; it resets that override.
function applyChanges(overrides, changes) {
  var out = withVersion(clone(isPlainObject(overrides) ? overrides : {}))
  for (var i = 0; i < changes.length; i++) {
    var change = changes[i]
    if (!change.path.length || UNSAFE_KEYS.indexOf(change.path[0]) >= 0) continue
    out = change.removed ? removeOverride(out, change.path) : setOverride(out, change.path, change.value)
  }
  return out
}

function withVersion(overrides) {
  var out = { version: VERSION }
  var keys = Object.keys(overrides)
  for (var i = 0; i < keys.length; i++) if (keys[i] !== "version") out[keys[i]] = overrides[keys[i]]
  return out
}

function serialize(overrides) {
  return JSON.stringify(withVersion(overrides), null, 2) + "\n"
}

if (typeof module !== "undefined") {
  module.exports = {
    VERSION: VERSION, validate: validate, validateDefaults: validateDefaults, parse: parse,
    resolve: resolve, diff: diff, applyChanges: applyChanges, removeOverride: removeOverride,
    serialize: serialize
  }
}
