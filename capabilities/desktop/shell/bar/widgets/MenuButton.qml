import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// Adapted from Omarchy shell/plugins/menu/BarWidget.qml at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c) David Heinemeier
// Hansson). Changes: the shared MirrorOS symbol (the path of
// capabilities/visual/branding/mirroros-symbol.svg, filled with the theme
// accent) instead of Omarchy's logo (U+E900 in its brand font), drawn on the
// physical pixel grid; left click toggles the MirrorOS menu root in-process
// instead of `omarchy-shell shell toggle omarchy.menu`; right click
// (xdg-terminal-exec) is an integration point with no action.
BarWidget {
  id: root
  moduleName: "omarchy.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) return
      if (root.bar.shell) root.bar.shell.toggle("menu")
    }

    // The symbol is an 8x8 grid of 2-unit blocks. Fractional scales split
    // blocks unevenly, so each block spans a whole number of physical pixels
    // (the smallest that covers the bar icon size) and the symbol origin sits
    // on a physical pixel.
    Item {
      id: symbol
      readonly property var barWindow: button.QsWindow.window
      readonly property real dpr: barWindow && barWindow.devicePixelRatio > 0 ? barWindow.devicePixelRatio : 1
      readonly property int blockPx: Math.max(1, Math.ceil(Style.bar.iconSize * dpr / 8))
      width: 8 * blockPx / dpr
      height: width

      function snap() {
        var center = button.mapToItem(null, button.width / 2, button.height / 2)
        var origin = button.mapToItem(null, 0, 0)
        var span = 8 * blockPx
        x = Math.round(center.x * dpr - span / 2) / dpr - origin.x
        y = Math.round(center.y * dpr - span / 2) / dpr - origin.y
      }

      Component.onCompleted: snap()

      Connections {
        target: button.Window.window
        function onAfterAnimating() { symbol.snap() }
      }

      Shape {
        width: 16
        height: 16
        transformOrigin: Item.TopLeft
        scale: symbol.width / 16
        ShapePath {
          strokeWidth: -1
          fillColor: button.active && button.useActiveColor ? button.activeColor : Commons.Color.accent
          PathSvg { path: "M6 0h2v2h-2z M4 2h4v2h-4z M10 2h2v2h-2z M2 4h4v2h-4z M10 4h4v2h-4z M0 6h4v2h-4z M12 6h4v2h-4z M0 8h4v2h-4z M12 8h4v2h-4z M2 10h4v2h-4z M10 10h4v2h-4z M4 12h2v2h-2z M8 12h4v2h-4z M8 14h2v2h-2z" }
        }
      }
    }
  }
}
