// MirrorOS SDDM theme logic. Pure functions over plain values copied from SDDM's native models, so they can be
// tested under Node.js without Qt. No credentials pass through this file.

// The last successful user when still listed, otherwise the first listed user; -1 when no account is listed.
function initialUserIndex(names, lastUser) {
  var last = names.indexOf(lastUser || "");
  if (last >= 0) return last;
  return names.length > 0 ? 0 : -1;
}

// The index of the configured session file; -1 unless exactly one listed session has that exact path.
function sessionIndex(files, configured) {
  var found = -1;
  if (!configured) return -1;
  for (var i = 0; i < files.length; i++) {
    if (files[i] !== configured) continue;
    if (found >= 0) return -1;
    found = i;
  }
  return found;
}

// SDDM's layout name when its keyboard model publishes one; its Wayland backend publishes none, so the label of the
// layout resolved by configure for the greeter is shown instead.
function layoutLabel(names, current, fallback) {
  if (current >= 0 && current < names.length && names[current]) return names[current];
  return fallback || "";
}

// The active layout recorded by the greeter compositor (ADR 0015): the first line of the state file when it is a short
// layout label, otherwise empty so the configured label is shown.
function stateLabel(text) {
  var line = String(text || "").split("\n")[0].trim();
  return /^[A-Za-z0-9 ()'._-]{1,64}$/.test(line) ? line : "";
}

function displayName(name, realName) {
  return realName ? realName : name;
}

// An actionable message for the unavailable state; empty when login can be attempted.
function unavailableReason(userIndex, session) {
  if (userIndex < 0) return "No user account is available for login.";
  if (session < 0) return "The MirrorOS session is unavailable; run mirroros-configure.";
  return "";
}

function canSubmit(userIndex, session, pending, password) {
  return userIndex >= 0 && session >= 0 && !pending && password.length > 0;
}

if (typeof module !== "undefined") {
  module.exports = {
    initialUserIndex: initialUserIndex,
    sessionIndex: sessionIndex,
    layoutLabel: layoutLabel,
    stateLabel: stateLabel,
    displayName: displayName,
    unavailableReason: unavailableReason,
    canSubmit: canSubmit
  };
}
