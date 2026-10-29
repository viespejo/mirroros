pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "MenuModel.js" as MenuModel
import "MirrorMenu.js" as MirrorMenu

// Adapted from Omarchy shell/plugins/menu/Menu.qml at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT, Copyright (c) David Heinemeier
// Hansson). Kept: item tree, navigation stack and back navigation, root search
// with the drilldown divider, the native Apps provider, dmenu select/multiple/
// onChange/input modes, card geometry and frozen top, key handling, row
// delegate, scroll scrims and empty state. Removed: JSONC/user-extension and
// language/catalog files, Bash providers, the generated Bash guard batch,
// uninstall and its confirmation dialog, plugin-host lifecycle and Omarchy IPC.
// Changed: the MirrorOS-owned model (MirrorMenu.js); actions come from a closed
// table instead of command text; session availability replaces `when:` guards
// and unavailable rows stay listed with their reason; dmenu results are written
// with fixed argv; native IpcHandler; Brief 1 Apps unavailable state.
//
// Open: qs ipc -p <shell dir> call menu open <root|apps|system|route>
Item {
  id: root

  // Injected by shell.qml.
  property var appLibrary: null
  property var sessionActions: null
  property var keybindingHelp: null
  property var wallpaperActions: null

  // Lifecycle entry points kept from the plugin. open(payloadJson) is reached
  // through the native IPC below instead of `omarchy-shell shell summon`.
  property string pendingInitialMenu: "root"

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }

    if (payload.fontFamily) root.fontFamily = payload.fontFamily

    if (payload.mode === "select" || payload.mode === "input") {
      root.openDmenu(payload)
    } else {
      root.openRoute(payload.initialMenu || payload.menu || "root")
    }
  }

  function close() {
    root.cancel()
  }

  function ping() { return "ok" }

  property string fontFamily: Style.font.menuFamily
  // The owned model, normalized with the upstream item schema.
  property var defaultMenuItems: []
  property bool opened: false
  property string mode: "menu"
  readonly property bool dmenuActive: mode === "select" || mode === "input"
  property string dmenuPrompt: ""
  property var dmenuOptions: []
  property bool dmenuMultiple: false
  property var dmenuSelected: []
  // What the last confirmed change applied; a failed change returns the checks here.
  property var dmenuSaved: []
  property string dmenuChangeKey: ""
  property var dmenuOnChange: []
  property string selectionFile: ""
  property string doneFile: ""
  property int dmenuWidth: 300
  property int dmenuMaxHeight: 0
  // In-process selector requests (keyboard help) get their result through
  // this function instead of the selection/done files.
  property var dmenuHandler: null
  property bool requestActive: false
  property bool rowsLoaded: false
  property string activeMenu: "root"
  property string filterText: ""
  // Resets of filterText reach the search line; its edits come back through setFilter.
  onFilterTextChanged: if (filterInput.text !== filterText) filterInput.text = filterText
  property int selectedIndex: 0
  // Stable identity (row itemId) of the selected row in menu mode; empty until
  // the cursor first settles after open, navigation or a filter change.
  property string selectedId: ""
  property bool cursorActive: false
  property int requestSerial: 0
  property int applySerial: 0
  property var items: ({})
  property var itemOrder: []
  property var navStack: []
  property var providersLoaded: ({})
  property var providerQueue: []
  property int providerRevision: 0

  // Shared application engine (entries, hidden filters, icons, launch).
  readonly property string appsUnavailableReason: root.appLibrary
    ? root.appLibrary.unavailableReason
    : "The application library service is not running."
  readonly property bool appsUnavailableShown: root.appsUnavailableReason !== "" && !root.dmenuActive
    && root.activeMenu === "apps" && !root.filterText
  // Bound to the central [menu] section in shell.toml via Commons.Color.qml.
  // Each color already includes its alpha companion (composed in the
  // singleton), so consumers can drop them straight into a Rectangle.
  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  property color selectedBorder: Commons.Color.menu.selectedBorder
  property var selectedBorderSpec: Border.surfaceSpec("menu", "selected-border", selectedBorder, 0)
  readonly property real rowReservedBorderLeft: Border.left(selectedBorderSpec)
  readonly property real rowReservedBorderRight: Border.right(selectedBorderSpec)
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int baseRowHeight: Math.max(Style.space(50), Style.font.body + Style.spacing.rowPaddingX * 2)
  property int detailRowHeight: Math.max(Style.space(58), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  property int pinnedRowHeight: detailRowHeight + Math.round(Style.font.bodySmall * 1.4)
  // How much of the first hidden row stays visible at the fold — enough to
  // read as a cut-off row rather than a bottom border.
  property int rowPeek: Math.round(baseRowHeight * 0.55)
  property int rowSpacing: Style.spacing.xs
  property int dividerHeight: Style.space(17)
  property bool searchDivider: false
  property int layoutSerial: 0
  property int cardWidth: Math.min(root.dmenuActive ? Style.space(root.dmenuWidth) : Style.space(300), panel.width - Style.gapsOut * 2)
  property int visibleRowsHeight: root.dmenuActive ? dmenuRowListHeight(layoutSerial, displayModel.count, filterText) : rowListHeight(layoutSerial, displayModel.count, filterText, searchDivider)
  property int cardHeight: root.dmenuActive
    ? Math.min(contentMargin * 2 + headerHeight + (mode === "input" ? 0 : contentSpacing + visibleRowsHeight), panel.height - Style.gapsOut * 2)
    : Math.min(contentMargin * 2 + headerHeight + contentSpacing + visibleRowsHeight, panel.height - Style.gapsOut * 2)

  function finishRequest(selection) {
    if (root.dmenuHandler) {
      var handler = root.dmenuHandler
      root.dmenuHandler = null
      root.opened = false
      if (selection !== null && selection !== undefined) handler(String(selection))
      return
    }

    if (!root.requestActive || !root.doneFile) {
      root.opened = false
      return
    }

    var activeSelectionFile = root.selectionFile
    var activeDoneFile = root.doneFile
    root.requestActive = false
    root.selectionFile = ""
    root.doneFile = ""

    // Fixed argv: the script text is constant and the selection and both
    // caller-supplied paths arrive as positional parameters, never re-parsed.
    if (selection === null || selection === undefined) {
      resultProc.enqueue(["bash", "-c", ': > "$1"', "bash", activeDoneFile], root.requestSerial)
    } else {
      resultProc.enqueue(["bash", "-c", 'printf "%s\\n" "$1" > "$2"; : > "$3"', "bash", String(selection), activeSelectionFile, activeDoneFile], root.requestSerial)
    }
  }

  // DEC-027: before a new selector or a regular menu replaces an active
  // selector, complete the old request as cancelled exactly once, with its own
  // done path, without running its selection or closing the new surface. An
  // in-process handler is dropped without being called, as on cancel.
  function cancelPendingRequest() {
    root.dmenuHandler = null
    if (!root.requestActive || !root.doneFile) return
    var replacedDoneFile = root.doneFile
    root.requestActive = false
    root.selectionFile = ""
    root.doneFile = ""
    resultProc.enqueue(["bash", "-c", ': > "$1"', "bash", replacedDoneFile], -1)
  }

  // Actions are ids from MirrorMenu's closed table, never command text.
  function runAction(action) {
    var command = String(action || "")
    if (!MirrorMenu.isKnownAction(command)) return

    if (command === "help:keybindings") {
      root.openKeybindings()
    } else if (command === "wallpaper:open" && root.wallpaperActions) {
      root.wallpaperActions.openPicker(null)
    } else if (command === "wallpaper:install" && root.wallpaperActions) {
      root.wallpaperActions.install()
    } else if (command.indexOf("session:") === 0 && root.sessionActions) {
      root.sessionActions.run(command.substring(8))
    }
  }

  // Keyboard help in the selector, as upstream's Learn > Keybindings does.
  function openKeybindings() {
    var help = root.keybindingHelp
    if (!help) return
    help.load(function() {
      var options = help.error ? ["\t" + "Keyboard help unavailable" + "\t" + help.error] : help.options()
      root.openDmenu({ mode: "select", prompt: "Keybindings", options: options, width: 800, maxHeight: 500 }, function(selection) {
        help.dispatch(help.recordForSelection(selection))
      })
    })
  }

  // Menu rows only surface their detail while a search is narrowing them;
  // dmenu rows carry caller-supplied subtext that must always be visible.
  // Unavailable rows pin their reason, with room for two lines.
  function rowHeightForDetail(detail, pinned) {
    if (pinned && detail) return root.pinnedRowHeight
    return (root.filterText || root.dmenuActive) && detail ? root.detailRowHeight : root.baseRowHeight
  }

  // Height the card can devote to rows before running off the screen — or
  // past the frozen top edge once a search has pinned the card in place.
  // Uses panel.cardTop rather than effectiveCardTop: the centered top is
  // derived from the card height, which this value feeds.
  function availableRowsHeight() {
    var top = panel.cardTop >= 0 ? panel.cardTop : Style.gapsOut
    var available = panel.height - top - Style.gapsOut - root.contentMargin * 2 - root.headerHeight - root.contentSpacing
    // The starting menu sets the ceiling along with the offset: drilling into
    // a longer submenu scrolls behind the fold instead of growing the card.
    if (panel.maxRowsHeight >= 0) available = Math.min(available, panel.maxRowsHeight)
    // A card that swallows the whole screen reads as a page, not a menu.
    return Math.min(available, Math.round(panel.height * 0.7))
  }

  // When every row fits, the list gets its full height. When they don't,
  // the card must end mid-row: a clipped row is what tells the eye there is
  // more below the fold, so never come out even on a row boundary.
  function foldedListHeight(totals, available) {
    var count = totals.length
    if (count === 0) return root.baseRowHeight
    if (totals[count - 1] <= available) return totals[count - 1]

    var peek = root.rowPeek
    var full = 0
    while (full < count && totals[full] <= available) full++
    while (full > 1 && totals[full - 1] + root.rowSpacing + peek > available) full--
    if (full < 1) return Math.max(available, root.baseRowHeight)

    return totals[full - 1] + root.rowSpacing + peek
  }

  function rowListHeight(_serial, _count, _filter, _divider) {
    if (displayModel.count === 0) return root.baseRowHeight

    var totals = []
    var total = 0
    var previousSection = ""

    for (var i = 0; i < displayModel.count; i++) {
      var row = displayModel.get(i)
      if (i > 0) total += root.rowSpacing
      if (row.section === "drilldown" && previousSection !== "drilldown") total += root.dividerHeight
      total += root.rowHeightForDetail(row.detail, row.pinned)
      previousSection = row.section
      totals.push(total)
    }

    return foldedListHeight(totals, availableRowsHeight())
  }

  function dmenuRowListHeight(_serial, _count, _filter) {
    if (root.mode === "input") return 0
    if (displayModel.count === 0) return root.baseRowHeight

    var available = availableRowsHeight()
    if (root.dmenuMaxHeight > 0) available = Math.min(available, Style.space(root.dmenuMaxHeight))

    var totals = []
    var total = 0
    for (var i = 0; i < displayModel.count; i++) {
      if (i > 0) total += root.rowSpacing
      total += root.rowHeightForDetail(displayModel.get(i).detail)
      totals.push(total)
    }

    return foldedListHeight(totals, available)
  }

  function item(id) {
    return root.items[id] || null
  }

  function normalizeItem(id, raw) {
    return MenuModel.normalizeItem(id, raw)
  }

  // The owned model replaces the JSONC files: same normalization and merge as
  // upstream, one source, English labels, no user extension. The merge injects
  // the root row with upstream's English "Go" label.
  function loadModel() {
    var raw = MirrorMenu.rawItems()
    var normalized = []
    for (var i = 0; i < raw.length; i++) normalized.push(root.normalizeItem(raw[i][0], raw[i][1]))
    root.defaultMenuItems = normalized
    root.rebuildItemsFromSources()
  }

  Component.onCompleted: root.loadModel()

  function rebuildItemsFromSources() {
    var mergedMenu = MenuModel.mergeMenuSources(root.defaultMenuItems, [], "Go")
    root.providerRevision += 1
    root.providersLoaded = ({})
    root.providerQueue = []
    root.items = mergedMenu.items
    root.itemOrder = mergedMenu.itemOrder
    root.rowsLoaded = true
    if (root.opened) {
      root.rebuildDisplay()
      if (!root.dmenuActive) {
        if (root.filterText.trim()) root.loadProvidersForSearch()
        else root.loadProviderForMenu(root.activeMenu)
      }
    }
  }

  // Upstream's Bash providers (fonts, power profiles, kernels, languages) are
  // out of scope; only the QML-native "apps" provider remains.
  readonly property var providers: ({})

  function slugify(value) {
    return MenuModel.slugify(value)
  }

  // The apps provider is QML-native: rows come from the shared AppLibrary
  // (DesktopEntries) instead of a bash enumeration, so they carry image
  // icons and launch through AppLibrary (uwsm app).
  function mergeAppRows() {
    if (!root.appLibrary) return

    var rows = root.appLibrary.sortedEntries("")
    var appRows = []
    for (var j = 0; j < rows.length; j++) {
      var entry = rows[j].entry
      var appId = String(entry.id || "")
      if (!appId) continue
      var subtext = root.appLibrary.entrySubtext(entry)
      var aliases = subtext ? [subtext] : []
      try {
        if (entry.keywords && typeof entry.keywords.join === "function") aliases = aliases.concat(entry.keywords)
      } catch (e) { }
      appRows.push({
        id: "apps." + appId,
        parent: "apps",
        kind: "app",
        icon: "",
        appIcon: String(entry.icon || ""),
        appId: appId,
        label: root.appLibrary.entryName(entry),
        title: "",
        target: "",
        description: subtext,
        action: "",
        provider: "",
        aliases: aliases,
        searchTerms: [],
        when: "",
        checked: "",
        disabled: "",
        order: 0
      })
    }

    var merged = MenuModel.mergeAppRows(root.items, root.itemOrder, appRows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened) root.rebuildDisplay()
  }

  function startProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return
    if (entry.provider === "apps") {
      root.providersLoaded[id] = true
      root.mergeAppRows()
      return
    }
  }

  // Entering a submenu is the one moment a volatile list is worth paying for
  // again: it may have been reshaped by the last pick from it. Search doesn't
  // invalidate, or every keystroke would restart the same enumeration.
  function invalidateVolatileProvider(id) {
    var entry = root.item(id)
    var spec = entry && entry.provider ? root.providers[entry.provider] : null
    if (spec && spec.volatile) root.providersLoaded[id] = false
  }

  function loadProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return

    // Native providers don't touch providerProc, so they never need to queue.
    if (entry.provider === "apps") {
      root.startProviderForMenu(id)
      return
    }

    // Upstream queued Bash providers here; none remain.
  }

  function loadProvidersForSearch() {
    var active = root.item(root.activeMenu) ? root.activeMenu : "root"

    for (var i = 0; i < root.itemOrder.length; i++) {
      var entry = root.item(root.itemOrder[i])
      if (!entry || !entry.provider || root.providersLoaded[entry.id]) continue
      if (active !== "root" && entry.id !== active && !root.isDescendantOf(entry.id, active)) continue

      root.loadProviderForMenu(entry.id)
    }
  }

  function depthFor(id) {
    return MenuModel.depthFor(root.items, id)
  }

  function pathFor(id) {
    return MenuModel.pathFor(root.items, id)
  }

  function parentPathFor(id) {
    return MenuModel.parentPathFor(root.items, id)
  }

  function isDescendantOf(id, ancestorId) {
    return MenuModel.isDescendantOf(root.items, id, ancestorId)
  }

  function childCount(id) {
    return MenuModel.childCount(root.items, root.itemOrder, id)
  }

  // Guarded items are hidden when their `when:` evaluates false. Static
  // submenus are also hidden when none of their descendants are visible;
  // provider-backed menus stay visible because their rows load on demand.
  function isVisible(entry) {
    return MenuModel.isVisible(root.items, root.itemOrder, root.whenResults, entry)
  }

  // Label with the ✓ marker baked in when `checked:` or `disabled:` evaluated
  // truthy.
  function labelFor(entry) {
    return MenuModel.labelFor(entry, root.checkedResults, root.disabledResults)
  }

  function searchableToken(value) {
    return MenuModel.searchableToken(value)
  }

  function leafIdFor(id) {
    return MenuModel.leafIdFor(id)
  }

  function nameSearchText(entry) {
    return MenuModel.nameSearchText(entry)
  }

  function termInSearchWords(term, text) {
    return MenuModel.termInSearchWords(term, text)
  }

  function descriptionTextMatches(query, text) {
    return MenuModel.descriptionTextMatches(query, text)
  }

  // Session rows whose provider is not ready stay listed, dimmed and not
  // executable, with this reason always shown. Upstream hides them instead.
  function unavailableReason(entry) {
    var action = String((entry && entry.action) || "")
    if (action.indexOf("session:") !== 0) return ""
    if (!root.sessionActions) return "Session actions are not running."
    var state = root.sessionActions.stateOf(action.substring(8))
    return state.state === "available" ? "" : (state.reason || "Unavailable.")
  }

  // Rows whose `disabled:` evaluated truthy stay listed but dimmed, and the
  // cursor steps over them. Unavailable session rows are disabled too.
  function isDisabled(entry) {
    return MenuModel.isDisabled(root.disabledResults, entry) || root.unavailableReason(entry) !== ""
  }

  // A disabled row earns its place in the submenu it belongs to, where the
  // list around it is the point. Search is a list of what you can do, so it
  // leaves them out. MirrorOS keeps unavailable session rows in search with
  // their reason, so searching "suspend" never comes back empty.
  function matchesQuery(entry, query) {
    return MenuModel.matchesQuery(entry, query, root.isVisible(entry) && !MenuModel.isDisabled(root.disabledResults, entry))
  }

  function searchScore(entry, query) {
    return MenuModel.searchScore(root.items, entry, query)
  }

  function displayRow(entry, detail, score, section) {
    var row = MenuModel.displayRow(root.items, root.itemOrder, root.checkedResults, root.disabledResults, entry, detail, score, section)
    var reason = root.unavailableReason(entry)
    row.pinned = reason !== ""
    if (row.pinned) {
      row.disabled = true
      row.detail = reason
    }
    return row
  }

  function rowSelectable(index) {
    if (index < 0 || index >= displayModel.count) return false
    return !displayModel.get(index).disabled
  }

  // First selectable row at or past `from`, continuing in the direction of
  // travel and wrapping. -1 when every row is disabled, which leaves the menu
  // with no cursor at all rather than one parked on a row Enter won't run.
  function nextSelectable(from, direction) {
    var count = displayModel.count
    if (count === 0) return -1

    var step = direction < 0 ? -1 : 1
    var index = ((from % count) + count) % count
    for (var i = 0; i < count; i++) {
      if (root.rowSelectable(index)) return index
      index = (index + step + count) % count
    }

    return -1
  }

  // Park the cursor on a selectable row after the rows underneath it changed.
  // A menu with nothing selectable in it -- every app in it already installed
  // -- shows no cursor at all, and grows one the moment a row can take it.
  //
  // Once a row is selected the cursor follows its identity, not its index. If
  // that row turned unavailable or left the list, the cursor stays off (Enter
  // runs nothing, even if the row recovers) until the user selects a row.
  function settleCursor() {
    if (root.selectedId === "") {
      var target = root.nextSelectable(root.selectedIndex, 1)
      root.selectedIndex = target >= 0 ? target : 0
      root.cursorActive = target >= 0
      root.selectedId = target >= 0 ? displayModel.get(target).itemId : ""
      return
    }

    var index = root.indexOfItem(root.selectedId)
    if (index < 0) {
      root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, displayModel.count - 1))
      root.cursorActive = false
      return
    }
    root.selectedIndex = index
    if (!root.rowSelectable(index)) root.cursorActive = false
  }

  function indexOfItem(id) {
    for (var i = 0; i < displayModel.count; i++) {
      if (displayModel.get(i).itemId === id) return i
    }
    return -1
  }

  // Enter in menu mode: only the row that was selected, and only while it is
  // still present and selectable.
  function activateSelected() {
    if (!root.cursorActive || root.selectedId === "") return
    var index = root.indexOfItem(root.selectedId)
    if (index >= 0) root.activateIndex(index)
  }

  function rebuildDmenuDisplay() {
    displayModel.clear()
    root.searchDivider = false

    if (root.mode === "input") {
      layoutSerial += 1
      return
    }

    if (root.dmenuMultiple && root.dmenuOnChange.length === 0) {
      displayModel.append({
        itemId: "dmenu.apply", disabled: false, kind: "dmenu", icon: "", iconFont: "",
        appIcon: "", appId: "", label: Commons.I18n.t("common.apply"), target: "",
        detail: Commons.I18n.tn("menu.selectedCount", root.dmenuSelected.length).arg(Commons.I18n.formatNumber(root.dmenuSelected.length)), path: "", childCount: 0,
        action: "", provider: "", score: -1, section: "", pinned: false
      })
    }
    var query = root.filterText.trim().toLowerCase()
    for (var i = 0; i < root.dmenuOptions.length; i++) {
      // An option is "<label>", "<glyph>\t<label>", or
      // "<glyph>\t<label>\t<subtext>". The glyph never comes back with the
      // selection; the subtext renders under the label, filters alongside it,
      // and returns with the selection as a stable key for same-named rows.
      var parts = String(root.dmenuOptions[i] || "").split("\t")
      var icon = parts.length > 1 ? parts.shift() : ""
      var label = parts.shift() || ""
      var detail = parts.join("\t")
      if (query && label.toLowerCase().indexOf(query) < 0
          && detail.toLowerCase().indexOf(query) < 0) continue
      displayModel.append({
        itemId: "dmenu." + i,
        disabled: false,
        kind: "dmenu",
        icon: root.dmenuMultiple ? (root.dmenuSelected.indexOf(MenuModel.dmenuValue(root.dmenuOptions[i])) !== -1 ? "✓" : "○") : icon,
        iconFont: "",
        appIcon: "",
        appId: "",
        label: label,
        target: "",
        detail: detail,
        path: "",
        childCount: 0,
        action: "",
        provider: "",
        score: i,
        section: "",
        pinned: false
      })
    }

    layoutSerial += 1

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) root.revealCursor()
    })
  }

  function updateDmenuChecks() {
    for (var i = 0; i < displayModel.count; i++) {
      var row = displayModel.get(i)
      if (row.itemId === "dmenu.apply") {
        displayModel.setProperty(i, "detail", Commons.I18n.tn("menu.selectedCount", root.dmenuSelected.length).arg(Commons.I18n.formatNumber(root.dmenuSelected.length)))
      } else if (row.kind === "dmenu") {
        var value = MenuModel.dmenuValue(root.dmenuOptions[Number(row.itemId.substring(6))])
        displayModel.setProperty(i, "icon", root.dmenuSelected.indexOf(value) !== -1 ? "✓" : "○")
      }
    }
  }

  function rebuildDisplay() {
    if (root.dmenuActive) {
      root.rebuildDmenuDisplay()
      return
    }

    displayModel.clear()

    if (!root.rowsLoaded) return

    var active = root.item(root.activeMenu) ? root.activeMenu : "root"
    root.activeMenu = active
    var rows = []
    var query = root.filterText.trim()
    root.searchDivider = false

    if (query) {
      var currentRows = []
      var drilldownRows = []

      for (var i = 0; i < root.itemOrder.length; i++) {
        var entry = root.item(root.itemOrder[i])
        if (!entry || entry.id === "root") continue
        if (!root.isDescendantOf(entry.id, active)) continue
        if (!root.matchesQuery(entry, query)) continue

        var detail = root.parentPathFor(entry.id)
        var row = root.displayRow(entry, detail, root.searchScore(entry, query))
        if (entry.parent === active) currentRows.push(row)
        else drilldownRows.push(row)
      }

      var searchSort = function(a, b) {
        if (a.score !== b.score) return a.score - b.score
        return a.path.localeCompare(b.path)
      }

      currentRows.sort(searchSort)
      drilldownRows.sort(searchSort)
      root.searchDivider = currentRows.length > 0 && drilldownRows.length > 0
      if (root.searchDivider) {
        for (var d = 0; d < drilldownRows.length; d++) drilldownRows[d].section = "drilldown"
      }
      rows = currentRows.concat(drilldownRows)
    } else {
      for (var j = 0; j < root.itemOrder.length; j++) {
        var child = root.item(root.itemOrder[j])
        if (!child || child.parent !== active) continue
        if (!root.isVisible(child)) continue
        rows.push(root.displayRow(child, child.description, child.order))
      }

      // DesktopEntries can reorder its values when an application starts.
      // Keep the Apps menu alphabetical independently of provider refreshes.
      if (active === "apps") {
        rows.sort(function(a, b) {
          var aLabel = String(a.label || "").toLowerCase()
          var bLabel = String(b.label || "").toLowerCase()
          if (aLabel < bLabel) return -1
          if (aLabel > bLabel) return 1
          var aId = String(a.itemId || "")
          var bId = String(b.itemId || "")
          if (aId < bId) return -1
          if (aId > bId) return 1
          return 0
        })
      }
    }

    for (var k = 0; k < rows.length; k++) displayModel.append(rows[k])
    layoutSerial += 1

    root.settleCursor()

    Qt.callLater(function() {
      if (displayModel.count > 0) root.revealCursor()
    })
  }

  // Contain alone parks the cursor row flush with the viewport edge, hiding
  // the neighbor entirely and losing the fold affordance. Keep the next
  // hidden row peeking past the cursor in the direction of travel.
  function revealCursor() {
    if (displayModel.count === 0) return
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)

    var item = resultList.itemAtIndex(root.selectedIndex)
    if (!item) return

    var reach = root.rowPeek + root.rowSpacing
    if (root.selectedIndex < displayModel.count - 1) {
      var maxY = Math.max(resultList.originY, resultList.originY + resultList.contentHeight - resultList.height)
      var overhang = item.y + item.height + reach - (resultList.contentY + resultList.height)
      if (overhang > 0) resultList.contentY = Math.min(resultList.contentY + overhang, maxY)
    }
    if (root.selectedIndex > 0) {
      var underhang = resultList.contentY - (item.y - reach)
      if (underhang > 0) resultList.contentY = Math.max(resultList.contentY - underhang, resultList.originY)
    }
  }

  function select(delta) {
    if (displayModel.count === 0) return

    root.disarmPointer()
    var from = cursorActive ? selectedIndex + delta : (delta < 0 ? displayModel.count - 1 : 0)
    var target = root.nextSelectable(from, delta)
    if (target < 0) return

    cursorActive = true
    selectedIndex = target
    selectedId = displayModel.get(target).itemId
    revealCursor()
  }

  function setFilter(nextFilter) {
    panel.freezeCardTop()
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.selectedId = ""
    root.cursorActive = root.mode !== "input"
    root.disarmPointer()
    if (!root.dmenuActive && root.filterText.trim()) root.loadProvidersForSearch()
    root.rebuildDisplay()
  }

  function setActiveMenu(id, pushHistory, fromPointer) {
    panel.freezeCardTop()
    if (!root.item(id)) id = "root"
    if (pushHistory && id !== root.activeMenu) root.navStack = root.navStack.concat([root.activeMenu])
    root.activeMenu = id
    root.filterText = ""
    root.selectedIndex = 0
    root.selectedId = ""
    root.cursorActive = true
    if (fromPointer) pointerGate.allowInitialSample()
    else root.disarmPointer()
    root.rebuildDisplay()
    root.invalidateVolatileProvider(id)
    root.loadProviderForMenu(id)
  }

  function goBack() {
    if (root.activeMenu === "root") return false

    if (root.navStack.length > 0) {
      var previous = root.navStack[root.navStack.length - 1]
      root.navStack = root.navStack.slice(0, root.navStack.length - 1)
      root.setActiveMenu(previous, false)
      return true
    }

    var active = root.item(root.activeMenu)
    root.setActiveMenu((active && active.parent) ? active.parent : "root", false)
    return true
  }

  function activateIndex(index, fromPointer) {
    if (root.dmenuActive) {
      if (root.mode === "input") {
        root.applyDmenuSelection(root.filterText)
        return
      }
      if (index < 0 || index >= displayModel.count) return
      var picked = displayModel.get(index)
      if (root.dmenuMultiple) {
        if (picked.itemId === "dmenu.apply") {
          root.applyDmenuSelection(JSON.stringify(MenuModel.dmenuSelections(root.dmenuOptions, root.dmenuSelected)))
        } else {
          var value = MenuModel.dmenuValue(root.dmenuOptions[Number(picked.itemId.substring(6))])
          var selected = MenuModel.toggleDmenuSelection(selectionProc.requestedSelection(), value)
          if (root.dmenuOnChange.length > 0) {
            selectionProc.enqueue(selected)
          } else {
            root.dmenuSelected = selected
            root.updateDmenuChecks()
          }
        }
      } else {
        root.applyDmenuSelection(picked.detail ? picked.label + "\t" + picked.detail : picked.label)
      }
      return
    }

    if (!root.rowSelectable(index)) return

    var row = displayModel.get(index)
    if (row.kind === "menu" || row.kind === "link") {
      root.setActiveMenu(row.target || row.itemId, true, fromPointer)
    } else if (row.kind === "app") {
      var appId = row.appId
      var label = row.label
      applySerial = requestSerial
      opened = false
      filterText = ""
      if (root.appLibrary) root.appLibrary.launch(appId, label)
    } else {
      root.applySelected(row.itemId, row.action)
    }
  }

  function applyDmenuSelection(value) {
    applySerial = requestSerial
    opened = false
    filterText = ""
    root.finishRequest(value)
  }

  function applySelected(id, action) {
    if (!id) { cancel(); return }

    applySerial = requestSerial
    opened = false
    filterText = ""
    root.runAction(action)
  }

  function cancel() {
    if (root.dmenuActive) root.finishRequest(null)
    opened = false
    filterText = ""
  }

  function openExistingMenu(initialMenu) {
    root.cancelPendingRequest()
    requestSerial += 1
    mode = "menu"
    requestActive = false
    selectionFile = ""
    doneFile = ""
    dmenuHandler = null
    activeMenu = root.item(initialMenu) ? initialMenu : "root"
    navStack = []
    filterText = ""
    selectedIndex = 0
    selectedId = ""
    cursorActive = true
    root.disarmPointer()
    if (root.sessionActions) root.sessionActions.refresh()
    opened = true
    rebuildDisplay()
    invalidateVolatileProvider(activeMenu)
    loadProviderForMenu(activeMenu)
    // The shell may start before first-install packages have finished placing
    // their icons. Refresh here even when the desktop entry list did not change.
    if (root.appLibrary) root.appLibrary.refreshIcons()

    Qt.callLater(function() { filterInput.forceActiveFocus() })
  }

  // `handler`, when given, receives the selection in-process (keyboard help);
  // external requests use the selection/done files as upstream does.
  function openDmenu(payload, handler) {
    root.cancelPendingRequest()
    requestSerial += 1
    dmenuHandler = typeof handler === "function" ? handler : null
    mode = payload.mode === "input" ? "input" : "select"
    dmenuPrompt = String(payload.prompt || (mode === "input" ? Commons.I18n.t("menu.inputPrompt") : Commons.I18n.t("menu.selectPrompt")))
    dmenuOptions = Array.isArray(payload.options) ? payload.options : []
    dmenuMultiple = mode === "select" && payload.multiple === true
    dmenuOnChange = dmenuMultiple && Array.isArray(payload.onChange)
      && payload.onChange.every(function(arg) { return typeof arg === "string" }) ? payload.onChange : []
    dmenuChangeKey = String(payload.changeKey || JSON.stringify(dmenuOnChange))
    dmenuSelected = MenuModel.dmenuSelections(dmenuOptions, Array.isArray(payload.selected) ? payload.selected : [], dmenuOnChange.length > 0)
    dmenuSaved = dmenuSelected
    if (dmenuOnChange.length > 0)
      dmenuSelected = MenuModel.dmenuSelections(dmenuOptions, selectionProc.requestedSelection(), true)
    selectionFile = String(payload.selectionFile || "")
    doneFile = String(payload.doneFile || "")
    requestActive = !!doneFile
    dmenuWidth = Math.max(1, Number(payload.width || 300))
    dmenuMaxHeight = Math.max(0, Number(payload.maxHeight || 0))
    activeMenu = "root"
    navStack = []
    filterText = ""
    selectedIndex = 0
    selectedId = ""
    cursorActive = mode !== "input"
    root.disarmPointer()
    opened = true
    rebuildDisplay()

    Qt.callLater(function() { filterInput.forceActiveFocus() })
  }
  ListModel { id: displayModel }

  // ----------------------------------------------------------- route surface
  //
  // The menu is opened through the native IPC below (`menu open <route>`).
  // Callers may pass a real id (`system`, `apps`) or an alias declared in the
  // model (`power-menu`, `applications`). Unknown strings fall through to the
  // id-as-route behavior so misspellings still attempt to open the literal id.
  function resolveRoute(input) {
    return MenuModel.resolveRoute(root.items, root.itemOrder, input)
  }

  function openRoute(initialMenu) {
    var id = root.resolveRoute(initialMenu)
    var entry = root.items[id]
    // If the resolved id is an action (i.e. the user invoked an alias for
    // a leaf, e.g. `omarchy menu summon screenrecord-stop`), run it directly
    // instead of opening an action with no children.
    if (entry && entry.kind === "action" && entry.action) {
      root.cancel()
      root.runAction(entry.action)
      return "ok"
    }
    // If it's a link (a redirect to another menu), follow the link.
    if (entry && entry.kind === "link" && entry.target) id = entry.target
    root.pendingInitialMenu = id
    root.openExistingMenu(id)
    return "ok"
  }

  function disarmPointer() {
    pointerGate.reset()
  }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    if (!root.rowSelectable(index)) return
    root.cursorActive = true
    root.selectedIndex = index
    root.selectedId = displayModel.get(index).itemId
  }

  Process {
    id: selectionProc
    property int serial: 0
    property string changeKey: ""
    property var selected: []
    property var queue: []
    property string collected: ""

    function requestedSelection() {
      for (var i = queue.length - 1; i >= 0; i--) {
        if (queue[i].key === root.dmenuChangeKey) return queue[i].selected
      }
      if (running && changeKey === root.dmenuChangeKey) return selected
      return root.dmenuSelected
    }

    function enqueue(values) {
      var selected = MenuModel.dmenuSelections(root.dmenuOptions, values, true)
      queue = queue.concat([{
        serial: root.requestSerial, key: root.dmenuChangeKey, selected: selected,
        command: root.dmenuOnChange.concat([JSON.stringify(selected)])
      }])
      if (!running) startNext()
    }

    function startNext() {
      if (queue.length === 0) return
      var change = queue[0]
      queue = queue.slice(1)
      serial = change.serial
      changeKey = change.key
      selected = change.selected
      collected = ""
      command = change.command
      running = true
    }

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: selectionProc.collected = text
    }
    onExited: function(exitCode) {
      if (changeKey === root.dmenuChangeKey && root.dmenuActive && root.dmenuOnChange.length > 0) {
        if (exitCode === 0) {
          var applied = selected
          if (collected.trim()) {
            try { applied = JSON.parse(collected) } catch (error) { applied = root.dmenuSelected }
          }
          if (Array.isArray(applied))
            root.dmenuSelected = MenuModel.dmenuSelections(root.dmenuOptions, applied, true)
          root.dmenuSaved = root.dmenuSelected
        } else {
          root.dmenuSelected = root.dmenuSaved
        }
        root.updateDmenuChecks()
      }
      startNext()
    }
  }

  // Result deliveries run one at a time in arrival order; a delivery is never
  // dropped by restarting a running process.
  Process {
    id: resultProc
    property var queue: []
    property int serial: -1

    function enqueue(command, requestSerial) {
      queue = queue.concat([{ command: command, serial: requestSerial }])
      if (!running) startNext()
    }

    function startNext() {
      if (queue.length === 0) return
      var delivery = queue[0]
      queue = queue.slice(1)
      serial = delivery.serial
      command = delivery.command
      running = true
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("Selector result could not be delivered to the requester")
      if (serial === root.requestSerial && root.applySerial === root.requestSerial)
        root.opened = false
      startNext()
    }
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
  }

  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      if (root.providersLoaded["apps"]) root.mergeAppRows()
    }
  }

  // Upstream fills these from the generated Bash guard batch. The owned model
  // declares no `when:`, `checked:` or `disabled:` expressions, so they stay
  // empty; session availability comes from SessionActions instead.
  property var whenResults: ({})       // id → true|false (allow visibility)
  property var checkedResults: ({})    // id → true|false (show ✓)
  property var disabledResults: ({})   // id → true|false (dim, skip cursor)

  Connections {
    target: root.sessionActions
    function onRevisionChanged() {
      if (root.opened && !root.dmenuActive) root.rebuildDisplay()
    }
  }

  // Native IPC, replacing `omarchy-shell shell summon omarchy.menu <payload>`.
  // Routes are ids ("root", "apps", "system") or aliases ("power-menu").
  IpcHandler {
    target: "menu"

    function open(route: string): string {
      return root.openRoute(route || "root")
    }

    function toggle(route: string): void {
      if (root.opened) root.cancel()
      else root.openRoute(route || "root")
    }

    function close(): void {
      root.cancel()
    }

    function isOpen(): bool {
      return root.opened
    }

    // "ok" when the Apps provider is healthy, otherwise the actionable reason.
    function status(): string {
      return root.appsUnavailableReason === "" ? "ok" : root.appsUnavailableReason
    }

    function keybindings(): void {
      root.openKeybindings()
    }

    // Selector request with upstream's dmenu payload. The return value only
    // says whether the request was ACCEPTED. Completion, cancellation and
    // replacement are visible to the caller only through its doneFile and
    // selectionFile, exactly as upstream.
    function dmenu(payloadJson: string): string {
      var payload = null
      try { payload = JSON.parse(payloadJson) } catch (e) { return "error: payload is not JSON" }
      if (!payload || typeof payload !== "object" || Array.isArray(payload)) return "error: payload must be an object"
      if (payload.mode !== "select" && payload.mode !== "input") return "error: mode must be select or input"
      root.openDmenu(payload)
      return "accepted"
    }

    // Test hooks: the same entry points the keyboard handler uses.
    function setFilter(text: string): void {
      root.setFilter(text)
    }

    function move(delta: int): void {
      root.select(delta)
    }

    function back(): bool {
      return root.goBack()
    }

    // Same branches as Enter in the key handler.
    function activate(): void {
      if (root.dmenuActive) {
        if (root.mode === "input") root.applyDmenuSelection(root.filterText)
        else if (displayModel.count > 0) root.activateIndex(root.cursorActive ? root.selectedIndex : 0)
      } else root.activateSelected()
    }

    function sessionState(): string {
      return JSON.stringify(root.sessionActions ? root.sessionActions.snapshot() : null)
    }

    // JSON snapshot. `labels` stays first for the Brief 1 launcher checks.
    function state(): string {
      var labels = []
      var rows = []
      for (var i = 0; i < displayModel.count; i++) {
        var row = displayModel.get(i)
        labels.push(row.label)
        rows.push({ label: row.label, detail: row.detail, kind: row.kind, disabled: row.disabled, pinned: !!row.pinned, section: row.section, icon: row.icon })
      }
      return JSON.stringify({
        labels: labels,
        opened: root.opened,
        mode: root.mode,
        menu: root.activeMenu,
        depth: root.navStack.length,
        filter: root.filterText,
        input: filterInput.text,
        selected: root.cursorActive ? root.selectedIndex : -1,
        selectedId: root.cursorActive ? root.selectedId : "",
        prompt: root.dmenuPrompt,
        requestActive: root.requestActive,
        dmenuSelected: root.dmenuSelected,
        rows: rows
      })
    }
  }
  OverlayWindow {
    id: panel
    shown: root.opened && root.rowsLoaded
    WlrLayershell.namespace: "mirroros-menu"

    // The card opens centered exactly as always. The first search keystroke
    // or submenu move freezes the top line where it currently sits — from
    // then on the card grows and shrinks downward instead of re-centering
    // on every resize, which made the menu jump around. MirrorOS deviation:
    // upstream also freezes maxRowsHeight here, capping the card at the
    // starting menu's rows; with the three-row MirrorOS root that clipped
    // System and Apps, so only the top is frozen and the card may grow down
    // to the screen edge. Closing or changing screens unfreezes the top.
    property int cardTop: -1
    property int maxRowsHeight: -1
    readonly property int centeredTop: Math.max(Style.gapsOut, Math.round((height - root.cardHeight) / 2))
    readonly property int effectiveCardTop: cardTop >= 0 ? cardTop : centeredTop
    function freezeCardTop() {
      if (shown && cardTop < 0) {
        cardTop = effectiveCardTop
      }
    }
    onShownChanged: if (!shown) { cardTop = -1; maxRowsHeight = -1 }
    onTargetScreenChanged: { cardTop = -1; maxRowsHeight = -1 }

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.cancel()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: Math.min(root.cardHeight, panel.height - Style.gapsOut - panel.effectiveCardTop)
      radius: root.cornerRadius
      anchors.horizontalCenter: parent.horizontalCenter
      y: panel.effectiveCardTop
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent

        // Focus is on filterInput, which forwards every key here first.
        // Upstream's Delete (uninstall) branch is not carried over.
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.cancel()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if ((event.key === Qt.Key_Backspace || Util.readingKey(event) === Qt.Key_Left) && !root.filterText) {
            root.goBack()
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.select(-6)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.select(6)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || Util.readingKey(event) === Qt.Key_Right) {
            if (root.dmenuActive) {
              if (root.mode === "input") root.applyDmenuSelection(root.filterText)
              else if (displayModel.count > 0) root.activateIndex(root.cursorActive ? root.selectedIndex : 0)
            } else if (root.cursorActive) root.activateSelected()
            else root.settleCursor()
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: "transparent"

          FilterInput {
            id: filterInput
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            keyHandler: keyCatcher
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            onTextChanged: if (text !== root.filterText) root.setFilter(text)
          }

          Text {
            textFormat: Text.PlainText
            anchors.fill: filterInput
            verticalAlignment: Text.AlignVCenter
            visible: !root.filterText && !filterInput.preeditText
            text: root.dmenuActive ? (root.dmenuPrompt + "…") : ((root.item(root.activeMenu) ? (root.item(root.activeMenu).title || root.item(root.activeMenu).label) : "Go") + "…")
            color: root.foreground
            opacity: 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

        }

        Item {
          width: parent.width
          height: root.visibleRowsHeight

          ListView {
            id: resultList
            anchors.fill: parent
            model: displayModel
            clip: true
            spacing: root.rowSpacing
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
              target: null
              onWheel: function(event) {
                var delta = event.pixelDelta.y || event.angleDelta.y / 120 * root.rowHeightForDetail("") * 3
                var bottom = resultList.originY + Math.max(0, resultList.contentHeight - resultList.height)
                resultList.contentY = Math.max(resultList.originY, Math.min(bottom, resultList.contentY - delta))
                event.accepted = true
              }
            }

            section.property: "section"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
              required property string section

              width: ListView.view.width
              height: section === "drilldown" ? root.dividerHeight : 0
              visible: section === "drilldown"

              Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(4)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.spacing.hairline
                color: Util.alpha(root.foreground, 0.2)
              }
            }

            delegate: BorderSurface {
              id: row
              required property int index
              required property string itemId
              required property string kind
              required property string icon
              required property string iconFont
              required property string appIcon
              required property string appId
              required property string label
              required property string target
              required property string detail
              required property string path
              required property string action
              required property int childCount
              required property bool disabled
              required property bool pinned

              readonly property bool hasCursor: root.cursorActive && row.index === root.selectedIndex
              readonly property bool isApp: row.kind === "app"
              readonly property bool hasIcon: row.icon.length > 0 || row.isApp

              width: ListView.view.width
              height: root.rowHeightForDetail(row.detail, row.pinned)
              // Faded: the row is here to say the software is already
              // installed, not to be picked.
              opacity: row.disabled ? 0.4 : 1
              radius: root.cornerRadius
              color: row.hasCursor ? root.selectedBackground : "transparent"
              borderSpec: row.hasCursor ? root.selectedBorderSpec : Border.none()

              Rectangle {
                visible: false
                width: Style.space(4)
                height: parent.height - Style.space(18)
                radius: Math.min(root.cornerRadius, Style.space(4))
                color: root.selectedBackground
                anchors.left: parent.left
                anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: iconText
                textFormat: Text.PlainText
                visible: row.hasIcon && !row.isApp
                text: row.icon
                color: row.hasCursor ? root.selectedText : root.foreground
                font.family: row.iconFont.length > 0 ? row.iconFont : root.fontFamily
                font.pixelSize: Style.font.iconLarge
                width: Style.space(36)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.left: parent.left
                anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8)
                y: contentColumn.y + labelText.y + (labelText.height - height) / 2
              }

              Image {
                id: appIconImage
                visible: row.isApp
                width: Style.font.iconLarge
                height: Style.font.iconLarge
                fillMode: Image.PreserveAspectFit
                // Decode at physical pixels — a logical-size decode leaves
                // PNG icons upscaled and blurry on HiDPI displays.
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
                source: row.isApp && root.appLibrary ? root.appLibrary.iconSource(row.appIcon) : ""
                asynchronous: true
                anchors.left: parent.left
                anchors.leftMargin: root.rowReservedBorderLeft + Style.space(8) + (Style.space(36) - width) / 2
                y: contentColumn.y + labelText.y + (labelText.height - height) / 2
              }

              Column {
                id: contentColumn
                anchors.left: row.hasIcon ? iconText.right : parent.left
                anchors.leftMargin: row.hasIcon ? Style.space(6) : root.rowReservedBorderLeft + Style.space(18)
                anchors.right: trail.left
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  id: labelText
                  textFormat: Text.PlainText
                  width: parent.width
                  text: row.label
                  color: row.hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.heading
                  font.weight: Font.Medium
                  elide: Text.ElideRight
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  // A parent path's separator points along the reading direction.
                  text: Commons.I18n.rightToLeft && row.kind !== "dmenu" ? row.detail.replace(/ › /g, " ‹ ") : row.detail
                  visible: (root.filterText || row.kind === "dmenu" || row.pinned) && row.detail.length > 0
                  color: root.foreground
                  opacity: 0.52
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  // An unavailable row's reason wraps to a second line.
                  wrapMode: row.pinned ? Text.Wrap : Text.NoWrap
                  maximumLineCount: row.pinned ? 2 : 1
                  elide: Text.ElideRight
                }
              }

              Row {
                id: trail
                width: Style.space(14)
                anchors.right: parent.right
                anchors.rightMargin: root.rowReservedBorderRight + Style.space(8)
                y: contentColumn.y + labelText.y + (labelText.height - height) / 2
                spacing: 0

                Text {
                  textFormat: Text.PlainText
                  visible: false
                  text: row.childCount
                  color: root.foreground
                  opacity: 0.45
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  textFormat: Text.PlainText
                  text: row.kind === "menu" || row.kind === "link" ? (Commons.I18n.rightToLeft ? "‹" : "›") : ""
                  color: row.hasCursor ? root.selectedText : root.foreground
                  opacity: row.kind === "menu" || row.kind === "link" ? 0.36 : 0
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.heading
                  font.weight: Font.Normal
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: row.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                onEntered: root.selectFromPointer(row.index, row, {
                  x: mouseArea.mouseX,
                  y: mouseArea.mouseY
                })
                onPositionChanged: function(mouse) {
                  root.selectFromPointer(row.index, row, mouse)
                }
                onClicked: {
                  if (row.disabled) return
                  root.cursorActive = true
                  root.selectedIndex = row.index
                  root.selectedId = row.itemId
                  root.activateIndex(row.index, true)
                }
              }
            }
          }

          // Scroll scrims. The clipped row already marks the fold at rest;
          // these keep both edges honest once the list has been scrolled,
          // when content hides above the card top as well as below. Strength
          // tracks the distance still hidden past each edge rather than
          // animating on a clock, so a programmatic jump — wrapping from the
          // last row back to the first — lands with the fade already applied.
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.min(Style.space(28), parent.height / 2)
            visible: opacity > 0
            opacity: resultList.contentHeight > resultList.height
              ? Math.max(0, Math.min(1, (resultList.contentY - resultList.originY) / height))
              : 0
            gradient: Gradient {
              GradientStop { position: 0; color: root.background }
              GradientStop { position: 1; color: Util.alpha(root.background, 0) }
            }
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(Style.space(28), parent.height / 2)
            visible: opacity > 0
            opacity: resultList.contentHeight > resultList.height
              ? Math.max(0, Math.min(1, (resultList.originY + resultList.contentHeight - resultList.height - resultList.contentY) / height))
              : 0
            gradient: Gradient {
              GradientStop { position: 0; color: Util.alpha(root.background, 0) }
              GradientStop { position: 1; color: root.background }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: displayModel.count === 0 && root.mode !== "input"

            Text {
              text: "󰈉"
              color: root.selectedText
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: Style.space(320)
            }

            Text {
              textFormat: Text.PlainText
              text: root.appsUnavailableShown
                ? "Applications unavailable"
                : (root.filterText ? Commons.I18n.t("common.noMatchesFor").arg(root.filterText) : Commons.I18n.t("menu.nothingHere"))
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              width: Style.space(320)
            }

            // Brief 1 launcher: an empty Apps menu says why and what to do.
            Text {
              textFormat: Text.PlainText
              visible: root.appsUnavailableShown
              text: root.appsUnavailableReason
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              width: Style.space(260)
            }
          }
        }

        Item {
          width: parent.width
          height: 0
        }
      }
    }
  }
}
