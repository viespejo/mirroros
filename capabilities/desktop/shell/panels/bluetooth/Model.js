// Adapted from Omarchy shell/plugins/panels/bluetooth/Model.js at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David
// Heinemeier Hansson). Changed: the per-address pending-action map
// (cloneMap, pendingAction, withPendingAction) is replaced by a single
// in-flight action (DEC-072). Added: actionBlocked, startAction,
// failureLiteral, actionResult and powerFailureLiteral; upstream functions
// are otherwise unchanged.

function deviceLabel(device) {
  if (!device) return ""
  return String(device.deviceName || device.name || "").trim()
}

function toArray(values) {
  if (!values) return []
  if (Array.isArray(values)) return values.slice()

  var length = Number(values.length || 0)
  if (!isFinite(length) || length <= 0) return []

  var list = []
  for (var i = 0; i < length; i++) list.push(values[i])
  return list
}

function isUuidLike(value) {
  var text = String(value || "").trim()
  if (text === "") return false
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(text)
    || /^[0-9a-f]{32}$/i.test(text)
    || /^0x[0-9a-f]{4,32}$/i.test(text)
    || /^0000[0-9a-f]{4}-0000-1000-8000-00805f9b34fb$/i.test(text)
}

function isAddressLike(value) {
  var text = String(value || "").trim()
  return /^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(text)
}

function normalizedAddress(value) {
  return String(value || "").trim().toLowerCase().replace(/[^0-9a-f]/g, "")
}

function hasHumanName(device) {
  var label = deviceLabel(device)
  return label !== "" && !isUuidLike(label) && !isAddressLike(label)
}

function nodeProps(node) {
  return node && node.ready && node.properties ? node.properties : {}
}

function nodeText(node) {
  var props = nodeProps(node)
  return [
    node ? node.name : "",
    node ? node.description : "",
    node ? node.nickname : "",
    node ? node.nick : "",
    props["node.name"],
    props["node.description"],
    props["node.nick"],
    props["device.name"],
    props["device.description"],
    props["device.product.name"],
    props["device.alias"],
    props["device.string"],
    props["api.bluez5.address"],
    props["bluez5.address"],
    props["media.name"]
  ].join(" ").toLowerCase()
}

function bluetoothSinkMatchesDevice(node, device) {
  if (!node || !node.isSink || node.isStream || !device) return false

  var address = normalizedAddress(device.address)
  var text = nodeText(node)
  if (address !== "" && normalizedAddress(text).indexOf(address) !== -1) return true

  var label = deviceLabel(device).toLowerCase()
  return label !== "" && text.indexOf(label) !== -1
}

function sortedByLabel(devices) {
  var list = toArray(devices)
  list.sort(function(a, b) { return deviceLabel(a).localeCompare(deviceLabel(b)) })
  return list
}

// Primitives-only projection of a BlueZ device for list-model rows. Holding
// the Device QObject in model data puts a live wrapper into every delegate's
// var property, and BlueZ churn (discovery timeouts, unpair) can destroy the
// object while a delegate is still incubating, which segfaults quickshell.
// Actions resolve the backend object via Panel.deviceFor().
function deviceRow(d) {
  if (!d) return null
  return {
    address: d.address || "",
    name: d.name || "",
    deviceName: d.deviceName || "",
    connected: !!d.connected,
    state: d.state !== undefined ? d.state : -1,
    batteryAvailable: !!d.batteryAvailable,
    battery: d.battery !== undefined ? d.battery : 0,
    pairing: !!d.pairing
  }
}

function deviceLists(devices) {
  var values = toArray(devices)
  var connected = []
  var known = []
  var discovered = []

  for (var i = 0; i < values.length; i++) {
    var d = values[i]
    if (!d || !hasHumanName(d)) continue
    if (d.connected) connected.push(d)
    else if (d.paired || d.bonded || d.trusted) known.push(d)
    else discovered.push(d)
  }

  return {
    connected: sortedByLabel(connected),
    known: sortedByLabel(known),
    discovered: sortedByLabel(discovered)
  }
}

// One device action runs at a time panel-wide (DEC-072): BlueZ serializes
// operations on a controller and concurrent pair/connect is unreliable. The
// in-flight action is { address, action } or null.
function pendingAction(current, address) {
  return address && current && current.address === address ? current.action : ""
}

// Rows other than the acting one are dimmed and their actions ignored.
function actionBlocked(current, address) {
  return !!current && !!current.address && current.address !== address
}

// The next in-flight action, or null when one already runs (repeats and
// clicks on other rows are ignored) or the request is incomplete.
function startAction(current, address, action) {
  if (current || !address || !action) return null
  return { address: address, action: action }
}

// Row literal for a failed action. Only a failed pair points at Advanced…:
// devices that need a code cannot pair under the NoInputNoOutput agent
// (DEC-070). The owned English text is the fallback when no translator is passed.
function failureLiteral(action, tr) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  if (action === "pair") return t("bluetooth.pairFailed", "Pairing failed. Devices that need a code: use Advanced…")
  if (action === "connect") return t("bluetooth.connectFailed", "Connect failed")
  if (action === "disconnect") return t("bluetooth.disconnectFailed", "Disconnect failed")
  if (action === "forget") return t("bluetooth.forgetFailed", "Forget failed")
  return t("bluetooth.actionFailed", "Action failed")
}

// Result of a bluetooth-device exit. On 0 the BlueZ state governs the row.
// Exit codes: 2 usage, 3 power on, 4 pair, 5 trust, 6 connect, 7 disconnect,
// 8 remove. A pair that fails after pairing succeeded (trust or connect) is
// not reported as a pairing failure.
function actionResult(action, exitCode, tr) {
  if (exitCode === 0) return { ok: true, failure: "" }
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  var failure
  if (exitCode === 3) failure = t("bluetooth.powerOnFailed", "Could not turn Bluetooth on")
  else if (exitCode === 5) failure = t("bluetooth.trustFailed", "Trust failed")
  else if (exitCode === 6) failure = failureLiteral("connect", tr)
  else failure = failureLiteral(action, tr)
  return { ok: false, failure: failure }
}

// Literal for a failed bluetooth-power on|off request.
function powerFailureLiteral(on, tr) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  return on ? t("bluetooth.powerOnFailed", "Could not turn Bluetooth on")
    : t("bluetooth.powerOffFailed", "Could not turn Bluetooth off")
}

function visibleSections(lists, discovering) {
  var sections = []
  if (lists && lists.connected && lists.connected.length > 0) sections.push("connected")
  if (lists && lists.known && lists.known.length > 0) sections.push("known")
  if (discovering && lists && lists.discovered && lists.discovered.length > 0) sections.push("discovered")
  return sections
}

function sectionDevices(lists, section) {
  if (!lists) return []
  if (section === "connected") return lists.connected || []
  if (section === "known") return lists.known || []
  if (section === "discovered") return lists.discovered || []
  return []
}

if (typeof module !== "undefined") {
  module.exports = {
    deviceLabel: deviceLabel,
    toArray: toArray,
    isUuidLike: isUuidLike,
    isAddressLike: isAddressLike,
    normalizedAddress: normalizedAddress,
    hasHumanName: hasHumanName,
    nodeProps: nodeProps,
    nodeText: nodeText,
    bluetoothSinkMatchesDevice: bluetoothSinkMatchesDevice,
    sortedByLabel: sortedByLabel,
    deviceRow: deviceRow,
    deviceLists: deviceLists,
    pendingAction: pendingAction,
    actionBlocked: actionBlocked,
    startAction: startAction,
    failureLiteral: failureLiteral,
    actionResult: actionResult,
    powerFailureLiteral: powerFailureLiteral,
    visibleSections: visibleSections,
    sectionDevices: sectionDevices
  }
}
