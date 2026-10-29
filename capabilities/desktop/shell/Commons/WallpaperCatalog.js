// Ordered NUL records adapted from Omarchy's background scanner and picker model.
function next(paths, current) {
  if (!Array.isArray(paths) || paths.length === 0) return null
  var index = paths.indexOf(current)
  return paths[(index + 1) % paths.length]
}

function parse(text) {
  if (typeof text !== "string" || (text.length && text.charAt(text.length - 1) !== "\u0000")) return null
  var paths = text ? text.slice(0, -1).split("\u0000") : []
  for (var i = 0; i < paths.length; i++) if (paths[i].charAt(0) !== "/") return null
  return paths
}

// Adapted from ImagePickerModel.loadRows (MIT, David Heinemeier Hansson).
// Internal NUL path/thumbnail pairs replace the external tab/newline protocol.
function loadRows(text) {
  var rows = parse(text)
  if (rows === null || rows.length % 2) return null
  var images = []
  var seen = {}
  for (var i = 0; i < rows.length; i += 2) {
    var fileName = rows[i].split("/").pop()
    if (seen[fileName]) continue
    seen[fileName] = true
    images.push({ filePath: rows[i], fileName: fileName, thumbnailPath: rows[i + 1] })
  }
  return images
}

function indexForSelectedImage(images, selectedImage) {
  for (var i = 0; i < images.length; i++) if (images[i].filePath === selectedImage) return i
  return 0
}

if (typeof module !== "undefined") module.exports = {
  next: next, parse: parse, loadRows: loadRows, indexForSelectedImage: indexForSelectedImage
}
