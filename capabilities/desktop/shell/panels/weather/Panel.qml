import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "Locations.js" as Locations

// Adapted from Omarchy shell/plugins/panels/weather/Panel.qml at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David
// Heinemeier Hansson); the compact location rows, their hover-only circular
// "×" and the bordered add button follow the design of Elsewhen's
// shell/plugins/panels/elsewhen/CityRow.qml and CitySearch.qml at v4.5.0
// (MIT, Jason Fried). Changes (ADR 0029): open-meteo is the only provider
// (no wttr.in, weather.json, geo.omarchy.org lookup or
// omarchy-weather-location); several saved locations, one active, stored per
// widget under bar.widgets["omarchy.weather"] through updateEntryInline; the
// hero reports the active location and the other locations follow as compact
// rows without local time or daylight strip; a fixed 30-minute schedule
// (active location only while closed, every location in one combined request
// on open), paused while the session is locked and refreshed on unlock; a
// failed request keeps the previous values and is not retried; panel IPC
// lives in the bar (no ShellIpc, edit IPC or refreshMinutes setting); empty
// "No location" hero with the search focused. Unit choice keeps the `unit`
// setting, otherwise the locale (no reported country without wttr.in).
Panel {
  id: root
  moduleName: "omarchy.weather"
  ipcTarget: "omarchy.weather"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false

  // The bar tracks the widget mounted in its slot — bar/widgets/Weather.qml —
  // not this nested panel. Everything the bar identifies a panel by has to be
  // that widget: the popout coordinator (and with it the open-panel dot under
  // the pill) compares against `slot.activeItem`, and switchPanelFrom looks
  // the slot up the same way.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    root.afterOpen()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    root.afterOpen()
    // Set after showing, not before: showing hands the popout coordinator
    // over, which closes whichever panel was open, and that close clears the
    // shared flag. Deferring means the panel taking over always wins, while
    // a handoff to a panel that does not manage the flag still leaves it
    // cleared rather than stuck on.
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  // Opening refreshes every location at once; with none saved the search is
  // ready instead.
  function afterOpen() {
    root.focusIndex = -1
    root.refresh("open")
    if (!root.hasLocation) root.startEditingLocation("replace")
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    if (root.editingLocation) root.cancelEditingLocation()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // ---- Saved locations: { locations: [{ name, latitude, longitude }], active }.
  readonly property var locationState: Locations.normalize(root.settings)
  readonly property bool hasLocation: Locations.hasLocation(locationState)
  readonly property var activeLocation: Locations.activeLocation(locationState)
  readonly property var otherLocations: Locations.others(locationState)
  readonly property string activeKey: reportKey(activeLocation)

  // Last good open-meteo report per location, keyed by its coordinates. Kept
  // on failure so stale data stays visible.
  property var reports: ({})

  function reportKey(location) {
    return location ? location.latitude + "," + location.longitude : ""
  }

  function reportFor(location) {
    var key = reportKey(location)
    return key !== "" && reports[key] ? reports[key] : null
  }

  // Session lock, from the notification service that hypridle's lockChanged
  // IPC updates. hypridle locks before sleep, so unlocking is also the resume.
  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property bool lockedNow: !!(notificationService && notificationService.lockedNow)
  property bool wasLocked: false
  onLockedNowChanged: {
    var resumed = Locations.unlocked(wasLocked, lockedNow)
    wasLocked = lockedNow
    if (resumed) refresh("unlock")
  }

  // A new or changed active location is fetched right away.
  onActiveKeyChanged: if (activeKey !== "") Qt.callLater(root.refreshAfterChange)

  // Click-to-edit state. "replace" edits the active record from the pinned
  // name; "add" appends a record from the "+ Add location" button.
  property bool editingLocation: false
  property string editMode: "replace"
  property var locationSuggestions: []
  property int suggestionIndex: 0
  property string geocodePendingQuery: ""
  property string geocodeActiveQuery: ""

  // Keyboard focus over the hero (-1), the other rows and "+ Add location"
  // (Locations.moveFocus).
  property int focusIndex: -1
  onOtherLocationsChanged: focusIndex = Locations.clampFocus(focusIndex, otherLocations.length)

  // A request asked for while another runs; the widest one waits.
  property string pendingReason: ""
  property var inFlight: []

  readonly property var dailyForecastReport: reportFor(activeLocation)
  readonly property var current: Model.openMeteoCurrentCondition(dailyForecastReport)
  readonly property var forecastDays: Model.openMeteoForecastDays(dailyForecastReport, Qt.formatDate(new Date(), "yyyy-MM-dd"))

  readonly property bool useImperial: Model.shouldUseImperial(setting("unit", ""), Qt.locale().name, "")

  // Shared hero/bar icon: the neutral glyph until the active location reports.
  readonly property string label: (hasLocation && current) ? (Model.currentIcon(current, "") || Model.NEUTRAL_ICON) : Model.NEUTRAL_ICON

  readonly property string reportLocation:  activeLocation ? activeLocation.name : "No location"
  readonly property string reportTempNum:   current ? displayNumber(useImperial ? current.temp_F : current.temp_C) : ""
  readonly property string tempUnit:        "°" + (useImperial ? "F" : "C")
  readonly property string reportFeels:     current ? formatTemp(useImperial ? current.FeelsLikeF : current.FeelsLikeC) : ""
  readonly property string reportWind:      current ? (useImperial ? (displayNumber(current.windspeedMiles) + " mph") : (displayNumber(current.windspeedKmph) + " km/h")) : ""
  readonly property string reportHumidity:  current ? (displayNumber(current.humidity) + "%") : ""

  // The report's numbers arrive as strings ("13"), and blank when missing.
  function displayNumber(value) {
    if (value === undefined || value === null || value === "") return ""
    return Commons.I18n.formatNumber(value)
  }

  // reason: "timer", "open", "unlock" or "change" (see Locations.fetchScope).
  function refresh(reason) {
    var scope = Locations.fetchScope(locationState, root.opened, root.lockedNow, reason)
    if (scope === "none") return
    if (forecastProc.running) {
      if (pendingReason !== "open") pendingReason = reason
      return
    }
    var list = Locations.fetchLocations(locationState, scope)
    var command = Model.forecastCommand(list)
    if (command.length === 0) return
    inFlight = list
    forecastProc.command = command
    forecastProc.running = true
  }

  function refreshAfterChange() {
    root.refresh("change")
  }

  function applyReports(text) {
    var parsed = Model.parseForecastReports(text, inFlight.length)
    // A failed or unreadable answer keeps the previous values; the next
    // scheduled refresh tries again.
    if (!parsed) return
    var next = {}
    for (var key in reports) next[key] = reports[key]
    for (var i = 0; i < parsed.length; i++) next[reportKey(inFlight[i])] = parsed[i]
    reports = next
  }

  // ---- Location editing. Clicking the pinned name swaps it for a search
  //      field that replaces the active record; "+ Add location" opens one
  //      that appends. Picking a geocoded suggestion persists name and
  //      coordinates to the widget's shell.json entry.
  // The search fields live in the panel's lazily built content.
  function locationInput() {
    if (!panel.loadedContent) return null
    return editMode === "add" ? panel.loadedContent.addField : panel.loadedContent.locationField
  }

  function startEditingLocation(mode) {
    editMode = mode === "add" && hasLocation ? "add" : "replace"
    editingLocation = true
    locationSuggestions = []
    suggestionIndex = 0
    Qt.callLater(function() {
      var locationField = root.locationInput()
      if (!locationField) return
      locationField.text = root.editMode === "replace" && root.activeLocation ? root.activeLocation.name : ""
      locationField.selectAll()
      locationField.forceActiveFocus()
    })
  }

  function cancelEditingLocation() {
    editingLocation = false
    locationSuggestions = []
    geocodeDebounce.stop()
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  }

  // Only a geocoded suggestion carries coordinates; a bare typed name is
  // not saved.
  function commitLocation() {
    var locationField = root.locationInput()
    if (!locationField) return
    pickSuggestion(Model.locationCommit(locationField.text, locationSuggestions, suggestionIndex))
  }

  function pickSuggestion(suggestion) {
    var record = Locations.location(suggestion)
    if (!record) return
    var adding = editMode === "add"
    persistLocations(adding ? Locations.add(locationState, record) : Locations.replaceActive(locationState, record))
    cancelEditingLocation()
    // A new non-active row is fetched with the others while the panel is open.
    if (adding) Qt.callLater(root.refreshAfterChange)
  }

  function activateLocation(index) {
    persistLocations(Locations.activate(locationState, index))
  }

  function removeLocation(index) {
    if (!Locations.canRemove(locationState, index)) return
    persistLocations(Locations.remove(locationState, index))
  }

  // Elsewhen's list keys: up and down walk the hero, the other rows and
  // "+ Add location"; Return or Space acts on the focus (the hero opens its
  // search, as Return did upstream); x or Delete removes a removable row.
  function moveFocus(step) {
    focusIndex = Locations.moveFocus(focusIndex, step, otherLocations.length)
  }

  function activateFocused() {
    if (focusIndex < 0) {
      startEditingLocation("replace")
    } else if (focusIndex >= otherLocations.length) {
      startEditingLocation("add")
    } else {
      var index = otherLocations[focusIndex].index
      focusIndex = -1
      activateLocation(index)
    }
  }

  function removeFocused() {
    if (focusIndex < 0 || focusIndex >= otherLocations.length) return
    var at = focusIndex
    var index = otherLocations[at].index
    if (!Locations.canRemove(locationState, index)) return
    removeLocation(index)
    focusIndex = otherLocations.length > 0 ? Math.min(at, otherLocations.length - 1) : -1
  }

  // Applied locally first so the panel redraws on the click itself; the
  // shell.json write comes back through the bar as the same value. The host
  // widget is kept in step, since it injects its settings into this panel.
  function persistLocations(state) {
    var values = Locations.toSettings(state)
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // Debounced geocoding. Only one curl runs at a time; if the query moved on
  // while a fetch was in flight, the latest query is fetched right after.
  function requestGeocode() {
    var locationField = root.locationInput()
    var query = locationField ? locationField.text.trim() : ""
    if (!root.opened || !root.editingLocation || query.length < 2) {
      locationSuggestions = []
      return
    }
    geocodePendingQuery = query
    if (!geocodeProc.running) startGeocode()
  }

  function startGeocode() {
    if (!root.opened || !root.editingLocation) return
    geocodeActiveQuery = geocodePendingQuery
    geocodeProc.command = Model.geocodingCommand(geocodeActiveQuery)
    geocodeProc.running = true
  }

  function formatTemp(value) {
    return Model.formatTemp(value, useImperial, Commons.I18n.formatNumber)
  }

  function rowTemp(location) {
    var cur = Model.openMeteoCurrentCondition(reportFor(location))
    return cur ? formatTemp(useImperial ? cur.temp_F : cur.temp_C) : ""
  }

  function rowIcon(location) {
    return Model.currentIcon(Model.openMeteoCurrentCondition(reportFor(location)), "")
  }

  function dayName(dateString) {
    var locale = Qt.locale(Commons.I18n.formatLocale)
    return Model.dayName(dateString, function(date) { return locale.standaloneDayName(date.getDay(), Locale.LongFormat) })
  }

  // Bare degree value (no unit letter), used in the forecast row.
  function bareTempForDay(day, kind) {
    return Model.bareTempForDay(day, kind, useImperial, Commons.I18n.formatNumber)
  }

  function dayIcon(day) {
    return Model.dayIcon(day)
  }

  // Elsewhen's row fill: the popup background tinted towards the foreground.
  function mix(base, tint, amount) {
    return Qt.rgba(base.r + (tint.r - base.r) * amount, base.g + (tint.g - base.g) * amount,
      base.b + (tint.b - base.b) * amount, base.a + (tint.a - base.a) * amount)
  }

  Process {
    id: forecastProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyReports(text)
    }
    onExited: {
      if (root.pendingReason === "") return
      var reason = root.pendingReason
      root.pendingReason = ""
      Qt.callLater(function() { root.refresh(reason) })
    }
  }

  Process {
    id: geocodeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.locationSuggestions = root.editingLocation ? Model.parseGeocodingResults(text) : []
        root.suggestionIndex = 0
        if (root.geocodePendingQuery !== root.geocodeActiveQuery) Qt.callLater(root.startGeocode)
      }
    }
  }

  Timer {
    id: geocodeDebounce
    interval: 300
    onTriggered: root.requestGeocode()
  }

  // Runs only with a saved location; the first fetch comes from the active
  // location appearing (onActiveKeyChanged).
  Timer {
    id: refreshTimer
    interval: Locations.REFRESH_MS
    running: root.hasLocation
    repeat: true
    onTriggered: root.refresh("timer")
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    // Anchor under the widget rather than the middle of the bar, so the
    // popup follows wherever the widget is placed.
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      property alias locationField: locationField
      property alias addField: addField
      implicitHeight: weatherColumn.implicitHeight
      anchors.fill: parent
      blocked: root.editingLocation
      // Return arrives as an activate too, so it is handled there once.
      onActivateRequested: root.activateFocused()
      onDeleteRequested: root.removeFocused()
      onMoveRequested: function(dx, dy) {
        if (dy === 0) return
        root.moveFocus(dy)
        keyCatcher.showFocus()
      }
      onTextKey: function(text, modifiers) {
        if (text === "a" || text === "+") root.startEditingLocation("add")
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      // Scrolls the focused row or button into view; the hero scrolls to the top.
      function showFocus() {
        var item = root.focusIndex < 0 ? null
          : root.focusIndex >= root.otherLocations.length ? addButton : locationRows.itemAt(root.focusIndex)
        if (!item) { weatherScroll.contentY = 0; return }
        var top = item.mapToItem(weatherColumn, 0, 0).y
        if (top < weatherScroll.contentY) weatherScroll.contentY = top
        else if (top + item.height > weatherScroll.contentY + weatherScroll.height)
          weatherScroll.contentY = top + item.height - weatherScroll.height
      }

      Flickable {
        id: weatherScroll
        anchors.fill: parent
        // As in Elsewhen: room for the rows' circular "×" to straddle their
        // top-right corners without being clipped.
        anchors.rightMargin: -Style.space(12)
        contentWidth: width
        contentHeight: weatherColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: weatherColumn
          width: weatherScroll.width - Style.space(12)
          spacing: Style.space(14)

      // ---- Hero row: big icon + temp on the left; location and stats stacked on the right.
      Item {
        width: parent.width
        height: Math.max(heroLeft.height, heroRight.height)

        Row {
          id: heroLeft
          anchors.left: parent.left
          anchors.leftMargin: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(16)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 5
            text: root.label || "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            // Decorative condition emoji; intentionally larger than the
            // Style.font.* scale's displayLarge (28).
            font.pixelSize: 64
          }

          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            // A reading and its unit ("13 °C") stay in that order in a
            // right-to-left layout too, the way bidi text keeps them.
            LayoutMirroring.enabled: false

            Text {
              id: tempBig
              textFormat: Text.PlainText
              text: root.reportTempNum || "—"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              // Hero temperature read-out; deliberately oversized, outside
              // the Style.font.* scale.
              font.pixelSize: 56
              font.bold: true
            }
            Text {
              textFormat: Text.PlainText
              text: root.current ? root.tempUnit : ""
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
              anchors.top: tempBig.top
              anchors.topMargin: Style.space(10)
            }
          }
        }

        Column {
          id: heroRight
          width: weatherStats.implicitWidth
          anchors.right: parent.right
          anchors.rightMargin: Style.space(20)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(12)

          Row {
            visible: !(root.editingLocation && root.editMode === "replace")
            spacing: Style.space(6)

            TapHandler {
              onTapped: root.startEditingLocation("replace")
            }
            HoverHandler {
              cursorShape: Qt.PointingHandCursor
            }

            Text {
              text: "\uf041"  // nf-fa-map_marker
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              textFormat: Text.PlainText
              text: (root.reportLocation || "").toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              font.letterSpacing: 1
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Row {
            visible: root.editingLocation && root.editMode === "replace"
            spacing: Style.space(6)

            TextField {
              id: locationField
              width: Style.space(190)
              placeholderText: Commons.I18n.t("weather.searchCity")
              foreground: root.bar.foreground
              font.family: root.bar.fontFamily

              onTextChanged: if (root.editingLocation && root.editMode === "replace") geocodeDebounce.restart()

              Keys.onPressed: function(event) { root.handleSearchKey(event) }
            }

            // Leaves the search without changing anything.
            Rectangle {
              width: Style.space(18)
              height: Style.space(18)
              anchors.verticalCenter: parent.verticalCenter
              radius: Math.min(4, Style.cornerRadius)
              color: cancelLocationArea.containsMouse ? Style.hoverFillFor(root.bar.foreground, Commons.Color.accent) : "transparent"

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: "✕"
                font.family: root.bar.fontFamily
                color: Qt.darker(root.bar.foreground, 1.4)
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: cancelLocationArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cancelEditingLocation()
              }
            }
          }

          Row {
            id: weatherStats
            visible: !!root.current
            spacing: Style.space(36)

            Column {
              spacing: Style.space(5)
              Text {
                text: Commons.I18n.t("weather.feels")
                textFormat: Text.PlainText
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }
              Text {
                textFormat: Text.PlainText
                text: root.reportFeels
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
              }
            }

            Column {
              spacing: Style.space(5)
              Text {
                text: Commons.I18n.t("weather.wind")
                textFormat: Text.PlainText
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }
              Text {
                textFormat: Text.PlainText
                text: root.reportWind
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
              }
            }

            Column {
              spacing: Style.space(5)
              Text {
                text: Commons.I18n.t("weather.humid")
                textFormat: Text.PlainText
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }
              Text {
                textFormat: Text.PlainText
                text: root.reportHumidity
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
              }
            }
          }
        }
      }

      // ---- Geocoding suggestions while the active location is being edited.
      Suggestions {
        host: root
        visible: root.editingLocation && root.editMode === "replace" && root.locationSuggestions.length > 0
      }

      Text {
        visible: root.hasLocation && !root.current
        text: Commons.I18n.t("weather.fetching")
        textFormat: Text.PlainText
        color: Qt.darker(root.bar.foreground, 1.5)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.italic: true
      }

      // ---- Divider between current conditions and forecast.
      Rectangle {
        visible: root.forecastDays.length > 0
        width: parent.width
        height: Style.spacing.hairline
        color: root.bar.foreground
        opacity: 0.12
      }

      // ---- Forecast row: each cell has the day icon left of a day-name + hi/lo column.
      //      Wrapped in an Item so the block of cells can be centered within the popup.
      Item {
        visible: root.forecastDays.length > 0
        width: parent.width
        height: forecastRow.height

        Row {
          id: forecastRow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(44)

          Repeater {
            model: root.forecastDays

            Row {
              required property var modelData
              required property int index
              spacing: Style.space(10)

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: root.dayIcon(modelData)
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.display
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  textFormat: Text.PlainText
                  text: root.dayName(modelData.date).toUpperCase()
                  color: Qt.darker(root.bar.foreground, 1.4)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1
                }

                Row {
                  spacing: Style.space(6)

                  Text {
                    textFormat: Text.PlainText
                    text: root.bareTempForDay(modelData, "max")
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: root.bareTempForDay(modelData, "min")
                    color: Qt.darker(root.bar.foreground, 1.5)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                  }
                }
              }
            }
          }
        }
      }

      // ---- Saved-locations section, introduced like the other panels' sections.
      PanelSeparator {
        visible: root.hasLocation
        foreground: root.bar.foreground
      }

      PanelSectionHeader {
        visible: root.hasLocation
        text: "SAVED LOCATIONS"
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
      }

      // ---- The other saved locations, in saved order: click to make one
      //      active; the hover "×" removes it (never the active or last one).
      Column {
        visible: root.otherLocations.length > 0
        width: parent.width
        spacing: Style.spacing.md

        Repeater {
          id: locationRows
          model: root.otherLocations

          Rectangle {
            id: locationRow
            required property var modelData
            required property int index
            readonly property bool removable: Locations.canRemove(root.locationState, modelData.index)

            width: parent.width
            implicitHeight: rowName.implicitHeight + Style.space(15) * 2
            height: implicitHeight
            radius: Style.cornerRadius
            color: root.mix(Commons.Color.popups.background, root.bar.foreground, rowHover.hovered || root.focusIndex === locationRow.index ? 0.15 : 0.10)

            HoverHandler { id: rowHover }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activateLocation(locationRow.modelData.index)
            }

            Text {
              id: rowName
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.rowPaddingX
              anchors.right: rowWeather.left
              anchors.rightMargin: Style.spacing.xl
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: locationRow.modelData.location.name
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.subtitle
              font.weight: Font.DemiBold
              elide: Text.ElideRight
            }

            Row {
              id: rowWeather
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.rowPaddingX
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(7)
              LayoutMirroring.enabled: false

              Text {
                textFormat: Text.PlainText
                text: root.rowTemp(locationRow.modelData.location)
                visible: text !== ""
                color: Qt.darker(root.bar.foreground, 1.55)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                textFormat: Text.PlainText
                text: root.rowIcon(locationRow.modelData.location)
                visible: text !== ""
                color: Qt.darker(root.bar.foreground, 1.55)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            PanelActionButton {
              id: removeButton
              anchors.horizontalCenter: parent.right
              anchors.horizontalCenterOffset: -Style.space(22) * 5 / 24
              anchors.verticalCenter: parent.top
              size: fontSize + (Style.space(22) - fontSize) * 0.85
              radius: size / 2
              color: root.mix(Commons.Color.popups.background, root.bar.foreground, _hot ? 0.24 : 0.14)
              borderSpec: Border.flat(root.mix(Commons.Color.popups.background, root.bar.foreground, _hot ? 0.65 : 0.35), Style.space(1))
              iconText: "\u00d7"
              foreground: Qt.darker(root.bar.foreground, 1.55)
              hoverColor: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.bodySmall
              enabled: locationRow.removable
              opacity: locationRow.removable && (rowHover.hovered || removeButton._hot) ? 1 : 0
              visible: opacity > 0
              Behavior on opacity { NumberAnimation { duration: Style.duration(120) } }
              onClicked: root.removeLocation(locationRow.modelData.index)
            }
          }
        }
      }

      // ---- "+ Add location": a bordered button that turns into the search.
      Button {
        id: addButton
        visible: root.hasLocation && !(root.editingLocation && root.editMode === "add")
        hasCursor: root.focusIndex === root.otherLocations.length
        width: parent.width
        height: addField.implicitHeight
        text: "+ Add location"
        fontSize: Style.font.bodySmall
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        bordered: true
        onClicked: root.startEditingLocation("add")
      }

      TextField {
        id: addField
        visible: root.editingLocation && root.editMode === "add"
        width: parent.width
        placeholderText: Commons.I18n.t("weather.searchCity")
        foreground: root.bar.foreground
        font.family: root.bar.fontFamily

        onTextChanged: if (root.editingLocation && root.editMode === "add") geocodeDebounce.restart()

        Keys.onPressed: function(event) { root.handleSearchKey(event) }
      }

      Suggestions {
        host: root
        visible: root.editingLocation && root.editMode === "add" && root.locationSuggestions.length > 0
      }
    }
  }
  }
  }

  function handleSearchKey(event) {
    if (event.key === Qt.Key_Escape) {
      root.cancelEditingLocation()
      event.accepted = true
    } else if (event.key === Qt.Key_Down) {
      if (root.suggestionIndex < root.locationSuggestions.length - 1) root.suggestionIndex++
      event.accepted = true
    } else if (event.key === Qt.Key_Up) {
      if (root.suggestionIndex > 0) root.suggestionIndex--
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.commitLocation()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      root.switchPanel((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
      event.accepted = true
    }
  }

  // Geocoding suggestions, shown under whichever search field is open.
  component Suggestions: Column {
    id: suggestions
    // Inline components do not see the panel's ids, so the panel is passed in.
    required property var host
    width: parent ? parent.width : 0
    spacing: 0

    Repeater {
      model: suggestions.host.locationSuggestions

      Rectangle {
        required property var modelData
        required property int index
        width: parent.width
        height: suggestionRow.implicitHeight + Style.space(12)
        radius: Style.cornerRadius
        color: index === suggestions.host.suggestionIndex ? Style.hoverFillFor(suggestions.host.bar.foreground, Commons.Color.accent) : "transparent"

        Row {
          id: suggestionRow
          anchors.left: parent.left
          anchors.leftMargin: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText
            text: modelData.name
            color: index === suggestions.host.suggestionIndex ? Style.hoverStateColor(suggestions.host.bar.foreground, Commons.Color.accent) : suggestions.host.bar.foreground
            font.family: suggestions.host.bar.fontFamily
            font.pixelSize: Style.font.body
          }
          Text {
            textFormat: Text.PlainText
            visible: text !== ""
            text: modelData.description
            color: Qt.darker(suggestions.host.bar.foreground, 1.5)
            font.family: suggestions.host.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onPositionChanged: suggestions.host.suggestionIndex = index
          onClicked: suggestions.host.pickSuggestion(modelData)
        }
      }
    }
  }
}
