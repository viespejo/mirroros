import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ActiveWindowModel.js" as ActiveWindowModel

// Adapted from Omarchy shell/plugins/bar/widgets/ActiveWindow.qml at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David Heinemeier
// Hansson). Changes: the label names the focused application (its desktop
// entry through DesktopEntries.heuristicLookup, or the raw app id) before the
// title, through the owned ActiveWindowModel.js; the tooltip shows the full
// label, and the root exposes tooltipHovered, which the bar requires before
// showing it; the width comes from a layout-independent TextMetrics instead
// of the elided Text's implicitWidth, which formed a binding loop; only a left click acts (activate), and both close() paths are
// removed, so middle and right clicks do nothing.
BarWidget {
  id: root
  moduleName: "omarchy.active-window"

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string appId: toplevel ? String(toplevel.appId || "") : ""
  readonly property string appName: {
    // DesktopEntries fills in asynchronously; re-resolve when it changes.
    var appsRevision = DesktopEntries.applications.values.length
    if (appId === "") return ""
    var entry = DesktopEntries.heuristicLookup(appId)
    return entry && entry.name ? String(entry.name) : ""
  }
  readonly property string title: toplevel ? ActiveWindowModel.label(appName, toplevel.title, appId) : ""
  readonly property int maxLabelWidth: Number(setting("maxWidth", 280))
  readonly property bool tooltipHovered: visible && mouseArea.containsMouse

  visible: title !== "" && !vertical
  implicitWidth: visible ? Math.min(maxLabelWidth, Math.ceil(labelMetrics.advanceWidth)) + Style.spacing.controlPaddingX * 2 : 0
  implicitHeight: barSize

  Behavior on implicitWidth {
    NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic }
  }

  TextMetrics {
    id: labelMetrics
    text: root.title
    font: labelText.font
  }

  Item {
    anchors.fill: parent
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    clip: true

    Text {
      id: labelText
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      width: parent.width
      text: root.title
      color: root.bar ? root.bar.barForeground : Commons.Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
      opacity: 0.85
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor

    onClicked: function(mouse) {
      if (root.toplevel) root.toplevel.activate()
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.title)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
