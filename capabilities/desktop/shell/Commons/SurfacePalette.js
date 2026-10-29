// Bounded surface settings reader. This is not a general TOML parser.
var surfaceKeys = {
  bar: ["background", "background-alpha", "text", "active"],
  popups: ["background", "background-alpha", "text", "border", "border-alpha"],
  tooltip: ["background", "background-alpha", "text", "border", "border-alpha"],
  notifications: ["background", "background-alpha", "text", "border", "border-alpha", "countdown"],
  menu: ["background", "background-alpha", "text", "border", "border-alpha", "scrim", "scrim-alpha",
    "selected-background", "selected-background-alpha", "selected-text", "selected-border", "selected-border-alpha"],
  hyprland: ["active-border", "active-border-foreground"]
}

// Invalid or duplicate supported entries are omitted individually. Unknown
// sections and keys are ignored, not treated as supported TOML features.
function parse(text) {
  var values = Object.create(null)
  var seen = Object.create(null)
  var invalid = Object.create(null)
  var section = ""
  var lines = String(text || "").split(/\r?\n/)
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line || line.charAt(0) === "#") continue
    var header = line.match(/^\[([a-z][a-z0-9-]*)\]\s*(?:#.*)?$/)
    if (header) { section = header[1]; continue }
    if (line.charAt(0) === "[") { section = ""; continue }
    var entry = line.match(/^([a-z][a-z0-9-]*)\s*=\s*(.*?)\s*$/)
    if (!entry || !Object.prototype.hasOwnProperty.call(surfaceKeys, section) ||
        surfaceKeys[section].indexOf(entry[1]) < 0) continue
    var key = section + "." + entry[1]
    if (seen[key]) { delete values[key]; invalid[key] = true; continue }
    seen[key] = true
    var raw = entry[2]
    if (/-alpha$/.test(entry[1])) {
      var alpha = raw.match(/^((?:\d+(?:\.\d+)?|\.\d+))\s*(?:#.*)?$/)
      if (!alpha || Number(alpha[1]) > 1) {
        invalid[key] = true; continue
      }
      values[key] = alpha[1]
    } else {
      var color = raw.match(/^"(#[0-9a-fA-F]{6}|[a-z][a-z0-9.-]*)"\s*(?:#.*)?$/)
      if (!color) { invalid[key] = true; continue }
      values[key] = color[1]
    }
  }
  return { values: values, invalid: Object.keys(invalid) }
}

// Resolve aliases before returning values to QML. A bad personal setting falls
// back to the theme setting for that key; a bad theme setting is omitted.
function resolve(themeText, userText, palette) {
  var theme = parse(themeText)
  var user = parse(userText)
  var failures = Object.create(null)
  var roles = {
    foreground: palette && palette.foreground,
    text: palette && palette.foreground,
    background: palette && palette.background,
    accent: palette && palette.accent,
    urgent: palette && palette.red,
    muted: palette && palette.muted
  }
  theme.invalid.forEach(function(key) { failures["theme:" + key] = true })
  user.invalid.forEach(function(key) { failures["user:" + key] = true })

  // Remove cyclic preferred entries as a group so their result cannot depend
  // on the order in which surface properties happen to be requested.
  var cycleChanged = true
  while (cycleChanged) {
    cycleChanged = false
    var candidates = Object.keys(theme.values).concat(Object.keys(user.values))
    for (var c = 0; c < candidates.length; c++) {
      var chain = []
      var cursor = candidates[c]
      while (cursor) {
        var index = chain.indexOf(cursor)
        if (index >= 0) {
          for (var j = index; j < chain.length; j++) {
            var cyclic = chain[j]
            if (Object.prototype.hasOwnProperty.call(user.values, cyclic)) {
              delete user.values[cyclic]; failures["user:" + cyclic] = true
            } else {
              delete theme.values[cyclic]; failures["theme:" + cyclic] = true
            }
          }
          cycleChanged = true
          break
        }
        chain.push(cursor)
        var map = Object.prototype.hasOwnProperty.call(user.values, cursor) ? user.values : theme.values
        var next = map[cursor]
        cursor = typeof next === "string" && next.indexOf(".") >= 0 && !/-alpha$/.test(cursor) ? next : ""
      }
    }
  }

  function valueFor(key, seen) {
    if (seen[key]) return null
    seen[key] = true
    var candidates = [user.values, theme.values]
    var sources = ["user:", "theme:"]
    for (var i = 0; i < candidates.length; i++) {
      if (!Object.prototype.hasOwnProperty.call(candidates[i], key)) continue
      var value = candidates[i][key]
      if (/-alpha$/.test(key) || /^#[0-9a-fA-F]{6}$/.test(value) || value === "transparent") {
        delete seen[key]
        return value
      }
      var resolved = null
      if (Object.prototype.hasOwnProperty.call(roles, value)) {
        if (typeof roles[value] === "string" && /^#[0-9a-fA-F]{6}$/.test(roles[value])) resolved = roles[value]
      } else if (value.indexOf(".") >= 0 && !/-alpha$/.test(value)) {
        resolved = valueFor(value, seen)
      }
      if (resolved !== null) { delete seen[key]; return resolved }
      failures[sources[i] + key] = true
    }
    delete seen[key]
    return null
  }

  var values = Object.create(null)
  var keys = Object.keys(theme.values).concat(Object.keys(user.values))
  for (var i = 0; i < keys.length; i++) {
    var result = valueFor(keys[i], Object.create(null))
    if (result !== null) values[keys[i]] = result
  }
  return { values: values, invalid: Object.keys(failures) }
}

if (typeof module !== "undefined") module.exports = { parse: parse, resolve: resolve }
