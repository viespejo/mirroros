import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import "MicrophoneModel.js" as MicrophoneModel

// Adapted from Omarchy shell/plugins/bar/widgets/Microphone.qml at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David Heinemeier
// Hansson). Changes: native Pipewire.defaultAudioSource only (no UntypedInput
// or wpctl path for virtual sources, no AudioNodes platform filter); in-use and
// visibility come from the owned MicrophoneModel.js, so the indicator is hidden
// unless the source is in use or muted, and without a source or audio
// controls; middle click toggles the audio panel through the bar instead of
// omarchy-shell.
BarWidget {
  id: root
  moduleName: "omarchy.microphone"

  readonly property var source: Pipewire.defaultAudioSource
  readonly property bool hasAudio: !!(source && source.audio)
  readonly property bool muted: hasAudio ? source.audio.muted : true
  readonly property real volume: hasAudio ? source.audio.volume : 0
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property bool streamsActive: MicrophoneModel.inUse(nodes)
  readonly property bool inUse: streamsActive && !muted

  visible: MicrophoneModel.visible(source !== null, hasAudio, muted, streamsActive)
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  function toggleMute() {
    if (root.hasAudio) root.source.audio.muted = !root.source.audio.muted
  }

  PwObjectTracker { objects: root.source ? [root.source] : [] }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.muted ? "󰍭" : "󰍬"
    active: root.inUse
    tooltipText: root.muted ? I18n.t("bar.microphoneMuted") : (root.inUse ? I18n.t("bar.microphoneInUse") : I18n.t("bar.microphoneLive"))
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.bar.requestPanel("omarchy.audio", "toggle")
      else root.toggleMute()
    }
    onWheelMoved: function(delta) {
      var step = 0.05
      if (!root.hasAudio) return
      root.source.audio.volume = Math.max(0, Math.min(1, root.volume + (delta > 0 ? step : -step)))
    }
  }
}
