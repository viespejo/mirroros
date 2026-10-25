import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Adapted from Omarchy shell/plugins/panels/audio/Panel.qml at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c) David Heinemeier
// Hansson): bar glyphs, volume wheel, OSD and mute-all. Headphone detection
// comes from audio/Model.js. No panel, DSP sink resolver or untyped input.
// New: delayed unavailable state; ready provider without a sink stays hidden.
BarWidget {
  id: root
  moduleName: "omarchy.audio"

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var volumeSink: sink
  readonly property bool hasOutput: !!(volumeSink && volumeSink.audio)
  readonly property bool hasInput: !!(source && source.audio)
  readonly property real outputVolume: hasOutput ? volumeSink.audio.volume : 0
  readonly property bool outputMuted: hasOutput ? volumeSink.audio.muted : false
  readonly property bool inputMuted: hasInput ? source.audio.muted : false
  readonly property bool anyAudible: (hasOutput && !outputMuted) || (hasInput && !inputMuted)
  readonly property bool unavailable: !Pipewire.ready && providerSettled
  property bool providerSettled: false
  property real wheelAccumulator: 0

  Timer {
    interval: 3000
    running: !Pipewire.ready && !root.providerSettled
    onTriggered: root.providerSettled = true
  }

  Connections {
    target: Pipewire
    function onReadyChanged() {
      if (Pipewire.ready) root.providerSettled = false
    }
  }

  PwObjectTracker { objects: [root.sink, root.source] }

  function isHeadphones(node) {
    if (!node) return false
    var p = node.ready && node.properties ? node.properties : {}
    var blob = String([
      node.name, node.description, node.nickname,
      p["device.icon-name"] || "",
      p["device.product.name"] || "",
      p["node.description"] || "",
      p["node.nick"] || ""
    ].join(" ")).toLowerCase()
    return blob.indexOf("headphone") !== -1
      || blob.indexOf("headset") !== -1
      || blob.indexOf("earbud") !== -1
      || blob.indexOf("earphone") !== -1
      || blob.indexOf("airpod") !== -1
  }

  function outputIcon(volume) {
    if (!sink || !sink.audio) return "\ueee8"
    if (isHeadphones(sink)) return "\u{f02cb}"
    if (outputMuted) return "\ueee8"
    var v = volume === undefined ? outputVolume : volume
    if (v >= 0.67) return "\uf028"
    if (v >= 0.34) return "\uf027"
    if (v > 0) return "\uf026"
    return "\ueee8"
  }

  function setOutputVolume(v) {
    if (!volumeSink || !volumeSink.audio) return outputVolume
    var volume = Math.max(0, Math.min(1, v))
    volumeSink.audio.volume = volume
    return volume
  }

  function showVolumeOsd(volume) {
    if (!bar || !bar.shell) return
    bar.shell.summon("omarchy.osd", JSON.stringify({
      icon: outputIcon(volume),
      value: Math.round(volume * 100)
    }))
  }

  function toggleAllMuted() {
    var mute = anyAudible
    if (hasOutput) volumeSink.audio.muted = mute
    if (hasInput) source.audio.muted = mute
  }

  visible: unavailable || (Pipewire.ready && hasOutput)
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.unavailable ? "\uf071" : root.outputIcon()
    tooltipText: root.unavailable
      ? "Audio unavailable: PipeWire is not ready; install pipewire and wireplumber and start their user services."
      : ""
    onPressed: function(b) {
      if (Pipewire.ready && b === Qt.RightButton) root.toggleAllMuted()
      // Other buttons: audio panel integration point (DEC-016).
    }
    onWheelMoved: function(delta) {
      if (!Pipewire.ready || !root.hasOutput) return
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps === 0) return
      var volume = root.setOutputVolume(root.outputVolume + wheel.steps * 0.05)
      root.showVolumeOsd(volume)
    }
  }
}
