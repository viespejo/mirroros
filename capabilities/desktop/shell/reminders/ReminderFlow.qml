import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ReminderFlowModel.js" as ReminderFlowModel

// Adapted from Omarchy shell/plugins/reminders/ReminderFlow.qml at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David Heinemeier
// Hansson). Changes: no plugin host (the omarchyPath, shell and manifest
// properties and the shell.hide call are removed), so open() takes no payload
// and dismiss() only closes; the layer namespace is mirroros-reminders;
// submitting runs MirrorOS's reminder command by absolute path with the
// argument vector from ReminderFlowModel.reminderArgs, and invalid minutes send
// a transient notify-send notice from the reminder app instead of
// omarchy-notification-send. The card, key handling and both steps are
// unchanged.
Item {
  id: root

  property bool opened: false
  property string step: "minutes"
  property string minutes: ""
  property string filterText: ""
  property string fontFamily: Style.font.menuFamily

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int cardWidth: Math.min(Style.space(300), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(contentMargin * 2 + headerHeight, panel.height - Style.gapsOut * 2)
  readonly property string promptText: root.step === "message" ? I18n.t("reminders.messagePrompt") : I18n.t("reminders.minutesPrompt")

  function open() {
    root.opened = true
    root.step = "minutes"
    root.minutes = ""
    root.filterText = ""

    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open()
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
  }

  function submit() {
    var selection = root.filterText

    if (root.step === "minutes") {
      var nextMinutes = ReminderFlowModel.validMinutes(selection)

      if (!selection.trim()) {
        root.dismiss()
        return
      }

      if (!nextMinutes) {
        Quickshell.execDetached(["notify-send", "-a", "reminder", "-h", "boolean:transient:true", I18n.t("reminders.invalidTitle"), I18n.t("reminders.invalidBody")])
        return
      }

      root.minutes = nextMinutes
      root.step = "message"
      root.filterText = ""
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }

    if (root.step === "message") {
      var args = ["/usr/share/mirroros/reminders/reminder"].concat(ReminderFlowModel.reminderArgs(root.minutes, selection))
      root.dismiss()
      Quickshell.execDetached(args)
    }
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "mirroros-reminders"

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.submit()
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Item {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.filterText || root.promptText
          color: root.foreground
          opacity: root.filterText ? 1 : 0.58
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          elide: Text.ElideRight
        }
      }
    }
  }
}
