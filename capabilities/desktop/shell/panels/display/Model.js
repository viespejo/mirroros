// Adapted from Omarchy shell/plugins/panels/monitor/Model.js at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David
// Heinemeier Hansson). Added: parseState reads the owned `display state` JSON
// and canToggle mirrors its last-independent-output guard; mirrorState offers
// the ADR 0027 mirror toggle; upstream functions are unchanged.
function clampBrightness(value) {
  var n = Number(value)
  if (!isFinite(n)) return 1
  return Math.max(1, Math.min(100, Math.round(n)))
}

function normalizeScale(scale) {
  var n = parseFloat(String(scale || ""))
  if (!isFinite(n)) return ""
  return String(Math.round(n * 100) / 100)
}

function gcd(a, b) {
  while (b) {
    var remainder = a % b
    a = b
    b = remainder
  }
  return a
}

function cleanScale(scale, width, height) {
  var requested = Number(scale)
  var modeWidth = Number(width)
  var modeHeight = Number(height)
  if (!isFinite(requested) || !isFinite(modeWidth) || !isFinite(modeHeight)
      || requested <= 0 || modeWidth <= 0 || modeHeight <= 0) return ""

  var divisor = gcd(Math.round(modeWidth * 120), Math.round(modeHeight * 120))
  var scaleUnits = Math.round(requested * 120)
  if (scaleUnits > divisor) scaleUnits = divisor
  while (divisor % scaleUnits !== 0) scaleUnits++
  return normalizeScale(scaleUnits / 120)
}

function matchingScaleIndex(scales, currentScale, width, height) {
  var current = Number(currentScale)
  if (!Array.isArray(scales) || !isFinite(current)) return -1

  var bestIndex = -1
  var bestDistance = Infinity
  var normalizedCurrent = normalizeScale(current)
  for (var i = 0; i < scales.length; i++) {
    if (cleanScale(scales[i], width, height) !== normalizedCurrent) continue

    var distance = Math.abs(Number(scales[i]) - current)
    if (distance < bestDistance) {
      bestIndex = i
      bestDistance = distance
    }
  }
  return bestIndex
}

function availableScales(scales, width, height) {
  if (!Array.isArray(scales) || Number(width) <= 0 || Number(height) <= 0) return scales || []

  var byEffectiveScale = {}
  for (var i = 0; i < scales.length; i++) {
    var requested = Number(scales[i])
    var effective = Number(cleanScale(requested, width, height))

    if (!isFinite(requested) || !isFinite(effective)) continue

    var key = normalizeScale(effective)
    var existing = byEffectiveScale[key]
    if (!existing || Math.abs(requested - effective) < existing.distance) {
      byEffectiveScale[key] = {
        value: String(scales[i]),
        index: i,
        distance: Math.abs(requested - effective)
      }
    }
  }

  return Object.keys(byEffectiveScale)
    .map(function(key) { return byEffectiveScale[key] })
    .sort(function(a, b) { return a.index - b.index })
    .map(function(candidate) { return candidate.value })
}

// tr is an optional translate(key, english) from the QML side (I18n.t);
// without it the English text stands, which is what the Node tests assert.
function brightnessName(percent, tr) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  var p = Math.round(percent)
  if (p >= 95) return t("monitor.level.sunBlast", "Sun blast")
  if (p >= 80) return t("monitor.level.solarFlare", "Solar flare")
  if (p >= 65) return t("monitor.level.goldenHour", "Golden hour")
  if (p >= 45) return t("monitor.level.evenDay", "Even day")
  if (p >= 30) return t("monitor.level.softGlow", "Soft glow")
  if (p >= 20) return t("monitor.level.lampLight", "Lamp light")
  if (p >= 10) return t("monitor.level.candlelit", "Candlelit")
  return t("monitor.level.nightOwl", "Night owl")
}

function parseDisplays(raw) {
  var displays = []
  try {
    displays = raw ? JSON.parse(String(raw)) : []
  } catch (e) {
    displays = []
  }
  if (!Array.isArray(displays)) displays = []

  var count = 0
  for (var i = 0; i < displays.length; i++) {
    if (displays[i] && displays[i].enabled) count++
  }

  return {
    displays: displays,
    enabledDisplayCount: count
  }
}

// An enabled output that mirrors another one does not count as independent:
// `display output <name> off` refuses to leave none.
function independentEnabledCount(displays) {
  var count = 0
  var list = Array.isArray(displays) ? displays : []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].enabled && !list[i].mirror) count++
  }
  return count
}

// As in the command, mirrors of the target count: they are detached first and stay enabled.
function canToggle(display, displays) {
  if (!display || !display.name) return false
  if (!display.enabled || display.mirror) return true
  var list = Array.isArray(displays) ? displays : []
  for (var i = 0; i < list.length; i++) {
    var d = list[i]
    if (d && d.name !== display.name && d.enabled && (!d.mirror || d.mirror === display.name)) return true
  }
  return false
}

// `display mirror` mirrors the internal display onto an enabled external output
// and toggles back; it is offered only when both exist (ADR 0027).
function mirrorState(displays, internal) {
  var list = Array.isArray(displays) ? displays : []
  var name = typeof internal === "string" ? internal : ""
  var hasInternal = false
  var hasExternal = false
  var mirrored = false
  for (var i = 0; i < list.length; i++) {
    var d = list[i]
    if (!d || !d.name) continue
    if (d.name === name) hasInternal = true
    else if (d.enabled) {
      hasExternal = true
      if (d.mirror === name) mirrored = true
    }
  }
  var available = name !== "" && hasInternal && hasExternal
  return { available: available, active: available && mirrored }
}

// `display state` prints { focused, internal, external, backlight, outputs }.
// The backlight belongs to the internal panel, so the brightness slider is
// offered only while that panel is focused (or nothing is); an external
// display shows the fixed-brightness state.
function parseState(raw) {
  var state = null
  try {
    state = raw ? JSON.parse(String(raw)) : null
  } catch (e) {
    state = null
  }
  if (!state || typeof state !== "object" || Array.isArray(state)) state = {}

  var displays = Array.isArray(state.outputs) ? state.outputs.filter(function(d) {
    return d && typeof d.name === "string" && d.name !== ""
  }) : []
  var focused = typeof state.focused === "string" ? state.focused : ""
  var internal = typeof state.internal === "string" ? state.internal : ""
  var focusedDisplay = null
  for (var i = 0; i < displays.length; i++) {
    if (displays[i].name === focused) focusedDisplay = displays[i]
  }
  var backlight = Number(state.backlight)
  var hasBacklight = state.backlight !== null && state.backlight !== undefined && isFinite(backlight)
  var brightnessAvailable = hasBacklight && (!focusedDisplay || focusedDisplay.internal === true)

  return {
    displays: displays,
    enabledDisplayCount: parseDisplays(JSON.stringify(displays)).enabledDisplayCount,
    focusedMonitor: focused,
    internalMonitor: internal,
    externalMonitor: typeof state.external === "string" ? state.external : "",
    monitorScale: focusedDisplay ? normalizeScale(focusedDisplay.scale) : "",
    brightnessAvailable: brightnessAvailable,
    brightnessPercent: brightnessAvailable ? Math.max(0, Math.min(100, Math.round(backlight))) : 0
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    independentEnabledCount: independentEnabledCount,
    canToggle: canToggle,
    mirrorState: mirrorState,
    parseState: parseState,
    clampBrightness: clampBrightness,
    normalizeScale: normalizeScale,
    cleanScale: cleanScale,
    matchingScaleIndex: matchingScaleIndex,
    availableScales: availableScales,
    brightnessName: brightnessName,
    parseDisplays: parseDisplays
  }
}
