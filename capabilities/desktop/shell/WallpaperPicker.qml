pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import "Commons/WallpaperCatalog.js" as Catalog

// Adapted from Omarchy shell/plugins/image-picker/ImagePicker.qml (MIT,
// Copyright (c) David Heinemeier Hansson); see UPSTREAM.md for source identity.
// In-process catalog and selection signals replace external response files.
Item {
  id: root
  property var images: []
  readonly property var paths: images.map(function(image) { return image.filePath })
  property var targetScreen: null
  property bool opened: false
  property bool layoutSettled: false
  property int selectedIndex: 0
  property int requestSerial: 0
  readonly property string currentPath: paths[selectedIndex] || ""
  readonly property int expandedWidth: 768
  readonly property int expandedHeight: 475
  readonly property int sliceWidth: 108
  readonly property int sliceHeight: 432
  readonly property int sliceSpacing: -30
  readonly property int skewOffset: 28
  signal selected(string path)

  onPathsChanged: {
    selectedIndex = Math.max(0, Math.min(selectedIndex, paths.length - 1))
    Qt.callLater(focusPicker)
  }

  function focusPicker() {
    if (!opened || !layoutSettled) return
    if (paths.length) carousel.forceActiveFocus()
    else emptyKeys.forceActiveFocus()
  }

  function focusedScreen() {
    var monitor = Hyprland.focusedMonitor
    for (var i = 0; i < Quickshell.screens.length; i++) {
      if (monitor && Quickshell.screens[i].name === monitor.name) return Quickshell.screens[i]
    }
    return Quickshell.screens.length ? Quickshell.screens[0] : null
  }

  function open(output, current) {
    requestSerial += 1
    targetScreen = output || focusedScreen()
    selectedIndex = Catalog.indexForSelectedImage(images, current)
    layoutSettled = false
    opened = !!targetScreen
    var serial = requestSerial
    Qt.callLater(function() {
      if (root.opened && serial === root.requestSerial) {
        root.layoutSettled = true
        root.focusPicker()
      }
    })
    return opened
  }

  function cancel() {
    requestSerial += 1
    opened = false
    layoutSettled = false
  }

  function selectAdjacent(direction) {
    if (paths.length) selectedIndex = (selectedIndex + direction + paths.length) % paths.length
  }

  function applySelected() {
    if (!currentPath) return
    var path = currentPath
    cancel()
    selected(path)
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (root.opened && Quickshell.screens.indexOf(root.targetScreen) < 0) root.cancel()
    }
  }

  PanelWindow {
    id: panel
    screen: root.targetScreen
    visible: root.opened && !!root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "mirroros-wallpaper-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Commons.Color.background
      opacity: 0.92
    }
    MouseArea {
      anchors.fill: parent
      onClicked: root.cancel()
    }

    Item {
      id: card
      visible: root.layoutSettled && root.paths.length > 0
      width: Math.min(parent.width - 80, root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing) + 40)
      height: root.expandedHeight + Style.space(30) + 30
      anchors.centerIn: parent
      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: carousel
        anchors.top: parent.top
        anchors.topMargin: Style.space(30)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing)
        focus: true
        readonly property real itemStep: root.sliceWidth + root.sliceSpacing
        readonly property real previewX: (width - root.expandedWidth) / 2

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) root.cancel()
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.applySelected()
          else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab
                   || (event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier)) root.selectAdjacent(-1)
          else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) root.selectAdjacent(1)
          else return
          event.accepted = true
        }

        Repeater {
          model: root.paths.length
          delegate: Item {
            id: slice
            required property int index
            readonly property int relativeIndex: index - root.selectedIndex
            readonly property bool selected: index === root.selectedIndex
            readonly property bool nearby: Math.abs(relativeIndex) <= 16
            property bool sourceActivated: nearby
            onNearbyChanged: if (nearby) sourceActivated = true
            visible: nearby
            x: selected ? carousel.previewX : (relativeIndex < 0
              ? carousel.previewX + relativeIndex * carousel.itemStep
              : carousel.previewX + root.expandedWidth + root.sliceSpacing + (relativeIndex - 1) * carousel.itemStep)
            width: selected ? root.expandedWidth : root.sliceWidth
            height: selected ? root.expandedHeight : root.sliceHeight
            y: selected ? 0 : (root.expandedHeight - root.sliceHeight) / 2
            z: selected ? 100 : 50 - Math.min(Math.abs(relativeIndex), 40)
            readonly property real topLeft: root.skewOffset
            readonly property real topRight: width
            readonly property real bottomRight: width - root.skewOffset
            readonly property real bottomLeft: 0

            Item {
              id: maskShape
              anchors.fill: parent
              visible: false
              layer.enabled: true
              Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  fillColor: "white"
                  strokeColor: "transparent"
                  startX: slice.topLeft; startY: 0
                  PathLine { x: slice.topRight; y: 0 }
                  PathLine { x: slice.bottomRight; y: slice.height }
                  PathLine { x: slice.bottomLeft; y: slice.height }
                  PathLine { x: slice.topLeft; y: 0 }
                }
              }
            }

            Item {
              anchors.fill: parent
              layer.enabled: true
              layer.smooth: true
              layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskShape
                maskThresholdMin: 0.3
                maskSpreadAtMin: 0.3
              }
              Image {
                anchors.fill: parent
                source: slice.sourceActivated && root.images[slice.index]
                  ? Util.fileUrl(root.images[slice.index].thumbnailPath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: true
                smooth: true
              }
              Rectangle {
                anchors.fill: parent
                color: Util.alpha(Commons.Color.background, slice.selected ? 0 : 0.42)
              }
            }

            Shape {
              anchors.fill: parent
              antialiasing: true
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                fillColor: "transparent"
                strokeColor: slice.selected ? Commons.Color.accent : Commons.Color.muted
                strokeWidth: slice.selected ? 3 : 1
                startX: slice.topLeft; startY: 0
                PathLine { x: slice.topRight; y: 0 }
                PathLine { x: slice.bottomRight; y: slice.height }
                PathLine { x: slice.bottomLeft; y: slice.height }
                PathLine { x: slice.topLeft; y: 0 }
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: slice.selected ? root.applySelected() : root.selectedIndex = slice.index
            }
          }
        }
      }
    }

    Item {
      id: emptyKeys
      anchors.fill: parent
      Keys.onEscapePressed: root.cancel()
    }

    Text {
      anchors.centerIn: parent
      visible: root.layoutSettled && root.paths.length === 0
      textFormat: Text.PlainText
      text: "No wallpapers available"
      color: Commons.Color.foreground
      font.pixelSize: Style.font.title
    }
  }
}
