#!/usr/bin/env bash
# Prototype-local checks for the shared menu (Story 4.3 prototype, Brief 3):
# tree and direct routes, back navigation, root search with drilldown,
# unavailable session rows and their reasons, session dispatch in dry-run
# mode, and keyboard help rows/dispatch.
#
# Synthetic data only. The menu-only fixture runs with fake `hyprctl`,
# `busctl`, `uwsm`, `systemctl` and (variant locker) `hyprlock` first in ITS
# PATH, so no compositor state, logind call or session action is touched, and
# MIRROROS_SHELL_SESSION_DRY_RUN records dispatch instead of executing it.
# No keyboard or pointer input is injected.
#
# Usage: capabilities/desktop/shell/tests/check-menu.sh
# Exit codes: 0 pass, 1 a check failed, 2 blocked (no Wayland session/tool).
set -u

shell_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../capabilities/desktop/shell" && pwd)
tmp=$(mktemp -d)
pid=""
failures=0

cleanup() {
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
    rm -rf "$tmp"
}
trap cleanup EXIT

pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }
check() { if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1 (expected: $3, got: $2)"; fi; }

for tool in node qs hyprctl; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
if [[ -z "${WAYLAND_DISPLAY:-}" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED no reachable Wayland session\n'
    exit 2
fi

# --- Synthetic desktop entries -------------------------------------------------
apps="$tmp/data/applications"
mkdir -p "$apps" "$tmp/home"
entry() { printf '[Desktop Entry]\nType=Application\nName=%s\nExec=true\n%s' "$2" "${3:-}" >"$apps/$1.desktop"; }
entry synthetic-alpha "Synthetic Alpha" $'GenericName=Synthetic tool\n'
entry synthetic-beta "Synthetic Beta"

# --- Fake tools (fixture PATH only) -------------------------------------------
fake="$tmp/fake"
bin="$tmp/bin"
locker_bin="$tmp/locker-bin"
mkdir -p "$fake" "$bin" "$locker_bin"

cat >"$bin/hyprctl" <<EOF
#!/bin/sh
# Fake hyprctl: synthetic binds; records dispatch evals (eval prints no values).
case "\$1" in
  binds) cat "$fake/binds.json" ;;
  eval) printf '%s\n' "\$2" >>"$fake/eval.log"; echo ok ;;
  *) exit 1 ;;
esac
EOF
cat >"$bin/busctl" <<EOF
#!/bin/sh
# Fake busctl: answers logind Can* from files; the method is the last argument.
# While gate-busctl exists the probe waits, so a test controls when answers land.
while [ -e "$fake/gate-busctl" ]; do sleep 0.1; done
for last; do :; done
[ -f "$fake/logind-\$last" ] || exit 1
printf '{"type":"s","data":["%s"]}\n' "\$(cat "$fake/logind-\$last")"
EOF
cat >"$bin/uwsm" <<'EOF'
#!/bin/sh
[ "$1" = check ] && [ "$2" = is-active ] && exit 0
exit 1
EOF
cat >"$bin/systemctl" <<EOF
#!/bin/sh
# Fake systemctl: only "--user is-active"; active when the marker exists.
# While gate-systemctl exists the probe waits (see busctl).
while [ -e "$fake/gate-systemctl" ]; do sleep 0.1; done
[ "\$1" = --user ] && [ "\$2" = is-active ] || exit 1
[ -e "$fake/locker-active" ] && exit 0
exit 3
EOF
printf '#!/bin/sh\nexit 0\n' >"$locker_bin/hyprlock"
chmod +x "$bin"/* "$locker_bin/hyprlock"
# System tools without hyprlock, so the no-locker variant holds whatever the
# guest has installed.
sysbin="$tmp/sysbin-nolocker"
mkdir -p "$sysbin"
for tool in /usr/bin/*; do [[ "${tool##*/}" == hyprlock ]] || ln -s "$tool" "$sysbin/"; done

printf yes >"$fake/logind-CanSuspend"
printf na >"$fake/logind-CanHibernate"
printf yes >"$fake/logind-CanReboot"
printf challenge >"$fake/logind-CanPowerOff"

cat >"$fake/binds.json" <<'EOF'
[
  {"modmask":64,"submap":"","key":"D","keycode":0,"description":"Apps","dispatcher":"__lua","arg":"11"},
  {"modmask":64,"submap":"","key":"Return","keycode":0,"description":"","dispatcher":"__lua","arg":"5"},
  {"modmask":65,"submap":"","key":"Q","keycode":0,"description":"Close window","dispatcher":"__lua","arg":"7"},
  {"modmask":64,"submap":"resize","key":"H","keycode":0,"description":"Submap row","dispatcher":"__lua","arg":"9"},
  {"modmask":64,"submap":"","key":"","keycode":0,"description":"Switch to workspace 2","dispatcher":"__lua","arg":"20"},
  {"modmask":64,"submap":"","key":"","keycode":0,"description":"Twin","dispatcher":"__lua","arg":"21"},
  {"modmask":64,"submap":"","key":"","keycode":0,"description":"Unregistered code key","dispatcher":"__lua","arg":"22"},
  {"modmask":64,"submap":"","key":"","keycode":0,"description":"","dispatcher":"__lua","arg":"23"}
]
EOF
# Registry file as exported by the Lua helper: instance header, "<id>\t<keys>\t<description>"
# lines; an invalid id must be ignored (stays non-launchable). Hyprland reports no key for
# `code:N` bindings, so those rows match by modifiers and description, only when unique:
# workspace.2 is unique, twin.a/twin.b share modifiers and description (ambiguous), the
# last bind has no description, and old.two is a two-column line from an older helper.
signature="${HYPRLAND_INSTANCE_SIGNATURE:-mirroros-test-instance}"
registry() {
    printf '# instance %s\nmenu.apps\tSUPER + D\tApps\nbad"id\tSUPER + SHIFT + Q\tClose window\n' "$1" >"$fake/registry.tsv"
    printf 'workspace.2\tSUPER + code:11\tSwitch to workspace 2\ntwin.a\tSUPER + code:12\tTwin\ntwin.b\tSUPER + code:13\tTwin\n' >>"$fake/registry.tsv"
    printf 'old.two\tSUPER + code:14\n' >>"$fake/registry.tsv"
}
registry "$signature"

# --- Fixture -------------------------------------------------------------------
run_dir="$tmp/shell"
cp -r "$shell_dir" "$run_dir"
rm -rf "$run_dir/tests"
cat >"$run_dir/shell.qml" <<'QML'
import Quickshell
import "services"
import "menu"
ShellRoot {
  id: shell
  property AppLibrary appLibrary: AppLibrary { }
  property SessionActions sessionActions: SessionActions { }
  property KeybindingHelp keybindingHelp: KeybindingHelp { }
  Menu {
    appLibrary: shell.appLibrary
    sessionActions: shell.sessionActions
    keybindingHelp: shell.keybindingHelp
  }
}
QML

ipc() { qs ipc -p "$run_dir" call menu "$@" 2>&1; }
js() { node -e "const s=JSON.parse(process.argv[1]); console.log($1)" "$2"; }
state() { ipc state; }
field() { js "$1" "$(state)"; }
layer_count() { hyprctl layers 2>/dev/null | grep -c 'namespace: mirroros-menu'; }

wait_for() {
    local out=""
    for _ in $(seq 1 25); do
        out=$("$@") && [[ "$out" == "$expected" ]] && break
        sleep 0.2
    done
    printf '%s' "$out"
}
eventually() { expected=$2; wait_for field "$1"; }

start_shell() {
    local name=$1 path=$2
    dry="$tmp/dry-run-$name.jsonl"
    : >"$dry"
    HOME="$tmp/home" XDG_DATA_HOME="$tmp/home/.local/share" XDG_DATA_DIRS="$tmp/data" \
        XDG_CURRENT_DESKTOP=Hyprland PATH="$path" MIRROROS_SHELL_SESSION_DRY_RUN="$dry" \
        HYPRLAND_INSTANCE_SIGNATURE="$signature" MIRROROS_SHELL_KEYBINDINGS_REGISTRY="$fake/registry.tsv" \
        "$(command -v qs)" -p "$run_dir" >"$tmp/$name.log" 2>&1 &
    pid=$!
    expected=ok
    check "$name: apps provider status ok" "$(wait_for ipc status)" ok
}

stop_shell() {
    local name=$1 noisy
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    pid=""
    # Only the known Qt text-input focus variants are exempt (Brief 1/2).
    noisy=$(grep -Ei 'warn|error' "$tmp/$name.log" \
        | grep -v 'qt.qpa.wayland.textinput.*has focus' \
        | grep -v 'QWaylandTextInputv3::disableSurface.*is focused')
    if [[ -n "$noisy" ]]; then fail "$name: log is not quiet"; printf '%s\n' "$noisy"; else pass "$name: log is quiet"; fi
}

# ============================== variant: no locker =============================
start_shell nolocker "$bin:$sysbin"

# Root and direct routes.
check "root: open accepted" "$(ipc open root)" ok
check "root: rows" "$(field 's.labels.join("|")')" "Apps|Learn|Style|Install|System"
check "root: overlay layer mapped" "$(expected=1 wait_for layer_count)" 1
check "root: menu id and depth" "$(field 's.menu+":"+s.depth')" "root:0"
ipc close >/dev/null
check "close: unmapped" "$(expected=0 wait_for layer_count)" 0

ipc open apps >/dev/null
check "apps direct: opens Apps without root" "$(field 's.menu+":"+s.depth')" "apps:0"
check "apps direct: alphabetical app rows" "$(eventually 's.labels.join("|")' 'Synthetic Alpha|Synthetic Beta')" "Synthetic Alpha|Synthetic Beta"
ipc open applications >/dev/null
check "apps alias route" "$(field 's.menu')" apps
ipc back >/dev/null
check "apps direct: back goes to parent root" "$(field 's.menu')" root
ipc close >/dev/null

ipc open system >/dev/null
check "system direct: rows in upstream order" "$(eventually 's.labels.join("|")' 'Lock|Suspend|Hibernate|Logout|Reboot|Shutdown')" \
    "Lock|Suspend|Hibernate|Logout|Reboot|Shutdown"
# Wait until every probe answered (no "Checking" reason left).
expected=0; wait_for field 's.rows.filter(r=>/Checking/.test(r.detail)).length' >/dev/null
check "system: availability" "$(field 's.rows.map(r=>r.label+"="+(r.disabled?"off":"on")).join(",")')" \
    "Lock=off,Suspend=on,Hibernate=off,Logout=on,Reboot=on,Shutdown=off"
check "system: lock reason pinned" "$(field 's.rows[0].pinned+"|"+s.rows[0].detail')" "true|Install hyprlock to lock the screen."
check "system: hibernate reason (logind na)" "$(field 's.rows[2].detail')" "This system reports hibernate is not supported (na)."
check "system: shutdown reason (logind challenge)" "$(field 's.rows[5].detail')" "Shutdown needs authorization (no polkit agent)."
check "system: no checkmark on unavailable rows" "$(field 's.labels.filter(l=>l.includes("✓")).length')" 0
check "system: cursor skips unavailable first row" "$(field 's.selected')" 1
ipc move 1 >/dev/null
check "system: Down skips unavailable Hibernate" "$(field 's.selected')" 3
ipc back >/dev/null
check "system direct: back to root" "$(field 's.menu')" root

# Tree navigation from root.
ipc open root >/dev/null
ipc move 1 >/dev/null; ipc move 1 >/dev/null
ipc move 1 >/dev/null; ipc move 1 >/dev/null
ipc activate >/dev/null
check "nav: System submenu pushed" "$(field 's.menu+":"+s.depth')" "system:1"
ipc back >/dev/null
check "nav: back pops" "$(field 's.menu+":"+s.depth')" "root:0"
ipc open root >/dev/null
ipc move 1 >/dev/null
ipc activate >/dev/null
check "nav: Learn holds Keybindings" "$(field 's.menu+"|"+s.labels.join("|")')" "learn|Keybindings"
ipc close >/dev/null

# Root search reaches submenus and app rows; unavailable rows stay with reason.
ipc open root >/dev/null
ipc setFilter alpha >/dev/null
check "search: app from root with parent path" "$(eventually 's.rows.map(r=>r.label+"@"+r.detail).join("|")' 'Synthetic Alpha@Apps')" "Synthetic Alpha@Apps"
ipc setFilter hibernate >/dev/null
check "search: unavailable row listed with reason" "$(field 's.rows.map(r=>r.label+"|"+r.disabled+"|"+r.detail).join(";")')" \
    "Hibernate|true|This system reports hibernate is not supported (na)."
ipc setFilter l >/dev/null
check "search: drilldown divider after current-level rows" \
    "$(field 's.rows[0].label+"|"+s.rows[0].section+"|"+s.rows.some(r=>r.section==="drilldown")')" "Learn||true"
ipc setFilter "" >/dev/null
ipc close >/dev/null

# Dispatch (dry-run): only available actions are recorded.
dispatched() { node -e 'const fs=require("fs");console.log(fs.readFileSync(process.argv[1],"utf8").trim().split("\n").filter(Boolean).map(l=>{const o=JSON.parse(l);return o.action+":"+o.argv.join(" ")}).join("|"))' "$dry"; }
ipc open system >/dev/null
expected=0; wait_for field 's.rows.filter(r=>/Checking/.test(r.detail)).length' >/dev/null
ipc activate >/dev/null
check "dispatch: Enter on Suspend closes" "$(ipc isOpen)" false
sleep 0.5
check "dispatch: suspend argv recorded" "$(dispatched)" "suspend:systemctl suspend"
ipc open system.reboot >/dev/null
ipc open system.logout >/dev/null
ipc open system.lock >/dev/null
ipc open system.hibernate >/dev/null
ipc open system.shutdown >/dev/null
sleep 0.5
check "dispatch: action routes run available actions only" "$(dispatched)" \
    "suspend:systemctl suspend|reboot:systemctl reboot|logout:uwsm stop"
check "sessionState: dry-run and argv table" \
    "$(js 's.dryRun+"|"+s.actions.lock.argv.join(" ")+"|"+s.actions.shutdown.argv.join(" ")' "$(ipc sessionState)")" \
    "true|loginctl lock-session|systemctl poweroff"

# Keyboard help from the compositor's binds; only registered ids launch.
ipc keybindings >/dev/null
check "help: selector opened" "$(eventually 's.mode+"|"+s.prompt' 'select|Keybindings')" "select|Keybindings"
check "help: installed binds only, submap rows excluded" "$(field 's.labels.join("|")')" \
    "SUPER + D → Apps|SUPER + Return|SUPER + SHIFT + Q → Close window|SUPER + code:11 → Switch to workspace 2|SUPER +  → Twin|SUPER +  → Unregistered code key|SUPER + "
check "help: honest notes" "$(field 's.rows.map(r=>r.detail).join("|")')" \
    "|No description · Not launchable from help|Not launchable from help||Not launchable from help|Not launchable from help|No description · Not launchable from help"
ipc activate >/dev/null
sleep 0.5
check "help: registered row dispatched by id" "$(cat "$fake/eval.log" 2>/dev/null)" 'MirrorOSKeys.dispatch("menu.apps")'
ipc keybindings >/dev/null
eventually 's.mode' select >/dev/null
ipc move 2 >/dev/null
ipc activate >/dev/null
sleep 0.5
check "help: unregistered row (invalid registry id) not dispatched" "$(wc -l <"$fake/eval.log")" 1
ipc close >/dev/null
ipc keybindings >/dev/null
eventually 's.mode' select >/dev/null
ipc move 3 >/dev/null
ipc activate >/dev/null
sleep 0.5
check "help: keyless code:N row matched by modifiers and description is dispatched" "$(tail -n 1 "$fake/eval.log")" \
    'MirrorOSKeys.dispatch("workspace.2")'
ipc keybindings >/dev/null
eventually 's.mode' select >/dev/null
ipc move 4 >/dev/null
ipc activate >/dev/null
sleep 0.5
check "help: ambiguous keyless row not dispatched" "$(wc -l <"$fake/eval.log")" 2
cp "$fake/binds.json" "$fake/binds-original.json"
node -e 'const fs=require("fs"), p=process.argv[1], b=JSON.parse(fs.readFileSync(p)); b.push({modmask:64,submap:"",key:"D",keycode:0,description:"Personal duplicate"}); fs.writeFileSync(p,JSON.stringify(b))' "$fake/binds.json"
ipc close >/dev/null
ipc keybindings >/dev/null
check "help: both duplicate chord rows are non-launchable" \
    "$(eventually 's.rows[0].detail+"|"+s.rows[7].detail' 'Not launchable from help|Not launchable from help')" \
    "Not launchable from help|Not launchable from help"
ipc activate >/dev/null
sleep 0.5
check "help: duplicate chord is not dispatched" "$(wc -l <"$fake/eval.log")" 2
mv "$fake/binds-original.json" "$fake/binds.json"
registry "another-instance"
ipc close >/dev/null
ipc keybindings >/dev/null
check "help: registry from another Hyprland instance launches nothing" \
    "$(eventually 's.mode+"|"+s.rows[0].detail' 'select|Not launchable from help')" "select|Not launchable from help"
rm -f "$fake/registry.tsv"
ipc close >/dev/null
ipc keybindings >/dev/null
check "help: missing registry file launches nothing" \
    "$(eventually 's.mode+"|"+s.rows[0].detail' 'select|Not launchable from help')" "select|Not launchable from help"
registry "$signature"
ipc open learn >/dev/null
ipc activate >/dev/null
check "help: Learn > Keybindings opens the selector" "$(eventually 's.mode+"|"+s.prompt' 'select|Keybindings')" "select|Keybindings"
ipc close >/dev/null
check "help: close returns to closed menu" "$(ipc isOpen)" false

stop_shell nolocker

# ============================== variant: locker present ========================
start_shell locker "$locker_bin:$bin:$PATH"
ipc open system >/dev/null
expected=0; wait_for field 's.rows.filter(r=>/Checking/.test(r.detail)).length' >/dev/null
check "locker: hyprlock without its service gives the start reason" "$(field 's.rows[0].disabled+"|"+s.rows[0].detail')" \
    "true|Start hypridle; it runs the screen locker."
ipc close >/dev/null
touch "$fake/locker-active"
ipc open system >/dev/null
expected=0; wait_for field 's.rows.filter(r=>/Checking/.test(r.detail)).length' >/dev/null
check "locker: lock available when hyprlock and its service are present" "$(eventually 's.rows[0].disabled' false)" false
# The cursor was placed while Lock was still unavailable and stays where it was
# when Lock becomes available (see the stable-selection variant); reopen so Lock
# is selected.
ipc close >/dev/null
ipc open system >/dev/null
check "locker: reopened System selects Lock" "$(eventually 's.menu+"|"+s.selected' 'system|0')" "system|0"
ipc activate >/dev/null
sleep 0.5
check "locker: lock dispatches loginctl lock-session" "$(dispatched)" "lock:loginctl lock-session"
stop_shell locker
rm -f "$fake/locker-active"

# ============================== variant: stable selection ======================
# Availability changes while a menu is open must never retarget Enter. Probe
# answers are held back by gate files; dispatch is recorded (dry-run), never run.
start_shell stable "$locker_bin:$bin:$PATH"
selected_label() { field 's.selected<0?"none":s.labels[s.selected]'; }
open_system_settled() {
    ipc open system >/dev/null
    expected=0; wait_for field 's.rows.filter(r=>/Checking/.test(r.detail)).length' >/dev/null
}
open_system_settled
check "stable: warm-up leaves Lock unavailable" "$(field 's.rows[0].disabled')" true
ipc close >/dev/null

# An earlier row (Lock) becomes available while Suspend is selected.
touch "$fake/gate-systemctl" "$fake/locker-active"
ipc open system >/dev/null
check "stable: Suspend selected while Lock probe is held" "$(eventually 's.selectedId+"|"+s.rows[0].disabled' 'system.suspend|true')" "system.suspend|true"
rm -f "$fake/gate-systemctl"
check "stable: Lock became available while open" "$(eventually 's.rows[0].disabled' false)" false
check "stable: selection stays on Suspend" "$(selected_label)|$(field 's.selectedId')" "Suspend|system.suspend"
ipc activate >/dev/null
sleep 0.5
check "stable: Enter runs Suspend, not the newly available Lock" "$(dispatched)" "suspend:systemctl suspend"

# The selected row (Suspend) becomes unavailable while open.
touch "$fake/gate-busctl"
ipc open system >/dev/null
ipc move 1 >/dev/null
check "stable: Suspend selected explicitly" "$(selected_label)|$(field 's.selectedId')" "Suspend|system.suspend"
printf na >"$fake/logind-CanSuspend"
rm -f "$fake/gate-busctl"
check "stable: Suspend became unavailable while open" "$(eventually 's.rows[1].disabled' true)" true
check "stable: reason stays visible" "$(field 's.rows[1].pinned+"|"+s.rows[1].detail')" \
    "true|This system reports suspend is not supported (na)."
check "stable: no cursor falls to another row" "$(field 's.selected+"|"+JSON.stringify(s.selectedId)')" '-1|""'
ipc activate >/dev/null
sleep 0.5
check "stable: Enter runs nothing" "$(ipc isOpen)|$(dispatched)" "true|suspend:systemctl suspend"
ipc move 1 >/dev/null
check "stable: explicit selection picks an available row" "$(selected_label)" Lock
ipc activate >/dev/null
sleep 0.5
check "stable: Enter then runs the explicitly selected row" "$(dispatched)" "suspend:systemctl suspend|lock:loginctl lock-session"
printf yes >"$fake/logind-CanSuspend"
rm -f "$fake/locker-active"

# Apps rows: an earlier app appearing must not move Enter to a different app.
ipc open apps >/dev/null
check "stable: app rows listed" "$(eventually 's.labels.join("|")' 'Synthetic Alpha|Synthetic Beta')" "Synthetic Alpha|Synthetic Beta"
ipc move 1 >/dev/null
check "stable: Synthetic Beta selected" "$(selected_label)" "Synthetic Beta"
entry synthetic-aaa "Synthetic Aaa"
check "stable: earlier app row appeared" "$(eventually 's.labels.join("|")' 'Synthetic Aaa|Synthetic Alpha|Synthetic Beta')" \
    "Synthetic Aaa|Synthetic Alpha|Synthetic Beta"
check "stable: selection stays on Synthetic Beta" "$(selected_label)" "Synthetic Beta"
rm -f "$apps/synthetic-aaa.desktop"
ipc close >/dev/null
stop_shell stable

# ============================== variant: help without compositor ===============
printf 'not json' >"$fake/binds.json"
start_shell nobinds "$bin:$PATH"
ipc keybindings >/dev/null
check "help: unreadable binds give an unavailable row" "$(eventually 's.labels.join("|")' 'Keyboard help unavailable')" "Keyboard help unavailable"
stop_shell nobinds

if ((failures > 0)); then
    printf '%d check(s) failed\n' "$failures"
    exit 1
fi
printf 'All checks passed\n'
