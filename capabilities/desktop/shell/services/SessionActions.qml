import QtQuick
import Quickshell
import Quickshell.Io

// MirrorOS session actions for the System menu. New code; behavior reference:
// Omarchy bin/omarchy-system and the System guards of omarchy-menu.jsonc at
// 7075b61c6aaa5d8589f6e816867508fc96dc49d9.
//
// A closed table maps each action to a fixed argv. Availability is probed with
// fixed commands; no command text from the menu model is ever interpreted.
// A provider answering "yes" is a declaration, not proof that the action works.
//
// MIRROROS_SHELL_SESSION_DRY_RUN=<file>, read once at startup, appends one JSON
// line per dispatch ({"action":..., "argv":[...]}) to that file instead of
// executing it. Tests use it to verify dispatch selection without disrupting
// the session.
Item {
  id: root

  readonly property var commands: ({
    lock: ["loginctl", "lock-session"],
    logout: ["uwsm", "stop"],
    suspend: ["systemctl", "suspend"],
    hibernate: ["systemctl", "hibernate"],
    reboot: ["systemctl", "reboot"],
    shutdown: ["systemctl", "poweroff"]
  })
  readonly property var names: ["lock", "suspend", "hibernate", "logout", "reboot", "shutdown"]

  // Captured once; later environment changes do not switch modes.
  property string dryRunPath: ""
  Component.onCompleted: {
    root.dryRunPath = Quickshell.env("MIRROROS_SHELL_SESSION_DRY_RUN") || ""
    root.refresh()
  }

  // name -> { state: "checking" | "available" | "unavailable", reason: string }
  property var states: ({})
  property int revision: 0

  function setState(name, state, reason) {
    var next = ({})
    for (var key in root.states) next[key] = root.states[key]
    next[name] = { state: state, reason: reason || "" }
    root.states = next
    root.revision += 1
  }

  function stateOf(name) {
    return root.states[name] || { state: "checking", reason: "Checking availability…" }
  }

  function available(name) {
    return root.stateOf(name).state === "available"
  }

  // Re-probe every action. Called when the menu opens; a probe still running
  // keeps its previous answer until it finishes.
  function refresh() {
    for (var i = 0; i < root.names.length; i++) {
      var probe = probes[root.names[i]]
      if (probe && !probe.running) probe.running = true
    }
  }

  // Short reasons: the menu shows them in two lines under the label.
  function logindReason(label, answer) {
    if (answer === "yes") return ""
    if (answer === "challenge") return label + " needs authorization (no polkit agent)."
    if (answer === "no" || answer === "na") return "This system reports " + label.toLowerCase() + " is not supported (" + answer + ")."
    return "Could not ask logind whether " + label.toLowerCase() + " is supported."
  }

  function finishLogind(name, label, exitCode, text) {
    var answer = ""
    if (exitCode === 0) {
      try {
        var parsed = JSON.parse(String(text || "").trim())
        if (parsed && Array.isArray(parsed.data)) answer = String(parsed.data[0] || "")
      } catch (e) { answer = "" }
    }
    var reason = root.logindReason(label, answer)
    root.setState(name, reason ? "unavailable" : "available", reason)
  }

  // Returns false when the action is not currently available.
  function run(name) {
    var argv = root.commands[name]
    if (!argv || !root.available(name)) return false
    if (root.dryRunPath) {
      var line = JSON.stringify({ action: name, argv: argv })
      // Data travels as positional parameters; the script text is constant.
      Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" >> "$2"', "sh", line, root.dryRunPath])
      return true
    }
    Quickshell.execDetached(argv)
    return true
  }

  function snapshot() {
    var out = ({})
    for (var i = 0; i < root.names.length; i++) {
      var name = root.names[i]
      var state = root.stateOf(name)
      out[name] = { state: state.state, reason: state.reason, argv: root.commands[name] }
    }
    return { dryRun: root.dryRunPath !== "", actions: out }
  }

  readonly property var probes: ({
    lock: lockProbe,
    logout: logoutProbe,
    suspend: suspendProbe,
    hibernate: hibernateProbe,
    reboot: rebootProbe,
    shutdown: shutdownProbe
  })

  // `loginctl lock-session` only locks when a listener runs the locker, so the
  // probe asks for both the locker and its idle/lock service (the packaged
  // hypridle.service user unit, DEC-023).
  Process {
    id: lockProbe
    command: ["sh", "-c", "command -v hyprlock >/dev/null 2>&1 || exit 3; systemctl --user is-active --quiet hypridle.service || exit 4"]
    onExited: function(exitCode) {
      if (exitCode === 0) root.setState("lock", "available", "")
      else if (exitCode === 3) root.setState("lock", "unavailable", "Install hyprlock to lock the screen.")
      else root.setState("lock", "unavailable", "Start hypridle; it runs the screen locker.")
    }
  }

  Process {
    id: logoutProbe
    command: ["sh", "-c", "command -v uwsm >/dev/null 2>&1 || exit 3; uwsm check is-active >/dev/null 2>&1 || exit 4"]
    onExited: function(exitCode) {
      if (exitCode === 0) root.setState("logout", "available", "")
      else if (exitCode === 3) root.setState("logout", "unavailable", "Install uwsm; logout stops the uwsm session.")
      else root.setState("logout", "unavailable", "Not a uwsm session; log out from the login manager.")
    }
  }

  Process {
    id: suspendProbe
    command: ["busctl", "--json=short", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanSuspend"]
    stdout: StdioCollector { id: suspendOut }
    onExited: function(exitCode) { root.finishLogind("suspend", "Suspend", exitCode, suspendOut.text) }
  }

  Process {
    id: hibernateProbe
    command: ["busctl", "--json=short", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanHibernate"]
    stdout: StdioCollector { id: hibernateOut }
    onExited: function(exitCode) { root.finishLogind("hibernate", "Hibernate", exitCode, hibernateOut.text) }
  }

  Process {
    id: rebootProbe
    command: ["busctl", "--json=short", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanReboot"]
    stdout: StdioCollector { id: rebootOut }
    onExited: function(exitCode) { root.finishLogind("reboot", "Reboot", exitCode, rebootOut.text) }
  }

  Process {
    id: shutdownProbe
    command: ["busctl", "--json=short", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanPowerOff"]
    stdout: StdioCollector { id: shutdownOut }
    onExited: function(exitCode) { root.finishLogind("shutdown", "Shutdown", exitCode, shutdownOut.text) }
  }
}
