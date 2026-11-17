pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons

// Adapted from Omarchy v4.5.0 (ac2690cd7be4f47e4a255f5e2e78d904d436b068),
// shell/plugins/dock/AppGrid.qml (MIT, Copyright (c) David Heinemeier Hansson).
// Grid geometry, icons and two-line labels only; the shared menu owns search,
// selection and launch. No dock, drag, context menu or uninstall integration.
Item {
  id: root

  required property var menu
  required property var model
  required property int screenWidth
  required property int screenHeight

  readonly property int iconSize: Math.round(56 * Style.fontScale)
  readonly property int labelHeight: Math.ceil(labelMetrics.height) * 2
  readonly property int cellGutter: Style.spacing.sm
  readonly property int cellPadding: Style.spacing.lg
  readonly property int cellWidth: Math.round(root.iconSize * 2.2)
  readonly property int cellHeight: root.cellPadding * 2 + root.iconSize + Style.spacing.md + root.labelHeight
  readonly property int inset: Style.spacing.panelPadding + Math.max(1, Style.space(2))
  readonly property int headerHeight: Math.max(Style.space(36), Style.font.heading + Style.spacing.controlPaddingY * 2)
  readonly property int headerSpacing: Style.spacing.xl
  readonly property int screenMargin: Style.space(40)
  readonly property int cardWidth: Math.max(1, Math.min(root.screenWidth - root.screenMargin * 2, 7 * root.cellWidth + root.inset * 2))
  readonly property int columns: Math.max(1, Math.floor((root.cardWidth - root.inset * 2) / root.cellWidth))
  readonly property int gridWidth: root.columns * root.cellWidth
  readonly property int cardHeight: Math.max(1, Math.min(root.screenHeight - root.screenMargin * 2, root.inset * 2 + root.headerHeight + root.headerSpacing + 4 * root.cellHeight))
  readonly property int viewportHeight: Math.max(0, root.cardHeight - root.inset * 2 - root.headerHeight - root.headerSpacing)

  function reveal(index) {
    grid.positionViewAtIndex(index, GridView.Contain)
  }

  FontMetrics {
    id: labelMetrics
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.body
  }

  GridView {
    id: grid
    anchors.fill: parent
    model: root.model
    clip: true
    cellWidth: root.cellWidth
    cellHeight: root.cellHeight
    boundsBehavior: Flickable.StopAtBounds

    delegate: Item {
      id: cell
      required property int index
      required property string itemId
      required property string appIcon
      required property string label
      readonly property bool selected: root.menu.cursorActive && itemId === root.menu.selectedId

      width: root.cellWidth
      height: root.cellHeight

      Image {
        id: icon
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cellPadding
        width: root.iconSize
        height: root.iconSize
        sourceSize: Qt.size(root.iconSize * Screen.devicePixelRatio, root.iconSize * Screen.devicePixelRatio)
        source: root.menu.appLibrary ? root.menu.appLibrary.iconSource(cell.appIcon) : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: false
        smooth: true
        mipmap: true
      }

      Rectangle {
        anchors.centerIn: labelText
        width: Math.min(cell.width - root.cellGutter * 2, labelText.contentWidth + Style.spacing.md * 2)
        height: labelText.contentHeight + Style.spacing.xs * 2
        radius: Style.cornerRadius
        color: cell.selected ? root.menu.selectedBackground : "transparent"
      }

      Text {
        id: labelText
        anchors.top: icon.bottom
        anchors.topMargin: Style.spacing.md
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - (root.cellGutter + Style.spacing.md) * 2
        textFormat: Text.PlainText
        text: cell.label
        color: cell.selected ? root.menu.selectedText : root.menu.foreground
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.menu.selectFromPointer(cell.index, cell, { x: pointer.mouseX, y: pointer.mouseY })
        onPositionChanged: function(mouse) { root.menu.selectFromPointer(cell.index, cell, mouse) }
        onClicked: root.menu.activateIndex(cell.index, true)
      }
    }
  }
}
