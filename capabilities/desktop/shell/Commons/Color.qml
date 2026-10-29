pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "BorderGeometry.js" as Geometry
import "ThemePalette.js" as ThemePalette
import "SurfacePalette.js" as SurfacePalette

// Adapted from Omarchy shell/Commons/Color.qml at 7075b61c6aaa5d8589f6e816867508fc96dc49d9
// (MIT, Copyright (c) David Heinemeier Hansson). Keeps the foundational palette
// defaults, the role helpers (pick, pickAlpha, flatColor, composed) and the
// bar, popups, tooltip, notifications and menu surface roles. MirrorOS reads
// five validated palette colors and bounded theme and personal surface settings.
QtObject {
  id: root

  property var palette: null
  onPaletteChanged: refreshSurfaces()
  property color foreground: palette ? palette.foreground : "#cacccc"
  property color background: palette ? palette.background : "#101315"
  property color accent: palette ? palette.accent : "#cacccc"
  property color urgent: palette ? palette.red : "#a55555"
  property color muted: palette ? palette.muted : "#707880"

  readonly property string stateHome: {
    var xdg = Quickshell.env("XDG_STATE_HOME") || ""
    return xdg.charAt(0) === "/" ? xdg : Quickshell.env("HOME") + "/.local/state"
  }
  property string palettePath: ""
  property bool trustedThemeSurfaces: false
  property Process themeResolver: Process {
    command: ["bash", "/usr/share/mirroros/themes/resolve-current", "/", root.stateHome, "0"]
    running: true
    stdout: StdioCollector { id: themeOutput }
    stderr: StdioCollector { id: themeError }
    onExited: function(code) {
      var diagnostic = themeError.text.trim()
      if (diagnostic) console.warn(diagnostic)
      var lines = themeOutput.text.trim().split("\n")
      if (code === 0 && lines[0] === "/usr/share/mirroros/themes/default" &&
          (lines.length === 1 || (lines.length === 2 && lines[1] === "shell.toml"))) {
        root.trustedThemeSurfaces = lines.length === 2
        root.palettePath = lines[0] + "/colors.toml"
      } else {
        console.warn("Cannot resolve MirrorOS shell theme; using defaults")
      }
    }
  }

  property FileView paletteFile: FileView {
    path: root.palettePath
    blockLoading: true
    printErrors: false
    onLoaded: {
      root.palette = ThemePalette.parse(text())
      if (!root.palette) console.warn("Invalid MirrorOS shell palette; using defaults")
    }
    onLoadFailed: function(error) {
      root.palette = null
      console.warn("Cannot read MirrorOS shell palette; using defaults")
    }
  }

  // Surface files are optional and never written by the shell.
  property string themeSurfaceText: ""
  property string userSurfaceText: ""
  property string surfaceDiagnostic: ""
  property var shellValues: ({})
  readonly property string configHome: {
    var xdg = Quickshell.env("XDG_CONFIG_HOME") || ""
    return xdg.charAt(0) === "/" ? xdg : Quickshell.env("HOME") + "/.config"
  }

  function refreshSurfaces() {
    var base = root.palette || {
      foreground: "#cacccc", background: "#101315", accent: "#cacccc", red: "#a55555", muted: "#707880"
    }
    var result = SurfacePalette.resolve(root.themeSurfaceText, root.userSurfaceText, base)
    root.shellValues = result.values
    var diagnostic = result.invalid.slice(0, 8).join(", ")
    if (result.invalid.length > 8) diagnostic += ", ..."
    if (diagnostic && diagnostic !== root.surfaceDiagnostic)
      console.warn("Invalid MirrorOS shell surface settings; using fallback: " + diagnostic)
    root.surfaceDiagnostic = diagnostic
  }

  property FileView themeSurfaceFile: FileView {
    path: root.palette && root.palettePath && root.trustedThemeSurfaces ? root.palettePath.replace(/colors\.toml$/, "shell.toml") : ""
    blockLoading: true
    printErrors: false
    onLoaded: { root.themeSurfaceText = text(); root.refreshSurfaces() }
    onLoadFailed: function(error) { root.themeSurfaceText = ""; root.refreshSurfaces() }
  }
  property FileView userSurfaceFile: FileView {
    path: root.configHome + "/mirroros/shell.toml"
    blockLoading: true
    printErrors: false
    onLoaded: { root.userSurfaceText = text(); root.refreshSurfaces() }
    onLoadFailed: function(error) {
      root.userSurfaceText = ""
      root.refreshSurfaces()
      if (error !== FileViewError.FileNotFound) console.warn("Cannot read personal shell surface settings; using fallback")
    }
  }

  function pick(key, fallback) {
    var v = shellValues[key]
    return (typeof v === "string" && v.length > 0) ? v : fallback
  }

  function pickAlpha(key, fallback) {
    var v = shellValues[key]
    if (typeof v !== "string" || v.length === 0) return fallback
    var n = Number(v)
    if (!isFinite(n)) return fallback
    return Util.clampAlpha(n)
  }

  function firstColorToken(value) {
    var parts = String(value || "").replace(/^\s+|\s+$/g, "").split(/\s+/)
    for (var i = 0; i < parts.length; i++) {
      if (!parts[i].match(/^-?\d+(?:\.\d+)?deg$/)) return parts[i]
    }
    return value
  }

  function flatColor(value, fallback) {
    var seen = Object.create(null)
    var token = firstColorToken(value)
    var role = String(token || "").replace(/^\s+|\s+$/g, "").toLowerCase()
    while (root.shellValues[role] && root.shellValues[role] !== token) {
      if (seen[role]) return fallback
      seen[role] = true
      token = firstColorToken(root.shellValues[role])
      role = String(token || "").replace(/^\s+|\s+$/g, "").toLowerCase()
    }
    if (role === "foreground" || role === "text") return root.foreground
    if (role === "accent") return root.accent
    if (role === "urgent") return root.urgent
    if (role === "muted") return root.muted
    if (role === "background") return root.background
    if (role === "transparent") return Qt.rgba(0, 0, 0, 0)

    var color = Geometry.canonicalColor(token, 1)
    if (typeof color === "string" && color === token && token.charAt(0) !== "#") return fallback
    return color
  }

  // Compose a color from a base-color key and its `-alpha` companion. If the
  // base token is a gradient, color-only consumers use the first stop.
  function composed(colorKey, alphaKey, colorFallback, alphaFallback) {
    return Util.alpha(flatColor(pick(colorKey, colorFallback), colorFallback), pickAlpha(alphaKey, alphaFallback))
  }

  readonly property QtObject bar: QtObject {
    property color background: root.composed("bar.background", "bar.background-alpha", root.background, 1.0)
    property color text: root.pick("bar.text", root.foreground)
    property color active: root.pick("bar.active", root.urgent)
  }
  readonly property QtObject popups: QtObject {
    property color background: root.composed("popups.background", "popups.background-alpha", root.background, 1.0)
    property color text: root.pick("popups.text", root.foreground)
    property color border: root.composed("popups.border", "popups.border-alpha", root.accent, 1.0)
  }
  readonly property QtObject tooltip: QtObject {
    property color background: root.composed("tooltip.background", "tooltip.background-alpha", root.background, root.palette ? 0.97 : 1.0)
    property color text: root.pick("tooltip.text", root.foreground)
    property color border: root.composed("tooltip.border", "tooltip.border-alpha", root.foreground, 1.0)
  }
  readonly property QtObject notifications: QtObject {
    property color background: root.composed("notifications.background", "notifications.background-alpha", root.background, 1.0)
    property color text: root.pick("notifications.text", root.foreground)
    property color border: root.composed("notifications.border", "notifications.border-alpha", root.accent, 1.0)
    property color countdown: root.pick("notifications.countdown", root.accent)
  }
  readonly property QtObject menu: QtObject {
    property color background: root.composed("menu.background", "menu.background-alpha", root.background, 1.0)
    property color text: root.pick("menu.text", root.foreground)
    property color border: root.composed("menu.border", "menu.border-alpha", root.foreground, 1.0)
    property color scrim: root.composed("menu.scrim", "menu.scrim-alpha", root.background, 0.5)
    property color selectedBackground: root.composed("menu.selected-background", "menu.selected-background-alpha", root.foreground, 0.08)
    property color selectedText: root.pick("menu.selected-text", root.accent)
    property color selectedBorder: root.composed("menu.selected-border", "menu.selected-border-alpha", root.foreground, root.palette ? 0.25 : 0.0)
  }
}
