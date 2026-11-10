// Adapted from Omarchy shell/plugins/panels/network/Model.js at v4.5.0
// (ac2690cd7be4f47e4a255f5e2e78d904d436b068) (MIT, Copyright (c) David
// Heinemeier Hansson). Changed: captivePortalUrl points at a plain-HTTP host
// that is not HSTS-preloaded; enterpriseConnectScript removed (no enterprise
// credential path). Added: packetLossUrgent, bandPillState,
// dnsNeedsConfirmation and dnsConfirmationValid; upstream functions are
// otherwise unchanged.

// Display numbers go through the shell's I18n.formatNumber when QML passes
// it; Node tests leave it out and get plain English digits.
function formatter(fmt) {
  return typeof fmt === "function" ? fmt : function(v, d) { return d === undefined ? String(v) : Number(v).toFixed(d) }
}

function parseNetworkStatus(raw) {
  var parts = String(raw || "disconnected\t\t\t").replace(/\r?\n+$/, "").split("\t")
  return {
    kind: parts[0] || "disconnected",
    label: parts[1] || "",
    signalStrength: parts[2] ? parseInt(parts[2], 10) : -1,
    frequency: parts[3] || ""
  }
}

function wifiIconFor(strength) {
  var icons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
  var index = Math.max(0, Math.min(4, Math.ceil(strength / 20) - 1))
  return icons[index]
}

// The connected network's own strength comes from the access points
// Quickshell grouped under its SSID. When it has none (an OWE transition-mode
// network between scans files the in-use access point under its hidden
// "_owetm_" twin), fall back to the strength NetworkManager reports for the
// access point in use.
function connectedSignalStrength(networkStrength, activeApSignal) {
  var strength = Math.round((networkStrength || 0) * 100)
  if (strength > 0) return strength
  return activeApSignal > 0 ? activeApSignal : strength
}

// Reads `nmcli -t -f IN-USE,SIGNAL device wifi list` output, where the in-use
// access point is the row marked "*".
function parseActiveApSignal(raw) {
  var lines = String(raw || "").split(/\r?\n/)
  for (var i = 0; i < lines.length; i++) {
    var match = /^\*:(\d+)$/.exec(lines[i].trim())
    if (match) return parseInt(match[1], 10)
  }
  return -1
}

// A known plain-HTTP endpoint lets the network redirect the browser to its
// login page. Never execute or automatically open an untrusted Location header.
// MirrorOS: neverssl.com exists for this and is not HSTS-preloaded, so the
// browser keeps plain HTTP and the portal can intercept it.
var captivePortalUrl = "http://neverssl.com/"

function connectivityState(kind, connectivity, states, checksEnabled) {
  if (kind === "disconnected") return "none"
  // Ignore stale cached results when the operator has disabled probing.
  if (!checksEnabled) return "unknown"
  if (connectivity === states.Portal) return "portal"
  if (connectivity === states.Limited) return "limited"
  if (connectivity === states.Full) return "full"
  if (connectivity === states.None) return "none"
  return "unknown"
}

function connectionIcon(kind, signalStrength, connectivity) {
  var restricted = connectivity === "portal" || connectivity === "limited"
  if (kind === "wifi") return restricted ? "󰤩" : wifiIconFor(signalStrength)
  if (kind === "ethernet") return restricted ? "󰈂" : "󰈀"
  return "󰤮"
}

function formatHeaderSpeed(mbps, fmt) {
  var f = formatter(fmt)
  var v = parseInt(mbps, 10)
  if (!v || v < 0) return ""
  if (v >= 1000) return f(v / 1000, v % 1000 === 0 ? 0 : 1) + "gbit"
  return f(v) + "mbit"
}

function formatHeaderFreq(mhz, fmt) {
  var f = formatter(fmt)
  var v = parseFloat(mhz)
  if (!v) return ""

  if (v >= 2400 && v < 2500) return f(2.4) + "ghz"
  if (v >= 4900 && v < 5925) return f(5) + "ghz"
  if (v >= 5925 && v < 7125) return f(6) + "ghz"
  if (v >= 57000 && v < 71000) return f(60) + "ghz"

  var ghz = v / 1000
  return f(ghz, ghz % 1 === 0 ? 0 : 1) + "ghz"
}

// Wi-Fi band state belongs in the selector section, not beside the hero name.
// Ethernet has no equivalent selector, so keep its negotiated link speed here.
function headerDetail(info, fmt) {
  var value = info || {}
  if (value.type === "ethernet") return formatHeaderSpeed(value.speed || "", fmt)
  return ""
}

function bandLabel(band, tr, fmt) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  if (band === "auto") return t("network.bandAuto", "Auto")
  if (!band) return ""
  // The band stays the script's "2.4" everywhere else; only the label is
  // written in the language's digits.
  var number = Number(band)
  return (isFinite(number) ? formatter(fmt)(number) : band) + "ghz"
}

// Under Automatic the pills are hidden, so the header carries the live band
// instead -- "WI-FI BAND: 2.4GHZ". Once a band is pinned the pills are on
// screen and say it themselves, so the header drops back to a plain label.
function bandSectionTitle(selected, current, tr, fmt) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  if (selected !== "auto") return t("network.wifiBand", "WI-FI BAND")

  var label = bandLabel(current, tr, fmt)
  if (label === "") return t("network.wifiBand", "WI-FI BAND")

  return t("network.wifiBandCurrent", "WI-FI BAND: %1").replace("%1", label.toUpperCase())
}

// MirrorOS: the three band states stay distinct. The chosen band (profile band
// or Automatic) is the only filled pill, the radio's current band is a
// separate marker, and while a switch runs the target pill alone is filled and
// marked switching while every pill is dimmed and ignores activation. Keyboard
// focus is drawn by the view as an outline and is not part of this state.
function bandPillState(band, selected, current, pending) {
  var busy = !!pending
  return {
    filled: busy ? band === pending : band === (selected || "auto"),
    current: !!current && band === current,
    switching: busy && band === pending,
    dimmed: busy,
    enabled: !busy
  }
}

function bandTooltip(band, tr, fmt) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  if (band === "auto") return t("network.bandAutoTooltip", "Let Wi-Fi pick the band")
  if (!band) return ""
  return t("network.stayOnBand", "Stay on %1").replace("%1", bandLabel(band, tr, fmt))
}

function parseBandStatus(raw) {
  var next = parseKeyValue(raw)
  var tokens = String(next.available || "").split(" ")
  var available = []

  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i] !== "") available.push(tokens[i])
  }

  return {
    band: next.band || "",
    selected: next.selected || "auto",
    available: available
  }
}

function decodeIwSsid(value) {
  var raw = String(value || "")

  try {
    var encoded = ""

    for (var i = 0; i < raw.length; i++) {
      if (raw[i] === "\\" && raw[i + 1] === "x" && /^[0-9a-f]{2}$/i.test(raw.substring(i + 2, i + 4))) {
        var hex = raw.substring(i + 2, i + 4)
        var byte = parseInt(hex, 16)
        encoded += byte < 32 || byte === 127 ? encodeURIComponent(raw.substring(i, i + 4)) : "%" + hex
        i += 3
      } else {
        encoded += encodeURIComponent(raw[i])
      }
    }

    return decodeURIComponent(encoded)
  } catch (error) {
    return raw
  }
}

function parseKeyValue(raw) {
  var next = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (!line) continue
    var idx = line.indexOf("\t")
    if (idx === -1) continue
    var key = line.substring(0, idx)
    var value = line.substring(idx + 1)
    next[key] = key === "ssid" ? decodeIwSsid(value) : value.trim()
  }
  return next
}

function throughputState(previous, next, now) {
  var prev = previous || {}
  var sample = next || {}
  var iface = sample.iface || ""
  var rx = parseFloat(sample.rx_bytes || "0")
  var tx = parseFloat(sample.tx_bytes || "0")
  var previousTime = Number(prev.prevSampleTime || 0)

  if (iface !== (prev.prevIface || "") || previousTime === 0) {
    return {
      prevIface: iface,
      prevRxBytes: rx,
      prevTxBytes: tx,
      prevSampleTime: now,
      downloadRate: 0,
      uploadRate: 0
    }
  }

  var downloadRate = Number(prev.downloadRate || 0)
  var uploadRate = Number(prev.uploadRate || 0)
  var dt = now - previousTime
  if (dt > 0) {
    downloadRate = Math.max(0, (rx - Number(prev.prevRxBytes || 0)) / dt)
    uploadRate = Math.max(0, (tx - Number(prev.prevTxBytes || 0)) / dt)
  }

  return {
    prevIface: iface,
    prevRxBytes: rx,
    prevTxBytes: tx,
    prevSampleTime: now,
    downloadRate: downloadRate,
    uploadRate: uploadRate
  }
}

function pingSampleValue(raw) {
  var value = parseFloat(raw)
  if (!isFinite(value) || value < 0) return null
  return value
}

function appendPingSample(samples, raw, limit) {
  var values = Array.isArray(samples) ? samples.slice() : []

  values.push(pingSampleValue(raw))
  while (values.length > limit) values.shift()

  return values
}

function averagePingLatency(samples, limit) {
  var values = Array.isArray(samples) ? samples : []
  var sampleLimit = Math.max(1, parseInt(limit, 10) || values.length || 1)
  var total = 0
  var count = 0

  for (var i = Math.max(0, values.length - sampleLimit); i < values.length; i++) {
    var value = values[i]
    if (typeof value !== "number" || !isFinite(value) || value < 0) continue
    total += value
    count++
  }

  return count > 0 ? total / count : -1
}

function pingPacketLossPercent(samples) {
  var values = Array.isArray(samples) ? samples : []
  if (values.length === 0) return 0

  var lost = 0
  for (var i = 0; i < values.length; i++) {
    if (values[i] === null) lost++
  }

  return Math.round((lost / values.length) * 100)
}

// Ping and loss only mean something once the internet is reachable. Behind a
// portal, on a limited link or offline every probe is lost by design, so the
// rows read "--" instead of a "Timeout" and "100%" that just restate that.
function internetPingReadable(samples, connectivity) {
  var values = Array.isArray(samples) ? samples : []
  if (connectivity === "portal" || connectivity === "limited" || connectivity === "none") return false
  return values.length > 0
}

function formatPacketLoss(percent, hasSamples, fmt) {
  var f = formatter(fmt)
  if (hasSamples === false) return "--"

  var value = parseInt(percent, 10)
  if (!value || value < 0) return f(0) + "%"
  return f(value) + "%"
}

function pingLatencyState(previous, next, limit, averageLimit) {
  var prev = previous || {}
  var sample = next || {}
  var iface = sample.iface || ""
  var window = Math.max(1, parseInt(limit, 10) || 5)
  var averageWindow = Math.max(1, parseInt(averageLimit, 10) || window)
  var reset = iface === "" || iface !== (prev.pingIface || "")
  var routerSamples = reset ? [] : prev.routerPingSamples
  var internetSamples = reset ? [] : prev.internetPingSamples

  routerSamples = sample.router_ping_ms === undefined ? [] : appendPingSample(routerSamples, sample.router_ping_ms, window)
  internetSamples = sample.internet_ping_ms === undefined ? [] : appendPingSample(internetSamples, sample.internet_ping_ms, window)

  return {
    pingIface: iface,
    routerPingSamples: routerSamples,
    internetPingSamples: internetSamples,
    routerPingLatency: averagePingLatency(routerSamples, averageWindow),
    internetPingLatency: averagePingLatency(internetSamples, averageWindow),
    internetPingPacketLoss: pingPacketLossPercent(internetSamples)
  }
}

// MirrorOS (ADR 0028): a single lost probe is noise, so loss reads as urgent
// only once the window holds enough samples and the loss is material.
var packetLossMinSamples = 10
var packetLossUrgentPercent = 10

function packetLossUrgent(samples) {
  var values = Array.isArray(samples) ? samples : []
  if (values.length < packetLossMinSamples) return false
  return pingPacketLossPercent(values) >= packetLossUrgentPercent
}

function formatBytes(bytes, fmt) {
  var f = formatter(fmt)
  var n = Number(bytes)
  if (!isFinite(n) || n < 0) n = 0
  if (n < 1024) return f(Math.round(n)) + " B"
  if (n < 1024 * 1024) return f(n / 1024, 1) + " KB"
  if (n < 1024 * 1024 * 1024) return f(n / (1024 * 1024), 1) + " MB"
  return f(n / (1024 * 1024 * 1024), 2) + " GB"
}

function formatRate(bytesPerSec, fmt) {
  return formatBytes(bytesPerSec, fmt) + "/s"
}

// `hasSamples` false means no probe has come back yet, which is different from
// a probe that timed out. The rows stay mounted through that gap and read "--"
// so the grid doesn't reflow a second after the panel opens.
function formatPingLatency(ms, hasSamples, tr, fmt) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  var f = formatter(fmt)
  if (hasSamples === false) return "--"

  var value = parseFloat(ms)
  if (!isFinite(value) || value < 0) return t("network.timeout", "Timeout")
  return f(value, value > 0 && value < 10 ? 1 : 0) + " ms"
}

function wifiRow(network) {
  if (!network) return null
  // Primitives only: rows become list-model data, so a WifiNetwork here puts a
  // live QObject wrapper in every delegate's var property. NetworkManager churn
  // (scans, AP removals) can destroy the object while a delegate is still
  // incubating, which segfaults quickshell in wrap_slowPath on the dangling
  // wrapper. Callers that need the object resolve it via networkForSsid().
  return {
    connected: !!network.connected,
    known: !!network.known,
    ssid: network.name || "",
    signal: Math.round((network.signalStrength || 0) * 100),
    security: network.security
  }
}

function sortWifiRows(rows) {
  var nets = Array.isArray(rows) ? rows.slice() : []
  nets.sort(function(a, b) {
    if (a.connected !== b.connected) return a.connected ? -1 : 1
    if (a.known !== b.known) return a.known ? -1 : 1
    return b.signal - a.signal
  })
  return nets
}

function wifiSectionTitle(wifiNetworks, index, tr) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  var networks = Array.isArray(wifiNetworks) ? wifiNetworks : []
  if (index < 0 || index >= networks.length) return ""

  var net = networks[index]
  if (!net) return ""

  if (net.known && index === 0) return t("network.knownNetworks", "KNOWN NETWORKS")
  if (!net.known && (index === 0 || (networks[index - 1] && networks[index - 1].known))) return t("network.otherNetworks", "OTHER NETWORKS")
  return ""
}

// OWE (Enhanced Open) encrypts traffic without authenticating the user, so it
// has no credentials to collect. The panel's lock is a credentials-required
// affordance, so OWE should neither show it nor open its attached prompt.
function requiresCredentials(security, openSecurity, oweSecurity) {
  // Only explicit passwordless types bypass the prompt. Unknown security
  // stays credentialed as the conservative fallback.
  return security !== openSecurity && security !== oweSecurity
}

function canForgetNetwork(network) {
  return !!(network && network.known && !network.connected)
}

// MirrorOS: DNS changes are persistent and per profile, so preset pills only
// ask for confirmation. Custom changes nothing until the terminal it opens
// reads servers, so it needs no in-panel confirmation.
function dnsNeedsConfirmation(provider) {
  return provider === "DHCP" || provider === "Cloudflare" || provider === "Google"
}

// A pending confirmation names one profile; it no longer applies once the
// header shows a different (or no) active profile.
function dnsConfirmationValid(confirmation, currentUuid) {
  if (!confirmation || !confirmation.uuid || !confirmation.provider) return false
  if (!dnsNeedsConfirmation(confirmation.provider)) return false
  return confirmation.uuid === (currentUuid || "")
}

function networkFailureReason(reason, needsCredentials, reasons, tr) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  var r = reasons || {}
  if (needsCredentials && reason === r.NoSecrets) return t("network.passphraseRequired", "Passphrase required")
  if (needsCredentials && reason === r.WifiAuthTimeout) return t("network.wrongPassword", "Wrong password")
  if (reason === r.WifiNetworkLost) return t("network.networkLost", "Network lost")
  if (reason === r.WifiClientDisconnected) return t("network.disconnected", "Disconnected")
  if (reason === r.WifiClientFailed) return t("network.connectionFailed", "Connection failed")
  return t("network.failedToConnect", "Failed to connect")
}

// Whether a failed connect should reopen the passphrase prompt. NoSecrets
// means credentials are missing only for a network that actually uses them.
// An auth timeout on such a network means the saved passphrase is wrong (the
// same profile a first failed attempt leaves behind as "known"), so the user
// needs a chance to re-enter it -- connectWithPsk overwrites the stored PSK on
// submit.
function shouldRepromptPassphrase(reason, needsCredentials, reasons) {
  var r = reasons || {}
  if (!needsCredentials) return false
  return reason === r.NoSecrets || reason === r.WifiAuthTimeout
}

// MirrorOS-owned VPN section helpers (ADR 0025 G8, plan 02-30); no upstream
// source. They read `vpn-profile list` output and drive the row actions. No
// credential passes through them: Connect only opens vpn-connect in Foot.
var vpnStates = ["inactive", "activating", "active", "deactivating"]
var vpnUuidPattern = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/

// One "<uuid>\t<state>\t<name>" line per profile; vpn-profile already turns
// control characters in names into '?', so a valid line has exactly 3 fields.
// Malformed lines and unknown states are dropped, keeping the listed order.
function parseVpnProfiles(text) {
  var rows = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    if (lines[i] === "") continue
    var fields = lines[i].split("\t")
    if (fields.length !== 3) continue
    if (!vpnUuidPattern.test(fields[0])) continue
    if (vpnStates.indexOf(fields[1]) < 0) continue
    if (fields[2] === "") continue
    rows.push({ uuid: fields[0], state: fields[1], name: fields[2] })
  }
  return rows
}

// One VPN at a time (DEC-083). anyBusy: some profile is active or activating.
// pendingUuid: the profile with a Disconnect in flight ("" when none); while
// it runs every row is inert and repeats are ignored.
function vpnRowAction(state, anyBusy, pendingUuid, uuid) {
  if (pendingUuid) return "none"
  if (state === "active") return "disconnect"
  if (state === "inactive") return anyBusy ? "none" : "connect"
  return "none"
}

function vpnStateLabel(state) {
  if (state === "active") return "Connected"
  if (state === "activating") return "Connecting\u2026"
  if (state === "deactivating") return "Disconnecting\u2026"
  return ""
}

// vpn-profile disconnect exit codes: 5 still active after the wait, 4
// NetworkManager unavailable.
function vpnDisconnectFailure(exitCode) {
  if (exitCode === 5) return "Still connected: disconnect not authorized"
  if (exitCode === 4) return "NetworkManager unavailable"
  return "Disconnect failed"
}

// Foot wrapper for `bash -c <script> vpn-connect <command> <uuid>`: $1 is the
// vpn-connect path and $2 the profile UUID; 6 is a cancelled authentication.
var vpnConnectScript = "\"$1\" \"$2\"; code=$?; echo; "
  + "if (( code == 0 )); then echo Connected; elif (( code == 6 )); then echo Cancelled; else echo Failed; fi; read -rsn1"

if (typeof module !== "undefined") {
  module.exports = {
    parseNetworkStatus: parseNetworkStatus,
    wifiIconFor: wifiIconFor,
    connectionIcon: connectionIcon,
    connectedSignalStrength: connectedSignalStrength,
    parseActiveApSignal: parseActiveApSignal,
    connectivityState: connectivityState,
    captivePortalUrl: captivePortalUrl,
    formatHeaderSpeed: formatHeaderSpeed,
    formatHeaderFreq: formatHeaderFreq,
    headerDetail: headerDetail,
    bandLabel: bandLabel,
    bandSectionTitle: bandSectionTitle,
    bandTooltip: bandTooltip,
    parseBandStatus: parseBandStatus,
    decodeIwSsid: decodeIwSsid,
    parseKeyValue: parseKeyValue,
    throughputState: throughputState,
    pingLatencyState: pingLatencyState,
    pingPacketLossPercent: pingPacketLossPercent,
    internetPingReadable: internetPingReadable,
    formatPacketLoss: formatPacketLoss,
    formatBytes: formatBytes,
    formatRate: formatRate,
    formatPingLatency: formatPingLatency,
    wifiRow: wifiRow,
    sortWifiRows: sortWifiRows,
    wifiSectionTitle: wifiSectionTitle,
    requiresCredentials: requiresCredentials,
    canForgetNetwork: canForgetNetwork,
    packetLossUrgent: packetLossUrgent,
    bandPillState: bandPillState,
    dnsNeedsConfirmation: dnsNeedsConfirmation,
    dnsConfirmationValid: dnsConfirmationValid,
    networkFailureReason: networkFailureReason,
    shouldRepromptPassphrase: shouldRepromptPassphrase,
    parseVpnProfiles: parseVpnProfiles,
    vpnRowAction: vpnRowAction,
    vpnStateLabel: vpnStateLabel,
    vpnDisconnectFailure: vpnDisconnectFailure,
    vpnConnectScript: vpnConnectScript
  }
}
