.pragma library

// MirrorOS microphone indicator model. New code; isShellLevelMeter is taken
// from Omarchy shell/Commons/AudioNodesModel.js at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David Heinemeier
// Hansson). Pure functions shared by Microphone.qml and the Node tests.

// The shell's own level meter (the audio panel's peak monitor) is a capture
// stream named after the shell or after its stream depending on the PipeWire
// version. It is not an app using the input.
function isShellLevelMeter(name) {
  var value = String(name || "")
  return value === "quickshell" || value === "quickshell-peak-monitor"
}

// True when any non-muted capture stream that is not a shell meter exists.
function inUse(nodes) {
  var list = nodes || []
  for (var i = 0; i < list.length; i++) {
    var node = list[i]
    if (!node || !node.isStream || node.isSink !== false) continue
    if (node.audio && node.audio.muted) continue
    if (isShellLevelMeter(node.name)) continue
    return true
  }
  return false
}

// Shown only with a default source that exposes audio controls, and only
// while it is in use or muted.
function visible(hasSource, hasAudio, muted, inUse) {
  return !!hasSource && !!hasAudio && (!!inUse || !!muted)
}
