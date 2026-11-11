import QtQuick
import qs.Commons
import qs.Ui

// Adapted from Omarchy shell/plugins/bar/indicators/StayAwake.qml at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David Heinemeier
// Hansson). Changes: reads the shell's runtime-only mirroros.stay-awake service
// (a native idle inhibitor) instead of omarchy.idle; the active tooltip is the
// literal "Allow Idle Lock" because MirrorOS has no screensaver.
BarIndicator {
  id: root

  readonly property var stayAwakeService: bar?.shell?.firstPartyServiceFor("mirroros.stay-awake")

  active: stayAwakeService ? stayAwakeService.enabled : false
  // A mug without a saucer, which drew a line under the cup.
  activeText: ""
  inactiveText: ""
  activeTooltipText: "Allow Idle Lock"
  inactiveTooltipText: I18n.t("bar.stayAwake")

  function toggle() {
    if (root.stayAwakeService) root.stayAwakeService.toggle()
  }

  onPressed: function() { root.toggle() }
}
