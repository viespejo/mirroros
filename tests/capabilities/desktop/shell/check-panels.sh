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
vpn_uuid=""
foot_pid=""
cleanup() {
    if [[ -n "$foot_pid" ]]; then kill "$foot_pid" 2>/dev/null || true; fi
    if [[ -n "$vpn_uuid" ]]; then nmcli connection delete uuid "$vpn_uuid" >/dev/null 2>&1 || true; fi
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
    function bluetoothState(): string {
      var item = panelItem("omarchy.bluetooth")
      if (!item) return JSON.stringify({ present: false })
      return JSON.stringify({ present: true, opened: item.opened, visible: item.visible, unavailable: item.unavailable,
        bluezAvailable: item.bluezAvailable, unavailableReason: item.unavailableReason, devices: item.devices.length })
    }
    function networkState(): string {
      var item = panelItem("omarchy.network")
      if (!item) return JSON.stringify({ present: false })
      return JSON.stringify({ present: true, opened: item.opened, networkManagerAvailable: item.networkManagerAvailable,
        wifiStationAvailable: item.wifiStationAvailable, canSelectBand: item.canSelectBand, vpnShown: item.vpnShown,
        vpnProfiles: item.vpnProfiles.map(function(p) { return p.uuid + ":" + p.state }) })
    }
    function networkVpnConnect(uuid: string): string {
      var item = panelItem("omarchy.network")
      if (!item) return "absent"
      item.connectVpn(uuid)
      return "ok"
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
for target in bluetooth network audio display power; do
    count=$(grep -c "^target $target\$" "$tmp/targets.txt" || true)
    [[ "$count" == 1 ]] || { printf 'FAIL target %s declared %s times\n' "$target" "$count"; exit 1; }
done
printf 'PASS panel IPC targets bluetooth, network, audio, display and power declared once\n'

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
await_panel_field() {
    local actual=""
    for ((i = 0; i < 50; i++)); do
        actual=$(panel_field "$1" "$2")
        [[ "$actual" == "$3" ]] && return
        sleep 0.1
    done
    printf 'FAIL %s.%s expected "%s", got "%s"\n' "$1" "$2" "$3" "$actual"; exit 1
}
foot_pids() { hyprctl clients -j | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{for(const c of JSON.parse(s))if(c.class==="foot")console.log(c.pid)})'; }

# Power panel: without a battery it never opens (and no statistics process exists to run).
targets=(network audio display power)
if [[ "$(panel_field powerState present)" == true && "$(panel_field powerState batteryPresent)" == false ]]; then
    call power open >/dev/null
    sleep 0.5
    [[ "$(panel_field powerState opened)" == false ]] || { printf 'FAIL power panel opened without a battery\n'; exit 1; }
    await_field active ""
    printf 'PASS power panel does not open without a battery\n'
    targets=(network audio display)
fi

# Bluetooth panel: hidden while BlueZ runs without an adapter (not counted, not opened); drawn otherwise, including
# the unavailable state.
if [[ "$(panel_field bluetoothState visible)" == true ]]; then
    targets=(bluetooth "${targets[@]}")
else
    printf 'NOT EXERCISED bluetooth panel hidden (BlueZ running without an adapter)\n'
fi

declare -A ids=([bluetooth]=omarchy.bluetooth [network]=omarchy.network [audio]=omarchy.audio [display]=omarchy.monitor [power]=omarchy.power)
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

# Network panel: the unavailable state follows NetworkManager's bus name; without a Wi-Fi device no band section.
# NetworkManager is never stopped here (root); the stopped case is a manual laboratory step.
if [[ " ${available[*]} " == *" network "* ]]; then
    [[ "$(call network open)" == opened ]] && await_field active omarchy.network
    sleep 0.5
    nm=$(busctl --system call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.NetworkManager)
    if [[ "$nm" == 'b true' ]]; then
        [[ "$(panel_field networkState networkManagerAvailable)" == true ]] ||
            { printf 'FAIL network panel unavailable while NetworkManager runs\n'; exit 1; }
        printf 'PASS network panel available with NetworkManager running\n'
        printf 'NOT EXERCISED network panel unavailable state (NetworkManager running; manual step)\n'
        if ! nmcli -t -f TYPE device 2>/dev/null | grep -qx wifi; then
            [[ "$(panel_field networkState wifiStationAvailable)" == false &&
               "$(panel_field networkState canSelectBand)" == false ]] ||
                { printf 'FAIL Wi-Fi or band section without a Wi-Fi device\n'; exit 1; }
            printf 'PASS no Wi-Fi or band section without a Wi-Fi device\n'
        fi
        # VPN section (plan 02-30): hidden without OpenConnect profiles and shown with a fictitious one; Connect opens
        # Foot running vpn-connect and closes the panel. The fictitious profile has no secret flags, so vpn-connect
        # refuses it (exit 4) before reading input and leaves it unchanged; the Foot window is then closed.
        vpn_profile=/usr/share/mirroros/hardware/vpn-profile
        if [[ ! -x "$vpn_profile" ]]; then
            printf 'NOT EXERCISED network panel VPN section (vpn-profile not delivered)\n'
        elif [[ -n "$("$vpn_profile" list)" ]]; then
            printf 'NOT EXERCISED network panel VPN section (OpenConnect profiles already exist)\n'
        else
            sleep 2.5
            await_panel_field networkState vpnShown false
            printf 'PASS network panel VPN section hidden without OpenConnect profiles\n'
            vpn_uuid=$(cat /proc/sys/kernel/random/uuid)
            if ! nmcli connection add type vpn vpn-type openconnect con-name mirroros-check-vpn \
                connection.uuid "$vpn_uuid" connection.autoconnect no connection.permissions "user:$USER" \
                vpn.data 'gateway = vpn.example.invalid, protocol = anyconnect' >/dev/null 2>&1; then
                vpn_uuid=""
                printf 'NOT EXERCISED network panel VPN section with a profile (could not add a fictitious profile)\n'
            else
                await_panel_field networkState vpnShown true
                await_panel_field networkState vpnProfiles "$vpn_uuid:inactive"
                printf 'PASS network panel VPN section shown with a fictitious OpenConnect profile\n'
                before=$(foot_pids)
                [[ "$(call panelTest networkVpnConnect "$vpn_uuid")" == ok ]] ||
                    { printf 'FAIL network panel VPN Connect not reachable\n'; exit 1; }
                await_field active ""
                for ((i = 0; i < 50; i++)); do
                    foot_pid=$(comm -13 <(sort <<< "$before") <(foot_pids | sort) | head -n1)
                    [[ -n "$foot_pid" ]] && break
                    sleep 0.1
                done
                [[ -n "$foot_pid" ]] || { printf 'FAIL VPN Connect opened no Foot window\n'; exit 1; }
                kill "$foot_pid" 2>/dev/null || true
                foot_pid=""
                printf 'PASS VPN Connect opens a Foot window and closes the panel\n'
                [[ "$(call network open)" == opened ]] && await_field active omarchy.network
                nmcli connection delete uuid "$vpn_uuid" >/dev/null
                vpn_uuid=""
                await_panel_field networkState vpnShown false
                printf 'PASS network panel VPN section hidden again after the profile is deleted\n'
            fi
        fi
    else
        [[ "$(panel_field networkState networkManagerAvailable)" == false ]] ||
            { printf 'FAIL network panel available without NetworkManager\n'; exit 1; }
        printf 'PASS network panel opens unavailable without NetworkManager\n'
        [[ "$(panel_field networkState vpnShown)" == false ]] ||
            { printf 'FAIL network panel VPN section shown without NetworkManager\n'; exit 1; }
        printf 'PASS network panel VPN section hidden without NetworkManager\n'
    fi
    [[ "$(call network toggle)" == closed ]] && await_field active ""
fi

# Bluetooth panel: the unavailable state follows BlueZ's bus name and states the tooltip reason with no devices.
# bluetooth.service is never stopped here (root); without a controller it is not started, which exercises the case.
if [[ " ${available[*]} " == *" bluetooth "* ]]; then
    [[ "$(call bluetooth open)" == opened ]] && await_field active omarchy.bluetooth
    sleep 0.5
    bluez=$(busctl --system call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.bluez)
    if [[ "$bluez" == 'b true' ]]; then
        [[ "$(panel_field bluetoothState bluezAvailable)" == true ]] ||
            { printf 'FAIL bluetooth panel unavailable while BlueZ runs\n'; exit 1; }
        printf 'PASS bluetooth panel available with BlueZ running and an adapter\n'
        printf 'NOT EXERCISED bluetooth panel unavailable state (bluetooth.service running; manual step)\n'
    else
        [[ "$(panel_field bluetoothState unavailable)" == true &&
           "$(panel_field bluetoothState unavailableReason)" == "Bluetooth unavailable: "* &&
           "$(panel_field bluetoothState devices)" == 0 ]] ||
            { printf 'FAIL bluetooth panel without BlueZ is not unavailable with a reason and no devices\n'; exit 1; }
        printf 'PASS bluetooth panel opens unavailable without BlueZ: %s\n' "$(panel_field bluetoothState unavailableReason)"
    fi
    [[ "$(call bluetooth toggle)" == closed ]] && await_field active ""
fi

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
