import QtQuick
import QtQuick.Shapes
import qs.Ui

// Adapted from Omarchy shell/plugins/menu/BarWidget.qml at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c) David Heinemeier
// Hansson). Changes: the shared MirrorOS symbol (the path of
// capabilities/visual/branding/mirroros-symbol.svg, filled with the bar
// foreground) instead of Omarchy's logo (U+E900 in its brand font); left click
// toggles the MirrorOS menu root in-process instead of `omarchy-shell shell
// toggle omarchy.menu`; right click (xdg-terminal-exec) is an integration
// point with no action.
BarWidget {
  id: root
  moduleName: "omarchy.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Shape {
        ShapePath {
          strokeWidth: -1
          fillColor: button.active && button.useActiveColor ? button.activeColor : button.foreground
          PathSvg { path: "M6 0h2v2h-2z M4 2h4v2h-4z M10 2h2v2h-2z M2 4h4v2h-4z M10 4h4v2h-4z M0 6h4v2h-4z M12 6h4v2h-4z M0 8h4v2h-4z M12 8h4v2h-4z M2 10h4v2h-4z M10 10h4v2h-4z M4 12h2v2h-2z M8 12h4v2h-4z M8 14h2v2h-2z" }
        }
      }
    }
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) return
      if (root.bar.shell) root.bar.shell.toggle("menu")
    }
  }
}
