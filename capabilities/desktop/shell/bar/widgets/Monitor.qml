import QtQuick
import Quickshell
import qs.Ui

// Adapted from Omarchy shell/plugins/panels/monitor/Panel.qml 359-360,
// 478-482 at 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c)
// David Heinemeier Hansson). Native screen-count glyph only. Display panel
// clicks and brightness wheel are integration points (DEC-016), with no action.
// The compositor supplies display state; brightness availability is not implied.
BarWidget {
  id: root
  moduleName: "omarchy.monitor"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Quickshell.screens.length > 1 ? "\u{f037a}" : "\u{f0379}"
  }
}
