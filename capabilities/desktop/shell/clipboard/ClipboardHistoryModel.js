// Adapted from Omarchy 520c3ed969d30b58defe03eb19d603f32b4cb002
// shell/plugins/clipboard/ClipboardHistory.js (MIT, Copyright (c) David
// Heinemeier Hansson). cliphist TSV ids replace JSON entries and array indices;
// only bounded display text, filtering and selection are retained.
function parseHistory(raw) {
  var seen = {}
  return String(raw || "").split("\n").reduce(function(rows, line) {
    var tab = line.indexOf("\t")
    if (tab < 1) return rows
    var id = line.slice(0, tab)
    if (!/^[0-9]{1,19}$/.test(id) || seen[id]) return rows
    seen[id] = true
    var text = line.slice(tab + 1).slice(0, 8192)
    rows.push({ id: id, text: text, image: /^\[\[ binary data .+\]\]$/.test(text) })
    return rows
  }, [])
}

function displayRows(history, query, imageLabel) {
  var needle = String(query || "").trim().toLowerCase()
  return (Array.isArray(history) ? history : []).filter(function(entry) {
    return !needle || (entry.text + (entry.image ? " image png " + imageLabel : "")).toLowerCase().indexOf(needle) >= 0
  }).map(function(entry) {
    return { id: entry.id, image: entry.image, text: entry.text,
      label: entry.image ? (imageLabel || "Image") : entry.text.replace(/\s+/g, " ") }
  })
}

function selection(index, count, delta, absolute) {
  if (count <= 0) return 0
  var next = absolute ? delta : index + delta
  return Math.max(0, Math.min(count - 1, next))
}

function removeEntry(history, id) {
  return history.filter(function(entry) { return entry.id !== id })
}

if (typeof module !== "undefined") module.exports = {
  parseHistory: parseHistory, displayRows: displayRows,
  selection: selection, removeEntry: removeEntry
}
