import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "widgets" as Widgets
import "BarModel.js" as BarModel

// Adapted from Omarchy shell/plugins/bar/Bar.qml at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c) David Heinemeier
// Hansson). Fixed top/opaque subset with static widget components. No plugin
// host, drag/pool, notch, transparency, hide flag or tray-section module host.
// Panel coordination (popout card and morph, Tab switching, focused-monitor
// routing and positional panels) is adapted from the same file at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068). MirrorOS divergences: routing
// follows "focused monitor wins" (BarModel.panelAction) instead of the open
// copy first, and panel IPC is declared here once with native IpcHandler
// targets instead of per-panel ShellIpc.
Item {
  id: root

  property var shell: null
  property var barConfig: ({})
  readonly property string position: "top"
  readonly property bool vertical: false
  readonly property bool barHidden: false
  readonly property int barSize: Style.bar.sizeHorizontal
  readonly property string fontFamily: Style.font.family
  readonly property color foreground: Commons.Color.bar.text
  readonly property color barForeground: foreground
  readonly property color background: Commons.Color.bar.background
  readonly property color urgent: Commons.Color.bar.active
  readonly property bool foregroundAnimationEnabled: true
  readonly property var layoutConfig: Util.normalizeLayout(barConfig.layout)
  // Per-widget inline settings (bar.widgets.<id>), layered over layout entries.
  readonly property var widgetOverrides: Util.isPlainObject(barConfig.widgets) ? barConfig.widgets : ({})

  function widgetOverride(entry) {
    var id = Util.canonicalWidgetId(BarModel.entryId(entry))
    return id && Util.isPlainObject(widgetOverrides[id]) ? widgetOverrides[id] : null
  }
  readonly property var providers: providerInventory
  property var clickTargets: []
  property var moduleSlots: []
  property var activePopout: null
  // Where the open panel's card stands, and in which section of the bar, so
  // a panel taking over in the same section can start its card from there.
  property var popoutCard: null
  property int barHoverCount: 0
  readonly property bool barHovered: barHoverCount > 0
  property bool centerSectionRevealHeld: false
  property bool centerHoverRevealSuppressed: false
  property var tooltipTarget: null
  property var pendingTooltipTarget: null
  property string tooltipText: ""
  property string pendingTooltipText: ""
  property bool tooltipShown: false
  property int tooltipRequest: 0

  ProviderState { id: providerInventory }

  // Deliberately closed map: no file discovery or user-supplied QML paths.
  readonly property var widgetComponents: ({
    "omarchy.menu": menuComponent,
    "omarchy.workspaces": workspacesComponent,
    "omarchy.active-window": activeWindowComponent,
    "omarchy.indicators": indicatorsComponent,
    "omarchy.clock": clockComponent,
    "omarchy.weather": weatherComponent,
    "omarchy.tray": trayComponent,
    "omarchy.keyboard-layout": keyboardComponent,
    "omarchy.bluetooth": bluetoothComponent,
    "omarchy.network": networkComponent,
    "omarchy.microphone": microphoneComponent,
    "omarchy.audio": audioComponent,
    "omarchy.monitor": monitorComponent,
    "omarchy.power": powerComponent
  })
  Component { id: menuComponent; Widgets.MenuButton { } }
  Component { id: workspacesComponent; Widgets.Workspaces { } }
  Component { id: activeWindowComponent; Widgets.ActiveWindow { } }
  Component { id: indicatorsComponent; Widgets.Indicators { } }
  Component { id: clockComponent; Widgets.Clock { } }
  Component { id: weatherComponent; Widgets.Weather { } }
  Component { id: trayComponent; Widgets.Tray { } }
  Component { id: keyboardComponent; Widgets.KeyboardLayout { } }
  Component { id: bluetoothComponent; Widgets.Bluetooth { } }
  Component { id: networkComponent; Widgets.Network { } }
  Component { id: microphoneComponent; Widgets.Microphone { } }
  Component { id: audioComponent; Widgets.Audio { } }
  Component { id: monitorComponent; Widgets.Monitor { } }
  Component { id: powerComponent; Widgets.Power { } }
  Component { id: emptyModuleComponent; Item { implicitWidth: 0; implicitHeight: 0; visible: false } }

  function barSizeFor(screenName) { return BarModel.barSizeFor({}, screenName, barSize) }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
  }

  function unregisterClickTarget(target) {
    var next = clickTargets.filter(function(item) { return item !== target })
    clickTargets = next
  }

  function registerModuleSlot(slot) {
    if (!slot || moduleSlots.indexOf(slot) !== -1) return
    var next = moduleSlots.slice()
    next.push(slot)
    moduleSlots = next
  }

  function unregisterModuleSlot(slot) {
    var next = moduleSlots.filter(function(item) { return item !== slot })
    moduleSlots = next
  }
  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }
  function targetTooltipHovered(target) {
    return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true
  }

  function clearTooltip() {
    tooltipTimer.stop()
    pendingTooltipTarget = null
    pendingTooltipText = ""
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }
  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  // The section a panel's widget sits in, the center's pieces counted as one,
  // as keyboard switching between panels counts them.
  function popoutSectionOf(owner) {
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.activeItem === owner) return BarModel.navigationRegions(slot.region).join(" ")
    }
    return ""
  }

  // Reported by the open panel. Only a screen name and four numbers are kept,
  // whoever reports them; the section comes from the bar's own layout.
  function notePopoutCard(card) {
    popoutCard = card ? { screen: String(card.screen || ""), section: popoutSectionOf(activePopout),
                          x: Number(card.x) || 0, y: Number(card.y) || 0,
                          width: Number(card.width) || 0, height: Number(card.height) || 0 } : null
  }

  // The last card, copied, for a panel taking over in the same section: one
  // switching across the bar opens fresh instead of flying the card over it.
  function popoutCardFor(owner) {
    var card = popoutCard
    if (!card || !card.section || card.section !== popoutSectionOf(owner)) return null
    return { screen: card.screen, x: card.x, y: card.y, width: card.width, height: card.height }
  }

  function slotWindow(slot) {
    if (!slot) return null
    return targetWindow(slot.activeItem) || targetWindow(slot)
  }

  function slotScreenName(slot) {
    var window = slotWindow(slot)
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  // The output Hyprland has focused, which is where a keyboard-summoned panel
  // belongs. Empty until Hyprland reports one.
  function focusedScreenName() {
    var monitor = Hyprland.focusedMonitor
    return monitor ? String(monitor.name || "") : ""
  }

  // Only widgets that expose popup open/close methods are panels; plain
  // indicators (workspaces, tray) are not.
  function isPanelItem(item) {
    return !!item && typeof item.open === "function" && typeof item.close === "function" && item.opened !== undefined
  }

  // Tab order for the panels in one bar region, with the three center
  // sections taken as one. A screen name scopes it to that monitor's bar.
  function panelNavigationSlots(region, screenName) {
    var records = moduleSlots.filter(function(slot) { return !!slot }).map(function(slot) {
      var item = slot.activeItem
      return { ref: slot, region: slot.region, moduleName: slot.moduleName, screenName: slotScreenName(slot),
               drawn: !!item && item.visible === true && BarModel.isDrawnSlot(slot), panel: isPanelItem(item) }
    })
    return BarModel.panelSlots(BarModel.navigationRegions(region), layoutConfig, records, screenName)
      .map(function(record) { return record.ref })
  }

  // The Nth panel (one-based) of a region on the focused monitor's bar,
  // counting only the panel icons on screen; any bar when Hyprland reports no
  // focused monitor with a bar.
  function panelWidgetIdAt(region, index) {
    var focused = focusedScreenName()
    var hasBar = !!focused && moduleSlots.some(function(slot) { return slotScreenName(slot) === focused })
    var slots = panelNavigationSlots(String(region || ""), hasBar ? focused : "")
    var slot = slots[Math.round(Number(index)) - 1]
    return slot ? String(slot.moduleName || "") : ""
  }

  function switchPanelFrom(owner, direction) {
    if (!owner) return false

    var currentSlot = null
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.activeItem === owner) {
        currentSlot = slot
        break
      }
    }
    if (!currentSlot) return false

    var slots = panelNavigationSlots(currentSlot.region, slotScreenName(currentSlot))
    if (slots.length < 2) return false

    var currentIndex = slots.indexOf(currentSlot)
    if (currentIndex < 0) return false

    var step = direction < 0 ? -1 : 1
    var nextSlot = slots[(currentIndex + step + slots.length) % slots.length]
    if (!nextSlot || !nextSlot.activeItem || nextSlot.activeItem === owner) return false

    nextSlot.activeItem.open()
    return true
  }

  // Every live panel copy of a widget id, one per monitor bar.
  function panelCandidates(pluginId) {
    var id = String(pluginId || "")
    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot.moduleName !== id || !isPanelItem(slot.activeItem)) continue
      candidates.push({ slot: slot, screenName: slotScreenName(slot), opened: slot.activeItem.opened === true })
    }
    return candidates
  }

  // The copy an open request for a widget id (e.g. "omarchy.audio") acts on.
  function findPanelWidget(pluginId) {
    var step = BarModel.panelAction(panelCandidates(pluginId), focusedScreenName(), "open")
    return step ? step.slot.activeItem : null
  }

  // One panel request (open, close or toggle) routed by BarModel.panelAction.
  // Returns "opened", "closed" or "unavailable" when no panel copy exists.
  function requestPanel(pluginId, action) {
    var candidates = panelCandidates(pluginId)
    if (candidates.length === 0) return "unavailable"
    var step = BarModel.panelAction(candidates, focusedScreenName(), action)
    if (!step) return "closed"
    if (step.method === "close") {
      step.slot.activeItem.close()
      return "closed"
    }
    step.slot.activeItem.open()
    return "opened"
  }

  function summonBarWidget(pluginId) {
    return requestPanel(pluginId, "open") === "opened"
  }

  // Toggle the Nth panel of a region on the focused monitor; "unknown" when
  // the region holds no panel at that position.
  function togglePanelAt(region, index) {
    var id = panelWidgetIdAt(region, index)
    return id ? requestPanel(id, "toggle") : "unknown"
  }

  // Panel IPC, declared once for the whole bar (never per bar instance) and
  // routed like the keyboard shortcuts. Targets use plain names.
  IpcHandler {
    target: "bluetooth"
    function open(): string { return root.requestPanel("omarchy.bluetooth", "open") }
    function close(): string { return root.requestPanel("omarchy.bluetooth", "close") }
    function toggle(): string { return root.requestPanel("omarchy.bluetooth", "toggle") }
  }

  IpcHandler {
    target: "network"
    function open(): string { return root.requestPanel("omarchy.network", "open") }
    function close(): string { return root.requestPanel("omarchy.network", "close") }
    function toggle(): string { return root.requestPanel("omarchy.network", "toggle") }
  }

  IpcHandler {
    target: "audio"
    function open(): string { return root.requestPanel("omarchy.audio", "open") }
    function close(): string { return root.requestPanel("omarchy.audio", "close") }
    function toggle(): string { return root.requestPanel("omarchy.audio", "toggle") }
  }

  IpcHandler {
    target: "display"
    function open(): string { return root.requestPanel("omarchy.monitor", "open") }
    function close(): string { return root.requestPanel("omarchy.monitor", "close") }
    function toggle(): string { return root.requestPanel("omarchy.monitor", "toggle") }
  }

  IpcHandler {
    target: "power"
    function open(): string { return root.requestPanel("omarchy.power", "open") }
    function close(): string { return root.requestPanel("omarchy.power", "close") }
    function toggle(): string { return root.requestPanel("omarchy.power", "toggle") }
  }

  IpcHandler {
    target: "clock"
    function open(): string { return root.requestPanel("omarchy.clock", "open") }
    function close(): string { return root.requestPanel("omarchy.clock", "close") }
    function toggle(): string { return root.requestPanel("omarchy.clock", "toggle") }
  }

  IpcHandler {
    target: "weather"
    function open(): string { return root.requestPanel("omarchy.weather", "open") }
    function close(): string { return root.requestPanel("omarchy.weather", "close") }
    function toggle(): string { return root.requestPanel("omarchy.weather", "toggle") }
  }

  function moduleWidgets(moduleName) {
    return moduleSlots.filter(function(slot) {
      return slot && slot.moduleName === moduleName && slot.activeItem
    }).map(function(slot) { return slot.activeItem })
  }

  function setBarHovered(hovered) {
    barHoverCount = Math.max(0, barHoverCount + (hovered ? 1 : -1))
    if (barHoverCount > 0) {
      centerSectionRevealTimer.stop()
      centerSectionRevealHeld = true
    } else {
      centerSectionRevealTimer.restart()
    }
  }

  function setCenterHoverRevealSuppressed(value) {
    centerHoverRevealSuppressed = !!value
  }

  Timer {
    id: centerSectionRevealTimer
    interval: 120
    // A pointer that dips off the bar and straight back leaves the peek open.
    onTriggered: if (!root.barHovered) root.centerSectionRevealHeld = false
  }
  function run(command) {
    if (command) Quickshell.execDetached(["bash", "-lc", command])
  }

  function moduleTargetClickable(target) {
    return target
      && target.visible !== false
      && target.opacity !== 0
      && target.interactive !== false
      && target.pressable !== false
      && target.concealed !== true
      && typeof target.triggerPress === "function"
  }

  function moduleClickTargetAt(slot, localX, localY) {
    for (var i = clickTargets.length - 1; i >= 0; i--) {
      var target = clickTargets[i]
      if (!moduleTargetClickable(target)) continue

      if (Util.itemContainsPoint(target, slot, localX, localY)) {
        return target
      }
    }

    if (moduleTargetClickable(slot.activeItem)) return slot.activeItem
    return null
  }

  function pressModuleClickTarget(slot, button, localX, localY) {
    var target = moduleClickTargetAt(slot, localX, localY)
    if (!target) return false

    target.triggerPress(button)
    return true
  }
  function showTooltip(target, text) {
    clearTooltip()

    if (!targetTooltipHovered(target) || !text) {
      tooltipRequest += 1
      return
    }

    var request = tooltipRequest + 1
    tooltipRequest = request
    pendingTooltipTarget = target
    pendingTooltipText = text

    Qt.callLater(function() {
      if (request !== tooltipRequest) return
      if (!targetTooltipHovered(pendingTooltipTarget)) {
        clearTooltip()
        return
      }
      tooltipTarget = pendingTooltipTarget
      tooltipText = pendingTooltipText
      pendingTooltipTarget = null
      pendingTooltipText = ""
      tooltipTimer.restart()
    })
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return

    tooltipRequest += 1
    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: 400
    onTriggered: {
      if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

  Timer {
    interval: 100
    running: root.tooltipShown
    repeat: true
    onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
  }

  // A visible bar window for surface-bound shell clients (the Stay Awake
  // idle inhibitor); re-evaluated when screens change or a window remaps.
  readonly property var liveWindow: {
    var windows = barPanels.instances
    for (var i = 0; i < windows.length; i++)
      if (windows[i] && windows[i].visible) return windows[i]
    return null
  }

  Variants {
    id: barPanels
    model: Quickshell.screens
    BarPanel {
      required property var modelData
      screen: modelData
    }
  }

  component BarPanel: PanelWindow {
    id: barWindow
    visible: !remapGuard.remapping
    ScreenMoveRemap {
      id: remapGuard
      window: barWindow
    }
    anchors { top: true; left: true; right: true }
    implicitHeight: root.barSize
    exclusionMode: ExclusionMode.Auto
    color: root.background
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "mirroros-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
      anchors.fill: parent
      HoverHandler {
        onHoveredChanged: root.setBarHovered(hovered)
        Component.onDestruction: if (hovered) root.setBarHovered(false)
      }
      CenterSections { anchors.fill: parent }
      ModuleList {
        entries: root.layoutConfig.left
        region: "left"
        fixedEdge: "start"
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
      ModuleList {
        entries: root.layoutConfig.right
        region: "right"
        fixedEdge: "end"
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }
    PopupWindow {
      id: tooltipWindow

      visible: root.tooltipShown && root.tooltipTarget !== null && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
      color: "transparent"
      implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
      implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

      anchor {
        id: tooltipAnchor
        window: barWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
          var target = root.tooltipTarget
          if (!root.targetBelongsToWindow(target, barWindow)) return

          var popupWidth = tooltipWindow.implicitWidth
          var popupHeight = tooltipWindow.implicitHeight
          var localX = target.width / 2 - popupWidth / 2
          var localY = target.height + 6

          if (root.position === "bottom") {
            localY = -popupHeight - 6
          } else if (root.position === "left") {
            localX = target.width + 6
            localY = target.height / 2 - popupHeight / 2
          } else if (root.position === "right") {
            localX = -popupWidth - 6
            localY = target.height / 2 - popupHeight / 2
          }

          var point = barWindow.contentItem.mapFromItem(target, localX, localY)
          tooltipAnchor.rect.x = Math.round(point.x)
          tooltipAnchor.rect.y = Math.round(point.y)
        }
      }

      BorderSurface {
        id: tooltipBubble
        implicitWidth: tooltipLabel.implicitWidth + 20
        implicitHeight: tooltipLabel.implicitHeight + 14
        color: Commons.Color.tooltip.background
        borderSpec: Border.surfaceSpec("tooltip", "border", Commons.Color.tooltip.border, 1)
        radius: Style.cornerRadius

        Text {
          id: tooltipLabel
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: root.tooltipText
          color: Commons.Color.tooltip.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }
  }

  // Center the clock group itself, with adjacent sections hanging off it.
  component CenterSections: Item {
    id: sections
    ModuleList {
      id: beginList
      entries: root.layoutConfig.centerBegin
      region: "centerBegin"
      fixedEdge: "end"
      x: centerBox.x - width
      y: Math.round((sections.height - height) / 2)
    }
    ModuleList {
      entries: root.layoutConfig.centerEnd
      region: "centerEnd"
      fixedEdge: "start"
      x: centerBox.x + centerBox.width
      y: Math.round((sections.height - height) / 2)
    }
    CenterBox {
      id: centerBox
      x: Math.round((sections.width - width) / 2)
      height: sections.height
    }
  }

  component CenterBox: Item {
    id: box
    width: boxList.width
    ModuleList {
      id: boxList
      entries: root.layoutConfig.center
      region: "center"
      fixedEdge: "center"
      firstEdge: "end"
      lastEdge: "start"
      y: Math.round((box.height - height) / 2)
    }
  }

  component ModuleList: Row {
    id: moduleListRoot
    property var entries: []
    property string region: ""
    property string fixedEdge: "center"
    property string firstEdge: ""
    property string lastEdge: ""
    spacing: 0
    Repeater {
      model: moduleListRoot.entries
      ModuleSlot {
        required property var modelData
        required property int index
        entry: modelData
        region: moduleListRoot.region
        fixedEdge: BarModel.slotEdge(moduleListRoot.entries.length, index,
          moduleListRoot.fixedEdge, moduleListRoot.firstEdge, moduleListRoot.lastEdge)
      }
    }
  }

  component ModuleSlot: Item {
    id: slot
    property var entry: null
    property string region: ""
    property string fixedEdge: "center"
    readonly property string moduleName: BarModel.entryId(entry)
    readonly property var activeItem: widgetLoader.item
    readonly property real widgetWidth: activeItem && activeItem.visible ? activeItem.implicitWidth : 0
    readonly property real widgetHeight: activeItem && activeItem.visible ? activeItem.implicitHeight : 0
    readonly property bool panelOpen: root.activePopout === activeItem && activeItem !== null
    readonly property Item panelIndicatorItem: activeItem && "openPanelIndicatorItem" in activeItem ? activeItem.openPanelIndicatorItem : null
    readonly property real panelIndicatorExtent: {
      var mark = panelIndicatorItem
      if (mark) return Math.max(Style.space(10), Math.round(mark.width * 0.55))
      var hint = activeItem && "openPanelIndicatorWidth" in activeItem ? activeItem.openPanelIndicatorWidth : undefined
      if (hint !== undefined && hint !== null && hint > 0) return Math.round(hint)
      return Math.max(Style.space(10), Math.round(slot.widgetWidth * 0.55))
    }
    readonly property real panelIndicatorCenter: {
      var mark = panelIndicatorItem
      if (!mark) return slot.width / 2
      var reveal = "revealProgress" in activeItem ? activeItem.revealProgress : 0
      return mark.mapToItem(slot, mark.width / 2, mark.height / 2).x
    }
    width: widgetWidth
    height: widgetHeight
    implicitWidth: width
    implicitHeight: height
    Component.onCompleted: root.registerModuleSlot(slot)
    Component.onDestruction: root.unregisterModuleSlot(slot)

    Loader {
      id: widgetLoader
      anchors.fill: parent
      sourceComponent: root.widgetComponents[slot.moduleName] || emptyModuleComponent
    }
    Binding { target: slot.activeItem; property: "bar"; value: root; when: !!slot.activeItem && "bar" in slot.activeItem }
    Binding { target: slot.activeItem; property: "moduleName"; value: slot.moduleName; when: !!slot.activeItem && "moduleName" in slot.activeItem }
    Binding { target: slot.activeItem; property: "settings"; value: BarModel.entrySettings(slot.entry, root.widgetOverride(slot.entry)); when: !!slot.activeItem && "settings" in slot.activeItem }
    Binding { target: slot.activeItem; property: "fixedEdge"; value: slot.fixedEdge; when: !!slot.activeItem && "fixedEdge" in slot.activeItem }

    Rectangle {
      readonly property int inset: Style.space(2)
      visible: opacity > 0
      opacity: slot.panelOpen ? 0.9 : 0
      color: Commons.Color.accent
      radius: Math.min(width, height) / 2
      width: slot.panelIndicatorExtent
      height: Style.space(2)
      x: Math.floor(slot.panelIndicatorCenter - width / 2)
      y: parent.height - height - inset
      z: 50
      Behavior on opacity {
        NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
      }
    }
    HoverHandler { id: moduleHover }
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      enabled: slot.widgetWidth > 0 && slot.widgetHeight > 0
      propagateComposedEvents: true
      cursorShape: moduleHover.hovered && root.moduleClickTargetAt(slot, mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: function(mouse) {
        if (!root.pressModuleClickTarget(slot, mouse.button, mouse.x, mouse.y)) mouse.accepted = false
      }
    }
  }
}
