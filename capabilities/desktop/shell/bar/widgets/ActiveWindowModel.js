.pragma library

// MirrorOS active window label model. New code; pure function shared by
// ActiveWindow.qml and the Node tests.

// "<application name> · <window title>". Only the name when the title is
// empty or equal to it ignoring case; the raw app id as the name when no desktop entry
// matched; the title alone when no name is known; "" when nothing is known.
function label(appName, title, appId) {
  var name = String(appName || appId || "").trim()
  var text = String(title || "").trim()
  if (name === "") return text
  if (text === "" || text.toLowerCase() === name.toLowerCase()) return name
  return name + " \u00b7 " + text
}
