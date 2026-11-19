import QtQuick
import qs.Commons
import qs.Ui

// Click to silence or resume notifications.
BarIndicator {
  id: root

  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false

  readonly property string bellOff: "\u{f009b}"

  active: dnd
  activeText: bellOff
  inactiveText: bellOff
  activeTooltipText: I18n.t("bar.allowNotifications")
  inactiveTooltipText: I18n.t("bar.silenceNotifications")

  onPressed: function() {
    if (root.notificationService)
      root.notificationService.setDoNotDisturb(!root.dnd)
  }
}
