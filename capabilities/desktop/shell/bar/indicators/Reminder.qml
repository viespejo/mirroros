import QtQuick
import Quickshell
import qs.Ui

// Adapted from Omarchy shell/plugins/bar/indicators/Reminder.qml at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David Heinemeier
// Hansson). Changes: the count and tooltip come from the shell's
// mirroros.reminders service, which runs `reminder show --json` once per
// refresh for every bar, instead of a Process per indicator, its
// Component.onCompleted run and the indicatorHost refresh connection; the
// click runs MirrorOS's reminder command by absolute path, or opens the
// shell's reminder prompt directly instead of `omarchy-reminder -i`.
BarIndicator {
  id: root

  readonly property var remindersService: bar?.shell?.firstPartyServiceFor("mirroros.reminders")
  readonly property int reminderCount: remindersService ? remindersService.count : 0
  readonly property string tooltip: remindersService ? remindersService.tooltip : ""

  active: reminderCount > 0
  activeText: "󰢌"
  inactiveText: "󰢌"
  activeTooltipText: tooltip
  inactiveTooltipText: tooltip

  function openReminderFlow() {
    if (root.bar && root.bar.shell) root.bar.shell.openReminders()
  }

  onPressed: function() {
    if (root.reminderCount > 0) Quickshell.execDetached(["/usr/share/mirroros/reminders/reminder", "show"])
    else root.openReminderFlow()
  }
}
