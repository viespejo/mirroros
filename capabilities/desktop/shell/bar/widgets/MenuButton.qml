import QtQuick
import qs.Ui

// Adapted from Omarchy shell/plugins/menu/BarWidget.qml at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c) David Heinemeier
// Hansson). Changes: PROVISIONAL glyph, the Arch logo (U+F303) from the bar's
// Nerd Font, instead of Omarchy's logo (U+E900 in its brand font); left click
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
    text: "\uf303"
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) return
      if (root.bar.shell) root.bar.shell.toggle("menu")
    }
  }
}
