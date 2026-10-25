#!/usr/bin/env bash
# Prototype-local checks for the launcher (Story 4.3 prototype). Since Brief 3
# the launcher is the Apps submenu of the shared menu, opened directly with
# `menu open apps`; these are the Brief 1 checks against that route.
# Synthetic data only: fake .desktop entries, a fake terminal emulator and an
# isolated HOME in a temporary directory.
#
# Usage: capabilities/desktop/shell/tests/check-launcher.sh
#
# Keyboard checks use wtype and type into the focused surface. They run only
# after the launcher layer is mapped (it takes exclusive keyboard focus), and
# never send Alt or Super chords, which could trigger compositor bindings.
#
# Exit codes: 0 all checks passed, 1 a check failed, 2 blocked (no
# reachable Wayland session or missing tool). Blocked is never reported as pass.
set -u

tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shell_dir=$(cd "$tests_dir/../../../../capabilities/desktop/shell" && pwd)
qmllint=/usr/lib/qt6/bin/qmllint
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

for tool in node qs "$qmllint" bash uwsm hyprctl wtype; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done

# --- Static check ------------------------------------------------------------
# Shared exact baseline: every QML file, no disabled diagnostic categories.
if ! node "$tests_dir/qmllint-check.mjs"; then
    fail "qmllint: new or stale baseline diagnostics"
fi

# --- Runtime checks ----------------------------------------------------------
if [[ -z "${WAYLAND_DISPLAY:-}" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED no reachable Wayland session (WAYLAND_DISPLAY=%s XDG_RUNTIME_DIR=%s)\n' \
        "${WAYLAND_DISPLAY:-unset}" "${XDG_RUNTIME_DIR:-unset}"
    exit 2
fi

# Synthetic desktop entries. Launches leave marker files in $tmp.
apps="$tmp/data/applications"
mkdir -p "$apps" "$tmp/empty/applications" "$tmp/home"
entry() { printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\n%s' "$2" "$3" "${4:-}" >"$apps/$1.desktop"; }

# A fake terminal emulator: records its arguments instead of opening a window.
cat >"$tmp/fake-term.sh" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >"$tmp/launched-terminal"
EOF
cat >"$tmp/tui-probe.sh" <<'EOF'
#!/bin/sh
true
EOF
chmod +x "$tmp/fake-term.sh" "$tmp/tui-probe.sh"

entry synthetic-alpha "Synthetic Alpha" "touch $tmp/launched-alpha" $'GenericName=Synthetic tool\n'
entry synthetic-beta "Synthetic Beta" "true"
entry synthetic-gamma "Synthetic Gamma" "true"
entry synthetic-term "Synthetic Term" "$tmp/fake-term.sh" $'Categories=System;TerminalEmulator;\n'
entry synthetic-tui "Synthetic TUI" "$tmp/tui-probe.sh" $'Terminal=true\n'
entry synthetic-nodisplay "Synthetic NoDisplay" "true" $'NoDisplay=true\n'
entry synthetic-gnome-only "Synthetic GnomeOnly" "true" $'OnlyShowIn=GNOME;\n'
entry synthetic-not-hyprland "Synthetic NotHyprland" "true" $'NotShowIn=Hyprland;\n'
all_labels='["Synthetic Alpha","Synthetic Beta","Synthetic Gamma","Synthetic Term","Synthetic TUI"]'

# Prototype-local terminal preference for uwsm (per process, never ~/.config or /etc).
mkdir -p "$tmp/xdg-config"
printf 'synthetic-term.desktop\n' >"$tmp/xdg-config/xdg-terminals.list"

# PATH without uwsm, for the unavailable-launcher variant.
mkdir "$tmp/no-uwsm-bin"
for tool in sh bash find sort awk; do ln -s "$(command -v "$tool")" "$tmp/no-uwsm-bin/$tool"; done

# Minimal fallback style: same token names, no theming.
fallback_dir="$tmp/fallback"
mkdir "$fallback_dir"
cat >"$fallback_dir/Color.qml" <<'QML'
pragma Singleton
import QtQuick

QtObject {
  property color foreground: "black"
  property color background: "white"
  property color accent: "black"
  property color urgent: "black"
  property color muted: "gray"
  property var shellValues: ({})
  readonly property QtObject menu: QtObject {
    property color background: "white"
    property color text: "black"
    property color border: "black"
    property color scrim: "transparent"
    property color selectedBackground: "lightgray"
    property color selectedText: "black"
    property color selectedBorder: "transparent"
  }
}
QML
cat >"$fallback_dir/Style.qml" <<'QML'
pragma Singleton
import QtQuick

QtObject {
  property int cornerRadius: 0
  property int gapsOut: 0
  function space(px) { return px }
  readonly property QtObject spacing: QtObject {
    readonly property int hairline: 1
    readonly property int xs: 0
    readonly property int sm: 0
    readonly property int md: 0
    readonly property int controlPaddingY: 0
    readonly property int rowPaddingX: 0
    readonly property int panelPadding: 0
  }
  readonly property QtObject font: QtObject {
    readonly property string family: ""
    readonly property string menuFamily: ""
    readonly property int caption: 12
    readonly property int bodySmall: 12
    readonly property int body: 12
    readonly property int title: 12
    readonly property int heading: 12
    readonly property int displayLarge: 12
    readonly property int iconLarge: 12
  }
}
QML

ipc() { qs ipc -p "$run_dir" call menu "$@" 2>&1; }
status() { ipc status; }
labels() { ipc state | sed -E 's/.*"labels":(\[[^]]*\]).*/\1/'; }
selected() { ipc state | sed -E 's/.*"selected":(-?[0-9]+).*/\1/'; }
filter() { ipc state | sed -E 's/.*"filter":"([^"]*)".*/\1/'; }
input_text() { ipc state | sed -E 's/.*"input":"([^"]*)".*/\1/'; }
is_open() { ipc isOpen; }
layer_count() { hyprctl layers 2>/dev/null | grep -c 'namespace: mirroros-menu'; }

# wait_for COMMAND EXPECTED: poll up to 5 s until COMMAND prints EXPECTED.
wait_for() {
    local out=""
    for _ in $(seq 1 25); do
        out=$("$1") && [[ "$out" == "$2" ]] && break
        sleep 0.2
    done
    printf '%s' "$out"
}

# wait_file PATH: poll up to 10 s for a marker file.
wait_file() {
    for _ in $(seq 1 50); do [[ -e "$1" ]] && { printf yes; return; }; sleep 0.2; done
    printf no
}

key() { wtype "$@"; sleep 0.3; }

open_with_focus() {
    ipc open apps >/dev/null
    check "$1: layer mapped before typing" "$(wait_for layer_count 1)" 1
    sleep 0.5
}

keyboard_checks() {
    local name=$1
    open_with_focus "$name"
    key gam
    check "$name: typing filters" "$(labels)" '["Synthetic Gamma"]'
    key -k BackSpace
    check "$name: Backspace edits filter" "$(filter)" ga
    key -M ctrl u -m ctrl
    check "$name: Ctrl+U clears filter" "$(filter)" ""
    check "$name: cursor on first row" "$(selected)" 0
    key -k Down
    check "$name: Down moves" "$(selected)" 1
    key -k Up -k Up
    check "$name: Up wraps to last" "$(selected)" 4
    key -k Page_Down
    check "$name: PageDown moves by 6 with wrap" "$(selected)" 0
    key xyz
    key -k Escape
    check "$name: Escape clears filter first" "$(filter)|$(is_open)" "|true"
    check "$name: Escape clears the search line" "$(input_text)" ""
    key -k Escape
    check "$name: second Escape closes" "$(wait_for is_open false)" false
    check "$name: layer unmapped after Escape" "$(wait_for layer_count 0)" 0

    rm -f "$tmp/launched-alpha"
    open_with_focus "$name"
    key alpha
    key -k Return
    check "$name: Enter closes" "$(wait_for is_open false)" false
    check "$name: Enter launches through uwsm" "$(wait_file "$tmp/launched-alpha")" yes
}

# run_variant NAME STYLE (real|fallback) DATA_DIR EXPECT (ok|unavailable:<text>) [PATH]
run_variant() {
    local name=$1 style=$2 data=$3 expect=$4 path=${5:-$PATH}
    run_dir="$tmp/run-$name"
    cp -r "$shell_dir" "$run_dir"
    rm -rf "$run_dir/tests"
    # Keep fallback style and reduced PATH scenarios launcher-local. Whole-shell
    # composition is exercised by check-bar.sh, not these isolated fixtures.
    cat >"$run_dir/shell.qml" <<'QML'
import Quickshell
import "services"
import "menu"
ShellRoot {
  id: shell
  property AppLibrary appLibrary: AppLibrary { }
  Menu { appLibrary: shell.appLibrary }
}
QML
    if [[ "$style" == fallback ]]; then
        cp "$fallback_dir/Color.qml" "$fallback_dir/Style.qml" "$run_dir/Commons/"
    fi
    rm -f "$tmp/launched-alpha" "$tmp/launched-terminal"

    HOME="$tmp/home" XDG_DATA_HOME="$tmp/home/.local/share" XDG_DATA_DIRS="$data" \
        XDG_CONFIG_DIRS="$tmp/xdg-config:${XDG_CONFIG_DIRS:-/etc/xdg}" \
        XDG_CURRENT_DESKTOP=Hyprland PATH="$path" \
        "$(command -v qs)" -p "$run_dir" >"$tmp/$name.log" 2>&1 &
    pid=$!

    if [[ "$expect" == unavailable:* ]]; then
        local want=${expect#unavailable:} out=""
        for _ in $(seq 1 25); do
            out=$(ipc status) && [[ "$out" == *"$want"* ]] && break
            sleep 0.2
        done
        if [[ "$out" == *"$want"* ]]; then
            pass "$name: reports actionable unavailable reason"
        else
            fail "$name: expected reason containing '$want', got: $out"
        fi
    else
        check "$name: status ok" "$(wait_for status ok)" ok
        check "$name: closed at start" "$(ipc isOpen)" false
        ipc open apps >/dev/null
        check "$name: open" "$(ipc isOpen)" true
        # Hidden-entry filtering (NoDisplay, OnlyShowIn, NotShowIn) and order.
        check "$name: lists only visible entries, sorted" "$(wait_for labels "$all_labels")" "$all_labels"
        ipc setFilter gam >/dev/null
        check "$name: filter narrows" "$(labels)" '["Synthetic Gamma"]'
        ipc setFilter "synthetic tool" >/dev/null
        check "$name: filter matches generic name" "$(labels)" '["Synthetic Alpha"]'
        ipc setFilter "" >/dev/null
        check "$name: cursor starts at first row" "$(selected)" 0
        ipc move 1 >/dev/null
        check "$name: move down" "$(selected)" 1
        ipc move -2 >/dev/null
        check "$name: move up wraps" "$(selected)" 4
        ipc setFilter alpha >/dev/null
        ipc activate >/dev/null
        check "$name: activate closes" "$(ipc isOpen)" false
        check "$name: activate launches through uwsm" "$(wait_file "$tmp/launched-alpha")" yes
        ipc open apps >/dev/null
        ipc setFilter tui >/dev/null
        ipc activate >/dev/null
        check "$name: terminal entry runs in the preferred terminal" "$(wait_file "$tmp/launched-terminal")" yes
        [[ -e "$tmp/launched-terminal" ]] && check "$name: terminal receives -e and the command" \
            "$(cat "$tmp/launched-terminal")" "-e $tmp/tui-probe.sh"
        ipc toggle apps >/dev/null
        check "$name: toggle opens" "$(ipc isOpen)" true
        ipc toggle apps >/dev/null
        check "$name: toggle closes" "$(ipc isOpen)" false
        if [[ "$name" == styled ]]; then
            check "$name: overlay layer unmapped" "$(wait_for layer_count 0)" 0
            keyboard_checks "$name"
        fi
    fi

    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    pid=""

    # Healthy state is quiet: no warnings or errors in the instance log.
    # Known Brief 1 Qt text-input focus warning, not shell behavior. The
    # portal is installed now; a portal warning is no longer exempted.
    local noisy
    noisy=$(grep -Ei 'warn|error' "$tmp/$name.log" | grep -v 'qt.qpa.wayland.textinput.*has focus')
    if [[ -n "$noisy" ]]; then
        fail "$name: log is not quiet"
        printf '%s\n' "$noisy"
    else
        pass "$name: log is quiet"
    fi
}

run_variant styled real "$tmp/data" ok
run_variant fallback fallback "$tmp/data" ok
run_variant empty real "$tmp/empty" "unavailable:No desktop entries found"
run_variant no-uwsm real "$tmp/data" "unavailable:uwsm not found" "$tmp/no-uwsm-bin"

if ((failures > 0)); then
    printf '%d check(s) failed\n' "$failures"
    exit 1
fi
printf 'All checks passed\n'
