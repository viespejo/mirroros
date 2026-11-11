import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../../panels/elsewhen" as Elsewhen

// MirrorOS host for the adapted Elsewhen world clock (ADR 0029), modelled on
// bar/widgets/Weather.qml. Shows Omarchy v4.5.0 Elsewhen's globe glyph and
// "World clock" tooltip and loads panels/elsewhen/Panel.qml, which has no bar
// button of its own. Panel IPC lives in the bar (native `worldclock` target
// with open/close/toggle). Any mouse button toggles the panel; upstream's
// right- and middle-click refresh is not kept, so nothing probes or fetches
// while the panel is closed. The qualified panels/elsewhen import makes
// Quickshell's scanner synthesize that directory's qmldir, so Panel.qml
// resolves its sibling types (HeroTitle, CitySearch, CityRow, ...).
BarWidget {
  id: root
  moduleName: "omarchy.elsewhen"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("moduleName" in target) target.moduleName = root.moduleName
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for the bar's panel routing (requestPanel, Tab
  // switching): Bar.isPanelItem requires open/close/opened on the bar-widget
  // root. Open maps to the panel's hotkey path so summoning suppresses the
  // center hover reveal.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("../../panels/elsewhen/Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    // Surrogate pair rather than a literal glyph, as Elsewhen's rows do.
    text: "\udb80\udde7"
    tooltipText: Commons.I18n.t("elsewhen.worldClock")

    onPressed: function(b) {
      if (root.bar) root.togglePanel()
    }
  }
}
