// Read the five root-level color strings used by the shell, not general TOML.
// Reject the entire palette if a required key is missing, duplicated or invalid.
function parse(text) {
  var names = ["foreground", "background", "accent", "muted", "red"]
  var values = {}
  var inTable = false
  var lines = String(text || "").split(/\r?\n/)
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line || line.charAt(0) === "#") continue
    if (line.charAt(0) === "[") { inTable = true; continue }
    if (inTable) continue
    var key = line.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=/)
    if (!key || names.indexOf(key[1]) < 0) continue
    var match = line.match(/^[A-Za-z_][A-Za-z0-9_]*\s*=\s*"(#[0-9a-fA-F]{6})"\s*(?:#.*)?$/)
    if (!match || Object.prototype.hasOwnProperty.call(values, key[1])) return null
    values[key[1]] = match[1]
  }
  for (var j = 0; j < names.length; j++) {
    if (!Object.prototype.hasOwnProperty.call(values, names[j])) return null
  }
  return values
}

if (typeof module !== "undefined") module.exports = { parse: parse }
