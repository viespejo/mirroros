import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The notification indicator: Do Not Disturb, snoozed, or a screen share
// awaiting a snooze decision. Click to silence or resume; right-click for the
// notification panel.
BarIndicator {
  id: root

  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false
  // A built-in clone of the indicators widget gets a narrowed service proxy
  // with only the silence switch; everything past it needs the real service.
  readonly property bool fullService: !!notificationService && notificationService.snoozeRevision !== undefined
  readonly property bool snoozed: fullService && notificationService.anySnooze === true
  readonly property bool sharingOffer: fullService && notificationService.sharingOfferPending === true
  // MirrorOS (DEC-021/022): notifications that arrived while the session was locked.
  readonly property int awayCount: fullService && notificationService.whileAwayCount > 0 ? notificationService.whileAwayCount : 0

  readonly property string bellOff: "\u{f009b}"
  readonly property string bellSleep: "\u{f00a0}"
  readonly property string sharingGlyph: "\u{f1483}"
  readonly property string bellOn: "\u{f009a}"

  active: dnd || snoozed || sharingOffer || awayCount > 0
  activeText: sharingOffer ? sharingGlyph : dnd ? bellOff : snoozed ? bellSleep : bellOn
  inactiveText: bellOff
  activeTooltipText: sharingOffer ? I18n.t("bar.notificationsSharing")
                   : dnd ? I18n.t("bar.allowNotifications")
                   : snoozed ? I18n.t("bar.notificationsSnoozed")
                   : I18n.t("notifications.showHistory")
  inactiveTooltipText: I18n.t("bar.silenceNotifications")

  onPressed: function(button) {
    if (!root.notificationService) return
    if (button === Qt.RightButton || root.sharingOffer) {
      if (root.fullService) root.notificationService.requestPanel("toggle", root.screenName)
    } else if (root.fullService && root.active) {
      // Source snoozes are resumed one by one from the panel.
      if (root.dnd || root.notificationService.globalSnoozeUntil > 0) root.notificationService.letEverythingThrough()
      else root.notificationService.requestPanel("open", root.screenName)
    } else {
      root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
    }
  }

  readonly property string screenName: {
    var window = root.QsWindow.window
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  // Clicks, keybindings and IPC all go through the service; the indicator on
  // the requested monitor answers, building its panel the first time.
  Connections {
    target: root.fullService ? root.notificationService : null
    ignoreUnknownSignals: true
    function onPanelRequested(action, screenName) {
      if (!root.belongsInBlock || (screenName && root.screenName && root.screenName !== screenName)) return
      if (!panelLoader.item) {
        panelLoader.setSource(root.notificationService.panelUrl,
                              { anchorItem: root, bar: root.bar, service: root.notificationService })
      }
      var panel = panelLoader.item
      if (!panel) return
      if (action === "settings") panel.openSettings()
      else panel.open()
    }
  }

  Loader { id: panelLoader }

  // MirrorOS: the while-away count as a small superscript at the bell's
  // top-right corner. Its first digit keeps the single-digit position, so
  // "9+" grows to the right instead of over the bell.
  Text {
    id: awayBadge
    visible: root.awayCount > 0 && root.effectiveActive
    x: root.width - awayDigit.advanceWidth - 1
    y: 1
    textFormat: Text.PlainText
    text: root.awayCount > 9 ? "9+" : I18n.formatNumber(root.awayCount)
    font.family: root.fontFamily
    font.pixelSize: Math.round(Style.bar.iconFont * 0.6)
    font.bold: true
    color: root.foreground
    renderType: Text.NativeRendering
  }

  TextMetrics { id: awayDigit; font: awayBadge.font; text: "0" }
}
