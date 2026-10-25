// Adapted from Omarchy shell/plugins/panels/network/Model.js at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9 (MIT). Bar-only icon and signal helpers.
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
