// MirrorOS-owned menu model. Same item schema, ids, labels, aliases, icons and
// order as the matching rows of Omarchy default/omarchy/omarchy-menu.jsonc at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9, restricted to Apps, Learn >
// Keybindings and System, plus the approved background rows from the installed
// reference recorded in UPSTREAM.md. Not a user-editable file: there is no extension file
// and no new configuration format.
//
// Differences from upstream rows:
// - `apps` has no action: upstream's root Apps row runs the dock app grid
//   (`omarchy-shell omarchy.dock apps`); here it is the Apps submenu.
// - Actions are ids from a closed table interpreted by Menu.qml
//   (`session:<name>`, `help:keybindings`), never command text. Session rows
//   carry no `when:` guard; SessionActions supplies availability instead.
// - `system.screensaver` and the other Learn rows are excluded.

var ITEMS = [
  ["apps", { icon: "\u{F003B}", label: "Apps", aliases: ["app", "applications"], provider: "apps" }],
  ["learn", { icon: "\u{F09D1}", label: "Learn" }],
  ["style", { icon: "\uEBCF", label: "Style" }],
  ["install", { icon: "\u{F0249}", label: "Install" }],
  ["system", { icon: "\uF011", label: "System", aliases: ["power-menu"] }],

  ["system.lock", { icon: "\uF023", label: "Lock", action: "session:lock" }],
  ["system.suspend", { icon: "\u{F04B2}", label: "Suspend", action: "session:suspend" }],
  ["system.hibernate", { icon: "\u{F0901}", label: "Hibernate", action: "session:hibernate" }],
  ["system.logout", { icon: "\u{F0343}", label: "Logout", action: "session:logout" }],
  ["system.reboot", { icon: "\u{F0709}", label: "Reboot", action: "session:reboot" }],
  ["system.shutdown", { icon: "\u{F0425}", label: "Shutdown", action: "session:shutdown" }],

  ["learn.keybindings", { icon: "\uF11C", label: "Keybindings", action: "help:keybindings" }],
  ["style.background", { icon: "\uF03E", label: "Background", aliases: ["background", "wallpaper"], action: "wallpaper:open" }],
  ["install.style", { icon: "\uEBCF", label: "Style" }],
  ["install.style.background", { icon: "\uF03E", label: "Background", action: "wallpaper:install" }]
]

// Closed action table: the only values an item's `action` may hold.
var ACTIONS = ["session:lock", "session:suspend", "session:hibernate", "session:logout",
  "session:reboot", "session:shutdown", "help:keybindings", "wallpaper:open", "wallpaper:install"]

function rawItems() {
  return ITEMS.map(function(pair) { return [pair[0], pair[1]] })
}

function isKnownAction(action) {
  return ACTIONS.indexOf(String(action || "")) >= 0
}

if (typeof module !== "undefined") {
  module.exports = { rawItems: rawItems, isKnownAction: isKnownAction, actions: ACTIONS }
}
