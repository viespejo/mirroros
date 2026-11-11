import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "GlobeModel.js" as Solar

// Adapted from Omarchy shell/plugins/panels/elsewhen/Panel.qml at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (Elsewhen, MIT, Jason Fried).
// Changes (ADR 0029): hosted by bar/widgets/WorldClock.qml, which injects
// bar, settings, moduleName, anchorItem and hostWidget, so the panel has no
// bar button and anchors to the host's; panel IPC lives in the bar (native
// `worldclock` target with open/close/toggle; no ShellIpc); no start-up
// probe, so the zone probe, the first-run seed, the zone catalogue and the
// open-meteo requests run only while the panel is open; globeEnabled is fixed
// off and the big globe, its zoom transition, jump box and session cities,
// smoothMotion and the moon show are removed; no people or GitHub profiles;
// no time-zone change (timezoneProc and its notifications): "Where are you?"
// offers only zones and places on the machine's own zone.

// A panel of clocks, one row per city. QML has no Intl, so a `date` probe
// supplies each zone's offset and the rows tick locally against it; the probe
// re-runs on open and every five minutes while open to catch DST.
Panel {
  id: root
  moduleName: "omarchy.elsewhen"
  ipcTarget: "omarchy.elsewhen"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — bar/widgets/WorldClock.qml
  // — not this nested panel, so the popout coordinator and Tab switching
  // identify the panel by that widget.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  function open() {
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
  }

  // Set after showing: showing hands the popout coordinator over, which
  // closes whichever panel was open, and that close clears the shared flag.
  function openFromHotkey() {
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
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

  // Items inside the panel's lazily built content, null until it first
  // opens. Code inside the content reaches its own ids directly.
  readonly property Item scroller: panel.loadedContent ? panel.loadedContent.scroller : null
  readonly property Item scrollContent: panel.loadedContent ? panel.loadedContent.scrollContent : null
  readonly property Item hero: panel.loadedContent ? panel.loadedContent.hero : null
  readonly property Item stage: panel.loadedContent ? panel.loadedContent.stage : null
  readonly property Item listWrap: panel.loadedContent ? panel.loadedContent.listWrap : null
  readonly property Item cityRows: panel.loadedContent ? panel.loadedContent.cityRows : null
  readonly property Item citySearch: panel.loadedContent ? panel.loadedContent.citySearch : null
  readonly property Item hereSearch: panel.loadedContent ? panel.loadedContent.hereSearch : null


  // ---- settings
  // `cities` once written; until then the older `zones` string.
  readonly property var zones: Model.parseCities(setting("cities", null), setting("zones", ""))
  readonly property var zoneIds: zones.map(function(z) { return z.id })
  // Never written: the first probe seeds the list around the local zone.
  readonly property bool needsSeed: zones.length === 0
  readonly property var probeIds: needsSeed ? zoneIds.concat(Model.seedCandidateZones()) : zoneIds

  readonly property var formatLocale: Qt.locale(Commons.I18n.formatLocale)
  readonly property bool autoHour24: Model.usesTwentyFourHour(formatLocale.timeFormat(Locale.ShortFormat))
  readonly property bool hour24: Model.resolveHour24(setting("hour24", ""), autoHour24)
  // "home" shows the distance from here ("+2h"), "utc" the zone itself ("UTC-5").
  readonly property string offsetMode: setting("offsetMode", "home") === "utc" ? "utc" : "home"
  // Only the US measurement system means Fahrenheit.
  readonly property string autoUnits: formatLocale.measurementSystem === Locale.ImperialUSSystem ? "F" : "C"
  readonly property string units: Model.resolveUnits(setting("units", ""), autoUnits)
  // Fixed off: the big globe is not delivered, so the hero globe opens nothing.
  readonly property bool globeEnabled: false

  // The words the model's clocks and dates read in, from the shell's language.
  readonly property var words: {
    var locale = formatLocale
    return {
      t: Commons.I18n.t,
      tn: Commons.I18n.tn,
      fmt: Commons.I18n.formatNumber,
      am: locale.amText,
      pm: locale.pmText,
      date: function(parts) {
        return new Date(parts.year, parts.month, parts.day, 12)
          .toLocaleString(locale, Commons.I18n.t("elsewhen.dateFormat"))
      }
    }
  }

  function toggleHour24() { persistSettings({ hour24: !hour24 }) }
  function toggleOffsetMode() { persistSettings({ offsetMode: offsetMode === "utc" ? "home" : "utc" }) }
  function toggleUnits() { persistSettings({ units: units === "C" ? "F" : "C" }) }

  function offsetTextFor(rowData) {
    if (!rowData || !rowData.ready) return ""
    return offsetMode === "utc" ? Model.utcOffsetLabel(rowData.offsetMinutes, words) : rowData.relative
  }

  // ---- state
  property var probe: ({})
  property var searchProbe: ({})
  property string zoneCatalogText: ""
  property var facts: ({})
  // Geocoder answers are final for the session; fallbacks are retried.
  property var geo: ({})
  property var fallbackGeo: ({})
  property var weather: ({})
  property int localOffsetMinutes: -(new Date().getTimezoneOffset())
  property string localZone: ""
  property double nowMs: Date.now()
  property bool probeQueued: false
  property bool searchProbeQueued: false
  property bool factsQueued: false

  readonly property bool adding: citySearch ? citySearch.active : false
  onAddingChanged: if (!adding && scroller) scroller.scrollToTop()
  readonly property bool choosingHere: hereSearch ? hereSearch.active : false
  readonly property var zoneOptions: Model.zoneOptions(zoneCatalogText, zones)
  // "Where are you?" stays on this machine's zone: here never moves the clock.
  readonly property var hereOptions: Model.zoneOptions(zoneCatalogText, [])
    .filter(function(option) { return option.value === localZone })
  function herePlacesFor(text) {
    return placesFor(text).filter(function(place) { return place.value === localZone })
  }
  readonly property var searchZoneIds: {
    var out = []
    var matches = (citySearch ? citySearch.matches : []).concat(hereSearch ? hereSearch.matches : [])
    for (var i = 0; i < matches.length; i++) {
      var id = matches[i].value
      if (out.indexOf(id) < 0) out.push(id)
    }
    return out
  }
  onSearchZoneIdsChanged: probeSearchZones()

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color fainter: Qt.darker(foreground, 2.1)
  // A literal gold: several themes' "yellow" is not yellow.
  readonly property color daylightMarker: "#E5C736"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ---- the zoom
  // The list never zooms into a globe; the copied rows, hero and search still
  // read the zoom, which stays at the list.
  readonly property real zoom: 0
  // Far enough for the top row to fall past the whole list.
  readonly property real knockFall: (listWrap ? listWrap.implicitHeight : 0) + Style.space(220)

  // Here moves, and the row that stood for it follows. A place on another zone
  // would move the machine's clock, which the shell never does: it is ignored.
  function setHere(pick) {
    var next = Model.hereAfterPick(zones, hereZone, pick, localZone)
    if (!next || next.zoneChange !== "") return
    applyHere(next)
  }

  function applyHere(next) {
    var values = { here: next.here === null ? undefined : next.here, homeCity: undefined }
    if (next.zones && next.zones !== zones) { values.cities = Model.serializeCities(next.zones); values.zones = undefined }
    persistSettings(values)
    refreshFacts()
  }

  function startChoosingHere() { if (hereSearch && localZone !== "") hereSearch.start() }

  // ---- drag to reorder
  // Rows move by transform while dragging; the order is committed on drop.
  property int dragIndex: -1
  property real dragOffset: 0
  property real rowPitch: 0
  // Every row's pitch, measured at the grab.
  property var rowPitches: []
  property int dragTarget: -1

  function beginRowDrag(index, pitch) {
    dropAnimation.stop()
    dragIndex = index
    dragTarget = index
    rowPitch = pitch
    var gap = pitch - (cityRows && cityRows.itemAt(index) ? cityRows.itemAt(index).height : 0)
    var pitches = []
    for (var i = 0; i < zones.length; i++) {
      var item = cityRows ? cityRows.itemAt(i) : null
      pitches.push(item ? item.height + gap : pitch)
    }
    rowPitches = pitches
  }

  function moveRowDrag(offset) {
    dragOffset = offset
    dragTarget = Model.dragTargetFor(dragIndex, dragOffset, rowPitch, dragTarget, zones.length, rowPitches)
  }

  // Glide into the slot, then commit.
  function releaseRowDrag() {
    if (dragIndex < 0) { cancelRowDrag(); return }
    dropAnimation.to = Model.dropOffset(dragIndex, dragTarget, rowPitch, rowPitches)
    dropAnimation.restart()
  }

  function commitRowDrag() {
    if (dragIndex >= 0 && dragTarget >= 0 && dragTarget !== dragIndex)
      persistSettings({ cities: Model.serializeCities(Model.moveZone(zones, dragIndex, dragTarget)), zones: undefined })
    cancelRowDrag()
  }

  function cancelRowDrag() {
    dropAnimation.stop()
    dragIndex = -1
    dragTarget = -1
    dragOffset = 0
  }

  // ---- scrubbing
  // Set absolutely from the pointer, held briefly after release, then back to now.
  property real scrubMinutes: 0
  readonly property double effectiveMs: nowMs + scrubMinutes * 60000
  readonly property string scrubLabel: Model.formatScrubDelta(scrubMinutes, words)

  // Measured against the unscrubbed present, so a drag cannot drift.
  function scrubTo(rowData, fraction) {
    if (!rowData || !rowData.ready) return
    var parts = Model.zoneParts(nowMs, rowData.offsetMinutes)
    scrubMinutes = Model.scrubDeltaMinutes(fraction, parts.hour * 60 + parts.minute)
  }

  function beginScrub(rowData, fraction) {
    scrubHold.stop()
    scrubTo(rowData, fraction)
  }

  function endScrub() { scrubHold.restart() }

  // Held until Escape or close: a key press has no release to time from. Unlike a
  // drag, which stays within the strip's day, the keys can run on into other days.
  function shiftHour(step) {
    scrubHold.stop()
    scrubMinutes = Math.round(scrubMinutes) + step * 60
  }

  // ---- the moon
  // The daylight strip's night marker.
  readonly property real moonPhase: Solar.moonPhase(effectiveMs)

  // ---- places
  readonly property var clockRows: Model.rows(zones, probe, effectiveMs, localOffsetMinutes, hour24, words)

  // The system zone names a representative city; a chosen `here` overrides it
  // while the machine stays on that zone, so a trip resets it on its own.
  readonly property var hereZone: Model.resolveHere(setting("here", null), setting("homeCity", ""), localZone)
  readonly property string homeCity: hereZone ? hereZone.label : ""
  readonly property var homeZone: hereZone || ({ label: "", id: localZone })

  function placeOf(zone) {
    var f = facts[Model.factsKey(zone)]
    return (f && f.lat !== undefined && f.lon !== undefined) ? f : null
  }

  // Held as the city's key, not a row index, so a reorder carries the focus
  // with the city and a removal drops it back to home.
  property string focusKey: ""
  readonly property int focusIndex: Model.indexOfZoneKey(zones, focusKey)
  readonly property var focusZone: focusIndex >= 0 ? zones[focusIndex] : homeZone
  readonly property var focusPlace: placeOf(focusZone)
  readonly property bool focusKnown: focusPlace !== null
  readonly property real focusLat: focusKnown ? focusPlace.lat : 0
  readonly property real focusLon: focusKnown ? focusPlace.lon : 0

  function focusOn(index) {
    addSelected = false
    var from = hero ? hero.spin : 0
    focusKey = index >= 0 && index < zones.length ? Model.factsKey(zones[index]) : ""
    if (focusKnown && hero) hero.turn(from, focusLon)
  }

  // Past the last city, the list's cursor rests on "Add a city"; the globe stays put.
  property bool addSelected: false

  // Up and down walk home, each city and then "Add a city", wrapping round like the
  // search list.
  function moveFocus(step) {
    var at = addSelected ? zones.length : focusIndex
    var next = Model.moveSelection(at + 1, step, zones.length + 2) - 1
    if (next === zones.length) {
      addSelected = true
      scrollToItem(citySearch)
      return
    }
    focusOn(next)
    scrollToItem(next >= 0 && cityRows ? cityRows.itemAt(next) : null)
  }

  // The picked city goes, as with its × button, and the cursor lands on the city
  // that takes its place. The last city stays, so there is always one clock.
  function deleteFocused() {
    if (addSelected || focusIndex < 0 || zones.length < 2) return
    var at = focusIndex
    removeCityAt(at)
    focusOn(Math.min(at, zones.length - 1))
  }

  function scrollToItem(item) {
    if (!scroller) return
    if (!item) { scroller.scrollToTop(); return }
    var top = item.mapToItem(scrollContent, 0, 0).y
    if (top < scroller.contentY) scroller.scrollTo(top)
    else if (top + item.height > scroller.contentY + scroller.height)
      scroller.scrollTo(Math.min(scroller.maxScroll, top + item.height - scroller.height))
  }

  // Surrogate pairs rather than literal glyphs, which re-encoding can break.
  function weatherGlyph(zone) {
    var f = facts[Model.factsKey(zone)]
    if (!f || f.w === undefined) return ""
    var kind = Model.weatherKind(f.w)
    if (kind === "sunny") return "\udb81\udda8"  // white-balance-sunny: a solid disc
    if (kind === "partly") return "\udb81\udd95"
    if (kind === "cloudy") return "\udb81\udd90"
    if (kind === "rain") return "\udb81\udd97"
    if (kind === "snow") return "\udb81\udd98"
    return ""
  }

  readonly property string localTime: {
    var here = Model.localParts(effectiveMs)
    var text = Model.formatTime(here, hour24, words)
    return hour24 ? text : text + " " + Model.meridiem(here, words)
  }

  // No full stop: a period hanging off the arc reads as a speck.
  readonly property string hereLine: (homeCity !== ""
      ? Commons.I18n.t("elsewhen.hereIn").arg(localTime).arg(homeCity)
      : Commons.I18n.t("elsewhen.here").arg(localTime))
    + (scrubLabel !== "" ? "  " + scrubLabel : "")

  // A capital's line box has empty space above it; the row's top pad drops by it.
  FontMetrics {
    id: nameFontMetrics
    font.family: root.fontFamily
    font.pixelSize: Style.font.subtitle
  }

  TextMetrics {
    id: nameCapMetrics
    font.family: root.fontFamily
    font.pixelSize: Style.font.subtitle
    text: "M"
  }

  readonly property real capGap: Math.max(0,
    nameFontMetrics.height - nameFontMetrics.descent + nameCapMetrics.tightBoundingRect.y)

  // The widest a row's time gets, so every row's weather lines up against one
  // column rather than hugging "4:06" in one row and "10:06" in the next.
  TextMetrics {
    id: widestTimeMetrics
    font.family: root.fontFamily
    font.pixelSize: Style.font.heading
    font.weight: Font.DemiBold
    // In the language's digits, which are not all as wide as ASCII ones.
    text: Model.formatTime({ hour: 0, minute: 0 }, true, root.words)
  }

  TextMetrics {
    id: meridiemMetrics
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    text: root.formatLocale.pmText.length > root.formatLocale.amText.length
      ? root.formatLocale.pmText : root.formatLocale.amText
  }

  readonly property real timeColumnWidth: Math.ceil(widestTimeMetrics.advanceWidth
    + (hour24 ? 0 : Style.spacing.xs + meridiemMetrics.advanceWidth))

  function tick() {
    nowMs = Date.now()
    localOffsetMinutes = -(new Date().getTimezoneOffset())
  }

  // Written straight back to this widget's shell.json entry, like the clock's.
  // An undefined value removes its key.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) {
      if (values[key] === undefined) delete entry[key]
      else entry[key] = values[key]
    }

    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setZones(next) {
    if (next === zones) return
    persistSettings({ cities: Model.serializeCities(next), zones: undefined })
    refresh()
    refreshFacts()
  }

  // The label matters as much as the zone: many cities share one. A place from
  // the geocoder brings its coordinates, so the row never has to look itself up.
  function addCity(id, label, place) { setZones(Model.addZone(zones, id, label || "", place)) }
  function removeCity(id) { setZones(Model.removeZone(zones, id)) }
  function removeCityAt(index) { setZones(Model.removeZoneAt(zones, index)) }

  function startAdding() { if (citySearch) citySearch.start() }

  // The local city plus four places spread round the clock from it. Home is
  // here, so a city already chosen is the one the list starts with.
  function seedFirstRun() {
    var offs = ({})
    for (var id in probe) offs[id] = probe[id].offsetMinutes

    var seeded = localZone === "" || !hereZone ? []
      : Model.seedZones({ label: hereZone.label, id: localZone }, offs, 4)
    if (seeded.length > 0 && hereZone.lat !== undefined) seeded[0] = Object.assign({}, seeded[0], hereZone)
    if (seeded.length === 0) seeded = Model.parseZones(Model.DEFAULT_ZONES)
    if (seeded.length === 0) return

    persistSettings({ cities: Model.serializeCities(seeded), zones: undefined })
    refresh()
    refreshFacts()
  }

  // A hidden field keeps its focus, so the panel asks for the keyboard back.
  function takeKeyboardBack() {
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  }

  // ---- place search
  // The geocoder's places for each query, kept for the session. A query is
  // looked up once the typing pauses, one request at a time, latest wins.
  property var placeCache: ({})
  property string placeWanted: ""

  function requestPlaces(text) {
    var q = Model.placeQuery(text)
    if (q === "" || placeCache[q] !== undefined) return
    placeWanted = q
    placeDebounce.restart()
  }

  function lookupPlaces() {
    var q = placeWanted
    if (q === "" || placeCache[q] !== undefined) return
    if (placeProc.running) return
    placeProc.query = q
    placeProc.command = ["curl", "-fsS", "--max-time", "8", Model.geocodeUrl(q)]
    placeProc.running = true
  }

  function placesFor(text) {
    var q = Model.placeQuery(text)
    return q === "" ? [] : (placeCache[q] || [])
  }

  function placesPending(text) {
    var q = Model.placeQuery(text)
    return q !== "" && placeCache[q] === undefined
  }

  // ---- processes
  // Each refresh queues behind one in flight rather than being dropped.
  function refresh() {
    if (probeIds.length === 0) return
    if (probeProc.running) { probeQueued = true; return }
    probeProc.running = true
  }

  // The command is set here rather than bound: this runs from the ids' own
  // change handler, which can fire before a binding on them has caught up.
  function probeSearchZones() {
    if (searchZoneIds.length === 0) return
    if (searchProc.running) { searchProbeQueued = true; return }
    searchProc.command = Model.probeCommand(searchZoneIds, false)
    searchProc.running = true
  }

  function refreshFacts() {
    if (zones.length === 0) return
    if (geoProc.running || weatherProc.running) { factsQueued = true; return }
    var missing = factsRequest.filter(function(row) {
      var key = Model.factsKey(row)
      return !geo[key] && !pinnedGeo[key]
    })
    if (missing.length === 0) { fetchWeather(); return }
    geoProc.rows = missing
    geoProc.command = ["bash", "-c", 'for url; do curl -fsS --max-time 8 "$url"; printf "\\n\\036\\n"; done', "bash"]
      .concat(missing.map(function(row) { return Model.geocodeUrl(row.label) }))
    geoProc.running = true
  }

  function coordsFor(key) {
    return pinnedGeo[key] || geo[key] || fallbackGeo[key] || null
  }

  function fetchWeather() {
    var now = Date.now()
    // A reading for somewhere else is stale too: a city's coordinates can move under its name.
    var stale = factsRequest.map(Model.factsKey).filter(function(key) {
      return coordsFor(key) && Model.weatherStale(weather[key], now, coordsFor(key))
    })
    if (stale.length === 0) { publishFacts(); return }
    weatherProc.keys = stale
    weatherProc.points = stale.map(coordsFor)
    weatherProc.command = ["curl", "-fsS", "--max-time", "8", Model.forecastUrl(stale.map(coordsFor))]
    weatherProc.running = true
  }

  function publishFacts() {
    var coords = {}
    var keys = factsRequest.map(Model.factsKey)
    keys.forEach(function(key) { coords[key] = coordsFor(key) })
    facts = Model.mergeFacts(keys, coords, weather)
    if (!factsQueued) return
    factsQueued = false
    Qt.callLater(refreshFacts)
  }

  function loadCatalog() {
    if (zoneCatalogText !== "" || catalogProc.running) return
    catalogProc.running = true
  }

  function utcLabelFor(zoneId) {
    var known = searchProbe[zoneId]
    return known === undefined ? "" : Model.utcOffsetLabel(known.offsetMinutes, words)
  }

  // Tracked cities and the city you are in (for the hero's home).
  readonly property var factsRequest: {
    var out = zones.slice()
    if (hereZone) out.push(hereZone)
    return out
  }

  // Coordinates a city came with, from a place search: never geocoded by name.
  readonly property var pinnedGeo: {
    var out = {}
    factsRequest.forEach(function(row) {
      if (row.lat !== undefined) out[Model.factsKey(row)] = { lat: row.lat, lon: row.lon }
    })
    return out
  }

  // ---- opening spin
  // It lands on the home meridian, so it waits for home's coordinates, read
  // straight from the facts: focusKnown can flip a beat before focusLon lands.
  property bool spinPending: false

  function homeMeridian() {
    var f = facts[Model.factsKey(focusZone)]
    return (f && f.lon !== undefined && f.lon !== null) ? f.lon : null
  }

  function startOpeningSpin() {
    var lon = homeMeridian()
    if (lon === null) { spinPending = true; spinFallback.restart(); return }
    spinPending = false
    spinFallback.stop()
    if (hero) hero.spinOpening(lon)
  }

  onFactsChanged: if (spinPending) startOpeningSpin()

  // No coordinates on a cold cache without network: spin anyway.
  Timer {
    id: spinFallback
    interval: 1500
    onTriggered: if (root.spinPending) { root.spinPending = false; if (root.hero) root.hero.spinOpening(null) }
  }

  onOpenedChanged: {
    if (opened) {
      // The opening spin below drives the hero, so build the content first.
      panel.ensureContent()
      focusKey = ""
      addSelected = false
      tick(); refresh(); refreshFacts(); loadCatalog()
      startOpeningSpin()
    } else {
      if (citySearch) citySearch.stop()
      if (hereSearch) hereSearch.stop()
      scrubMinutes = 0
      spinPending = false; spinFallback.stop()
    }
  }

  Process {
    id: probeProc
    command: Model.probeCommand(root.probeIds, true)
    stdout: StdioCollector {
      onStreamFinished: {
        root.probe = Model.parseProbe(text)
        var lz = Model.localZoneFromProbe(text)
        if (lz !== "") root.localZone = lz
        if (root.needsSeed) root.seedFirstRun()
        root.tick()
        Qt.callLater(function() {
          if (!root.probeQueued) return
          root.probeQueued = false
          root.refresh()
        })
      }
    }
  }

  // Merged, so a known offset stays on screen while the next probe runs.
  Process {
    id: searchProc
    stdout: StdioCollector {
      onStreamFinished: {
        var merged = {}
        for (var known in root.searchProbe) merged[known] = root.searchProbe[known]
        var fresh = Model.parseProbe(text)
        for (var id in fresh) merged[id] = fresh[id]
        root.searchProbe = merged
        Qt.callLater(function() {
          if (!root.searchProbeQueued) return
          root.searchProbeQueued = false
          root.probeSearchZones()
        })
      }
    }
  }

  Process {
    id: catalogProc
    command: ["timedatectl", "list-timezones"]
    stdout: StdioCollector {
      onStreamFinished: root.zoneCatalogText = text
    }
  }

  FileView {
    id: zoneTab
    path: "/usr/share/zoneinfo/zone1970.tab"
    printErrors: false
  }

  Process {
    id: geoProc
    property var rows: []
    stdout: StdioCollector {
      onStreamFinished: {
        var answers = text.split("\n\u001e\n")
        var nextGeo = Object.assign({}, root.geo)
        var nextFallback = {}
        geoProc.rows.forEach(function(row, i) {
          var key = Model.factsKey(row)
          var found = Model.pickGeocode(answers[i] || "", row.id)
          var place = found.place || Model.zoneTabCoords(zoneTab.text(), row.id)
          if (!place) return
          if (found.answered) nextGeo[key] = place
          else nextFallback[key] = place
        })
        root.geo = nextGeo
        root.fallbackGeo = nextFallback
        root.fetchWeather()
      }
    }
  }

  Timer {
    id: placeDebounce
    interval: 300
    onTriggered: root.lookupPlaces()
  }

  // A failed lookup is remembered as no places, so the list stops saying it is
  // searching. The next query is tried on the answer and again on the exit: the
  // output can finish while the process still reads as running, and a query
  // turned away then would never be asked.
  Process {
    id: placeProc
    property string query: ""
    onRunningChanged: if (!running) Qt.callLater(root.lookupPlaces)
    stdout: StdioCollector {
      onStreamFinished: {
        var next = Object.assign({}, root.placeCache)
        next[placeProc.query] = Model.placeOptions(text)
        root.placeCache = next
        Qt.callLater(root.lookupPlaces)
      }
    }
  }

  Process {
    id: weatherProc
    property var keys: []
    property var points: []
    stdout: StdioCollector {
      onStreamFinished: {
        root.weather = Object.assign({}, root.weather, Model.parseForecast(text, weatherProc.keys, Date.now(), weatherProc.points))
        root.publishFacts()
      }
    }
  }

  Timer {
    interval: 900000
    running: root.opened
    repeat: true
    onTriggered: root.refreshFacts()
  }

  NumberAnimation {
    id: dropAnimation
    target: root
    property: "dragOffset"
    duration: Style.duration(150)
    easing.type: Easing.OutCubic
    onFinished: root.commitRowDrag()
  }

  Timer {
    id: scrubHold
    interval: 2500
    onTriggered: root.scrubMinutes = 0
  }

  Timer {
    interval: 1000
    running: root.opened
    repeat: true
    onTriggered: root.tick()
  }

  Timer {
    interval: 300000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(680))

    content: PanelKeyCatcher {
      id: keyCatcher
      property alias scroller: scroller
      property alias scrollContent: scrollContent
      property alias hero: hero
      property alias stage: stage
      property alias listWrap: listWrap
      property alias cityRows: cityRows
      property alias citySearch: citySearch
      property alias hereSearch: hereSearch
      implicitHeight: scrollContent.implicitHeight
      anchors.fill: parent
      blocked: root.adding || root.choosingHere
      // Escape unwinds one layer: search (its own field), a shifted time, then panel.
      onCloseRequested: {
        if (root.scrubMinutes !== 0) { scrubHold.stop(); root.scrubMinutes = 0 }
        else root.close()
      }
      onDeleteRequested: root.deleteFocused()
      // Up and down pick a city; left and right move the clocks an hour.
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveFocus(dy)
        else root.shiftHour(dx)
      }
      // Return or Space on "Add a city" opens the search; elsewhere they do nothing.
      onActivateRequested: {
        if (root.addSelected) root.startAdding()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      // "+" or "a" adds a city. "t" flips 24-hour and AM/PM time, like clicking a
      // row's time, and Alt+T flips Fahrenheit and Celsius, like clicking a
      // temperature. "w" asks where you are, like clicking the header.
      onTextKey: function(text, modifiers) {
        var key = text.toLowerCase()
        if (key === "r") root.refresh()
        else if (key === "t" && (modifiers & Qt.AltModifier)) root.toggleUnits()
        else if (key === "t") root.toggleHour24()
        else if (key === "+" || key === "a") root.startAdding()
        else if (key === "w") root.startChoosingHere()
      }

      // Clipped to the card and scrolled by the wheel only: the rows own drags.
      Flickable {
        id: scroller
        anchors.fill: parent
        anchors.rightMargin: -Style.space(12)
        clip: true
        interactive: false
        contentWidth: width
        contentHeight: scrollContent.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        readonly property real maxScroll: Math.max(0, contentHeight - height)

        function clamp() { contentY = Util.clamp(contentY, 0, maxScroll) }
        onHeightChanged: clamp()
        onContentHeightChanged: clamp()

        function scrollTo(y) {
          scrollAnim.stop()
          scrollAnim.from = contentY
          scrollAnim.to = y
          scrollAnim.start()
        }
        function scrollToTop() { scrollTo(0) }

        // Follows maxScroll: the results arrive over several frames after the
        // search opens, so a one-shot scroll lands short.
        onMaxScrollChanged: if (root.adding) scrollTo(maxScroll)

        // Not a Behavior: the wheel writes contentY too and must track directly.
        NumberAnimation {
          id: scrollAnim
          target: scroller
          property: "contentY"
          duration: Style.duration(160)
          easing.type: Easing.OutCubic
        }

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            var d = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * Style.space(40)
            scroller.contentY -= d
            scroller.clamp()
          }
        }

        Column {
          id: scrollContent
          width: scroller.width - Style.space(12)
          spacing: Style.spacing.panelGap

          HeroTitle {
            id: hero
            width: parent.width
            caption: root.hereLine
            // Accent while scrubbed, so a shifted time is never taken for now.
            captionColor: root.scrubMinutes !== 0 ? Commons.Color.accent : root.dim
            // Away from home it brings the globe back; at home it asks where here is.
            captionClickable: root.focusIndex >= 0 || root.localZone !== ""
            foreground: root.foreground
            dim: root.dim
            fontFamily: root.fontFamily
            zoom: root.zoom
            globeEnabled: root.globeEnabled
            restLon: root.focusLon
            markerShown: root.focusKnown
            markerLat: root.focusLat
            markerLon: root.focusLon
            onCaptionClicked: {
              if (root.focusIndex >= 0) root.focusOn(-1)
              else if (root.choosingHere) hereSearch.stop()
              else root.startChoosingHere()
            }
          }

          // "Where are you?": only zones and places on this machine's zone.
          // Opened by the header rather than a button of its own.
          CitySearch {
            id: hereSearch
            visible: active && root.zoom < 1
            width: parent.width
            showButton: false
            options: root.hereOptions
            placesFor: function(text) { return root.herePlacesFor(text) }
            placesPending: function(text) { return root.placesPending(text) }
            loading: root.zoneCatalogText === ""
            placeholderText: Commons.I18n.t("elsewhen.whereAreYou")
            offsetLabel: function(zoneId) { return root.utcLabelFor(zoneId) }
            foreground: root.foreground
            dim: root.dim
            fainter: root.fainter
            fontFamily: root.fontFamily
            onActiveChanged: if (active) { root.loadCatalog(); if (citySearch.active) citySearch.stop() }
            onQueryChanged: if (active) root.requestPlaces(query)
            onPicked: function(label, id, place) {
              var pick = { label: label, id: id }
              root.setHere(place ? Object.assign(pick, place) : pick)
            }
            onDismissed: root.takeKeyboardBack()
            // Tab and Shift+Tab switch panels while typing; the key catcher is blocked while editing.
            Keys.onTabPressed: root.switchPanel(1)
            Keys.onBacktabPressed: root.switchPanel(-1)
          }

          // ---- stage
          // The list's own height; there is no globe to grow into.
          Item {
            id: stage
            width: parent.width
            height: Math.max(1, listWrap.implicitHeight)

            // Clipped, so knocked rows fall out of the panel.
            Item {
              anchors.fill: parent
              // Let circular actions straddle the rows' top-right corners.
              anchors.topMargin: -Style.space(12)
              anchors.rightMargin: -Style.space(12)
              clip: true

              Column {
                id: listWrap
                y: Style.space(12)
                width: stage.width
                spacing: Style.spacing.panelGap

                Column {
                  visible: root.zoom < 1
                  width: parent.width
                  spacing: Style.spacing.md

                  // The zone list, not clockRows: that ticks, and would
                  // rebuild every delegate mid-drag.
                  Repeater {
                    id: cityRows
                    model: root.zones

                    CityRow { panel: root }
                  }
                }

                CitySearch {
                  id: citySearch
                  visible: root.zoom < 1
                  width: parent.width
                  options: root.zoneOptions
                  existing: root.zones
                  placesFor: function(text) { return root.placesFor(text) }
                  placesPending: function(text) { return root.placesPending(text) }
                  loading: root.zoneCatalogText === ""
                  offsetLabel: function(zoneId) { return root.utcLabelFor(zoneId) }
                  hasCursor: root.addSelected
                  foreground: root.foreground
                  dim: root.dim
                  fainter: root.fainter
                  fontFamily: root.fontFamily
                  onActiveChanged: if (active) { root.loadCatalog(); if (hereSearch.active) hereSearch.stop() }
                  onQueryChanged: if (active) root.requestPlaces(query)
                  onPicked: function(label, id, place) { root.addCity(id, label, place) }
                  onDismissed: root.takeKeyboardBack()
                  // Tab and Shift+Tab switch panels while typing; the key catcher is blocked while editing.
                  Keys.onTabPressed: root.switchPanel(1)
                  Keys.onBacktabPressed: root.switchPanel(-1)

                  // Knocked aside last, after every row.
                  transform: Translate {
                    x: Model.knockX(root.zones.length, root.zoom, Style.space(95))
                    y: Model.knockY(root.zones.length, root.zoom, root.knockFall)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
