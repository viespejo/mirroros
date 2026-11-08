#!/usr/bin/bash
# Session check for shell panels: native IPC targets, global shortcut dispatch, focused-monitor routing and Tab
# switching. Runs an isolated copy of the shell with synthetic HOME/XDG state; never on the daily session.
set -Eeuo pipefail
tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shell_dir=$(cd "$tests_dir/../../../../capabilities/desktop/shell" && pwd)
for tool in node qs hyprctl busctl; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
node "$tests_dir/qmllint-check.mjs"
if [[ -z "${WAYLAND_DISPLAY:-}" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED no reachable Wayland session\n'; exit 2
fi
tmp=$(mktemp -d)
pid=""
cleanup() {
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
    rm -rf "$tmp"
}
trap cleanup EXIT
run_dir="$tmp/shell"
cp -r "$shell_dir" "$run_dir"
mkdir -p "$tmp/home" "$tmp/config" "$tmp/data/applications" "$tmp/state"
node --input-type=module - "$run_dir/shell.qml" <<'JS'
import fs from 'node:fs';
const file = process.argv[2];
let qml = fs.readFileSync(file, 'utf8').replace('import Quickshell\n', 'import Quickshell\nimport Quickshell.Io\n');
qml = qml.trimEnd().slice(0, -1) + `
  IpcHandler {
    target: "panelTest"
    function activeSlot() {
      var b = desktopShell.bar, active = b.activePopout
      for (var i = 0; i < b.moduleSlots.length; i++) {
        var slot = b.moduleSlots[i]
        if (slot && active && (slot.activeItem === active || slot.activeItem === active.owner)) return slot
      }
      return null
    }
    function state(): string {
      var b = desktopShell.bar, slot = activeSlot()
      return JSON.stringify({ configLoaded: desktopShell.shellConfigStore.loaded,
        active: slot ? slot.moduleName : "", screen: slot ? b.slotScreenName(slot) : "",
        focused: b.focusedScreenName(), notificationPanel: !!desktopShell.notificationService.openPanel,
        rightPanels: b.panelNavigationSlots("right", b.focusedScreenName()).map(function(s) { return s.moduleName }) })
    }
    function request(id: string, action: string): string { return desktopShell.bar.requestPanel(id, action) }
    function audioState(): string {
      var b = desktopShell.bar, focused = b.focusedScreenName(), item = null
      for (var i = 0; i < b.moduleSlots.length; i++) {
        var slot = b.moduleSlots[i]
        if (slot && slot.moduleName === "omarchy.audio" && slot.activeItem && (!item || b.slotScreenName(slot) === focused))
          item = slot.activeItem
      }
      if (!item) return JSON.stringify({ present: false })
      return JSON.stringify({ present: true, opened: item.opened, hasOutput: item.hasOutput, unavailable: item.unavailable,
        sinks: item.displayAudioSinks.map(function(row) { return row.name }) })
    }
    function panelItem(id) {
      var b = desktopShell.bar, focused = b.focusedScreenName(), item = null
      for (var i = 0; i < b.moduleSlots.length; i++) {
        var slot = b.moduleSlots[i]
        if (slot && slot.moduleName === id && slot.activeItem && (!item || b.slotScreenName(slot) === focused))
          item = slot.activeItem
      }
      return item
    }
    function displayState(): string {
      var item = panelItem("omarchy.monitor")
      if (!item) return JSON.stringify({ present: false })
      return JSON.stringify({ present: true, opened: item.opened, brightnessAvailable: item.brightnessAvailable,
        focusedMonitor: item.focusedMonitor, internalMonitor: item.internalMonitor,
        displays: item.displays.map(function(d) { return d.name }),
        toggleable: item.displays.filter(function(d) { return item.canToggle(d) }).map(function(d) { return d.name }) })
    }
    function powerState(): string {
      var item = panelItem("omarchy.power")
      if (!item) return JSON.stringify({ present: false })
      return JSON.stringify({ present: true, opened: item.opened, batteryPresent: item.batteryPresent,
        profiles: item.profiles, activeProfile: item.activeProfile })
    }
    function tab(direction: int): string {
      var slot = activeSlot()
      return slot && desktopShell.bar.switchPanelFrom(slot.activeItem, direction) ? "ok" : "none"
    }
  }
}
`;
fs.writeFileSync(file, qml);
JS
call() { qs ipc -p "$run_dir" call "$@"; }
state() { call panelTest state; }
field() { state | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const v=JSON.parse(s)[process.argv[1]];console.log(Array.isArray(v)?v.join(" "):String(v))})' "$1"; }
await_field() {
    local actual=""
    for ((i = 0; i < 50; i++)); do
        actual=$(field "$1")
        [[ "$actual" == "$2" ]] && return
        sleep 0.1
    done
    printf 'FAIL %s expected "%s", got "%s"\n' "$1" "$2" "$actual"; exit 1
}
global() { hyprctl dispatch "hl.dsp.global(\"mirroros:$1\")" >/dev/null; }

owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications)
[[ "$owner" == 'b false' ]] || { printf 'BLOCKED Notifications already owned (shell running); no replacement attempted\n'; exit 2; }
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" \
    MIRROROS_SHELL_STATE_DIR="$tmp/state" qs -p "$run_dir" > "$tmp/shell.log" 2>&1 &
pid=$!
for ((i = 0; i < 100; i++)); do
    [[ "$(field configLoaded 2>/dev/null)" == true ]] && break
    sleep 0.1
done
[[ "$(field configLoaded)" == true ]] || { printf 'FAIL shell did not become ready\n'; cat "$tmp/shell.log"; exit 1; }

# Panel targets are declared once for the whole shell, never per bar instance.
qs ipc -p "$run_dir" show > "$tmp/targets.txt"
for target in audio display power; do
    count=$(grep -c "^target $target\$" "$tmp/targets.txt" || true)
    [[ "$count" == 1 ]] || { printf 'FAIL target %s declared %s times\n' "$target" "$count"; exit 1; }
done
printf 'PASS panel IPC targets audio, display and power declared once\n'

# An absent panel answers unavailable without opening anything.
[[ "$(call panelTest request omarchy.absent open)" == unavailable ]] || { printf 'FAIL absent panel not unavailable\n'; exit 1; }
await_field active ""
printf 'PASS absent panel reports unavailable\n'

# Notification panel through the Hyprland global dispatcher (no process spawned by the key path).
global panel.notifications
await_field notificationPanel true
global panel.notifications
await_field notificationPanel false
printf 'PASS mirroros:panel.notifications toggles the notification panel\n'

panel_field() { call panelTest "$1" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const v=JSON.parse(s)[process.argv[1]];console.log(Array.isArray(v)?v.join(" "):String(v))})' "$2"; }

# Power panel: without a battery it never opens (and no statistics process exists to run).
targets=(audio display power)
if [[ "$(panel_field powerState present)" == true && "$(panel_field powerState batteryPresent)" == false ]]; then
    call power open >/dev/null
    sleep 0.5
    [[ "$(panel_field powerState opened)" == false ]] || { printf 'FAIL power panel opened without a battery\n'; exit 1; }
    await_field active ""
    printf 'PASS power panel does not open without a battery\n'
    targets=(audio display)
fi

declare -A ids=([audio]=omarchy.audio [display]=omarchy.monitor [power]=omarchy.power)
available=()
for target in "${targets[@]}"; do
    result=$(call "$target" open)
    if [[ "$result" == unavailable ]]; then
        printf 'NOT EXERCISED %s panel absent in this shell (unavailable)\n' "$target"; continue
    fi
    [[ "$result" == opened ]] || { printf 'FAIL %s open returned %s\n' "$target" "$result"; exit 1; }
    await_field active "${ids[$target]}"
    await_field screen "$(field focused)"
    [[ "$(call "$target" close)" == closed ]] && await_field active ""
    [[ "$(call "$target" toggle)" == opened ]] && await_field active "${ids[$target]}"
    [[ "$(call "$target" toggle)" == closed ]] && await_field active ""
    global "panel.$target"
    await_field active "${ids[$target]}"
    global "panel.$target"
    await_field active ""
    available+=("$target")
    printf 'PASS %s open/close/toggle by IPC and mirroros:panel.%s on the focused monitor\n' "$target" "$target"
done

# Audio panel: the WirePlumber dummy sink is never listed; without an output the panel opens unavailable with no rows.
audio_field() { call panelTest audioState | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const v=JSON.parse(s)[process.argv[1]];console.log(Array.isArray(v)?v.join(" "):String(v))})' "$1"; }
if [[ " ${available[*]} " == *" audio "* ]]; then
    [[ "$(call audio open)" == opened ]] && await_field active omarchy.audio
    sleep 0.3
    sinks=$(audio_field sinks)
    [[ " $sinks " != *" auto_null "* ]] || { printf 'FAIL audio panel lists the WirePlumber dummy sink\n'; exit 1; }
    if [[ "$(audio_field hasOutput)" == false ]]; then
        [[ -z "$sinks" ]] || { printf 'FAIL audio panel without output lists outputs: %s\n' "$sinks"; exit 1; }
        printf 'PASS audio panel opens unavailable without an output (no output rows or slider)\n'
    else
        [[ -n "$sinks" ]] || { printf 'FAIL audio panel with an output lists no device\n'; exit 1; }
        printf 'PASS audio panel lists outputs without the dummy sink\n'
    fi
    [[ "$(call audio toggle)" == closed ]] && await_field active ""
fi

# Display panel: read-only state from `display state`; brightness only for the focused internal panel; the last
# independent output is not offered for disabling. No output or scale change is made here.
if [[ " ${available[*]} " == *" display "* ]]; then
    [[ "$(call display open)" == opened ]] && await_field active omarchy.monitor
    for ((i = 0; i < 30; i++)); do [[ -n "$(panel_field displayState displays)" ]] && break; sleep 0.1; done
    read -r -a outputs <<< "$(panel_field displayState displays)"
    (( ${#outputs[@]} > 0 )) || { printf 'FAIL display panel lists no output\n'; exit 1; }
    [[ "$(panel_field displayState focusedMonitor)" == "$(field focused)" ]] ||
        { printf 'FAIL display panel focused output differs from Hyprland\n'; exit 1; }
    if [[ "$(panel_field displayState brightnessAvailable)" == true ]]; then
        [[ "$(panel_field displayState focusedMonitor)" == "$(panel_field displayState internalMonitor)" ]] ||
            { printf 'FAIL brightness offered for an external display\n'; exit 1; }
    fi
    if (( ${#outputs[@]} == 1 )); then
        [[ -z "$(panel_field displayState toggleable)" ]] || { printf 'FAIL single output offered for disabling\n'; exit 1; }
        printf 'PASS display panel reads state and protects the single output\n'
    else
        printf 'PASS display panel reads state for %s outputs (guard with several outputs is a manual check)\n' "${#outputs[@]}"
    fi
    [[ "$(call display toggle)" == closed ]] && await_field active ""
fi

if [[ " ${available[*]} " == *" power "* ]]; then
    [[ "$(call power open)" == opened ]] && await_field active omarchy.power
    [[ -n "$(panel_field powerState profiles)" ]] || { printf 'FAIL power panel lists no profile\n'; exit 1; }
    printf 'PASS power panel opens with a battery and lists profiles (%s)\n' "$(panel_field powerState profiles)"
    [[ "$(call power toggle)" == closed ]] && await_field active ""
fi

if (( ${#available[@]} >= 2 )); then
    read -r -a order <<< "$(field rightPanels)"
    call panelTest request "${order[0]}" open >/dev/null
    await_field active "${order[0]}"
    [[ "$(call panelTest tab 1)" == ok ]] && await_field active "${order[1]}"
    [[ "$(call panelTest tab -1)" == ok ]] && await_field active "${order[0]}"
    global panel-at-2
    await_field active "${order[1]}"
    global panel-at-2
    await_field active ""
    printf 'PASS Tab, Shift+Tab and mirroros:panel-at-N follow the right section of the focused monitor\n'
else
    printf 'NOT EXERCISED Tab switching and panel-at-N need at least two panels\n'
fi
printf 'PASS panel session checks\n'
