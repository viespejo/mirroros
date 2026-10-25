#!/usr/bin/env bash
# DEC-027 selector replacement checks. Synthetic data only, isolated HOME/XDG,
# no input injection. Requires a disposable Wayland session with Quickshell.
#
# Before a new selector request or a regular menu replaces an active selector,
# the old request must complete as cancelled exactly once (done file, empty
# selection), without running its selection, while the new request keeps
# working. Rapid replacements must not lose a completion, and a failed delivery
# must not block later requests.
#
# Usage: tests/capabilities/desktop/shell/check-selector-replacement.sh
# Exit codes: 0 pass, 1 a check failed, 2 blocked.
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

for tool in node qs timeout; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
if [[ -z "${WAYLAND_DISPLAY:-}" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED no reachable Wayland session\n'
    exit 2
fi

run_dir="$tmp/shell"
cp -r "$shell_dir" "$run_dir"
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
mkdir -p "$tmp/home" "$tmp/data/applications" "$tmp/config" "$tmp/state"
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" \
    XDG_DATA_HOME="$tmp/home/.local/share" XDG_DATA_DIRS="$tmp/data" \
    "$(command -v qs)" -p "$run_dir" >"$tmp/shell.log" 2>&1 &
pid=$!

ipc() { qs ipc -p "$run_dir" call menu "$@" 2>&1; }
field() { node -e "const s=JSON.parse(process.argv[1]); console.log($1)" "$(ipc state)"; }
for _ in $(seq 1 25); do [[ "$(ipc isOpen)" == false ]] && break; sleep 0.2; done
check "shell: IPC reachable" "$(ipc isOpen)" false

priv=$(mktemp -d "$tmp/req.XXXXXX")
n=0
# new_request [DIR] -> sets sel/done_file for a fresh request.
new_request() {
    n=$((n + 1))
    sel="${1:-$priv}/sel-$n"
    done_file="${1:-$priv}/done-$n"
    [[ -d "${1:-$priv}" ]] && : >"$sel"
}
payload() {
    node -e 'const [mode, extra, sel, done] = process.argv.slice(1);
      console.log(JSON.stringify(Object.assign({ mode, selectionFile: sel, doneFile: done }, JSON.parse(extra))))' \
        "$1" "$2" "$sel" "$done_file"
}
# shellcheck disable=SC2016  # $1 is expanded by the inner bash, not here.
wait_done() { timeout "${2:-5}" bash -c 'while [ ! -e "$1" ]; do sleep 0.05; done' _ "$1"; }
outcome() { if wait_done "$1" "${3:-5}"; then printf 'done:%s' "$(cat "$2")"; else printf 'timeout'; fi; }
# A completion is delivered once: after removing the done file it must not reappear.
once() { rm -f -- "$1"; sleep "${2:-1}"; [[ -e "$1" ]] && echo repeated || echo once; }

# --- Selector replaced by a selector ---------------------------------------------
marker="$priv/old-on-change-ran"
# shellcheck disable=SC2016  # $1 belongs to the synthetic onChange command.
on_change=$(node -e 'console.log(JSON.stringify(["sh","-c",": > \"$1\"","sh",process.argv[1]]))' "$marker")
new_request
old_sel=$sel old_done=$done_file
ipc dmenu "$(payload select "{\"options\":[\"First\",\"Other\"],\"multiple\":true,\"onChange\":$on_change}")" >/dev/null
ipc move 1 >/dev/null
new_request
check "selector->selector: replacement accepted" "$(ipc dmenu "$(payload select '{"options":["Second"]}')")" accepted
check "selector->selector: old request completes as cancelled" "$(outcome "$old_done" "$old_sel")" "done:"
check "selector->selector: old selection not executed" "$([[ -e "$marker" ]] && echo executed || echo none)" none
check "selector->selector: old completion delivered once" "$(once "$old_done")" once
check "selector->selector: new selector shown and open" "$(field 's.opened+"|"+s.labels.join(",")')" "true|Second"
check "selector->selector: new request pending" "$([[ -e "$done_file" ]] && echo "done" || echo pending)" pending
ipc activate >/dev/null
check "selector->selector: new request completes with its selection" "$(outcome "$done_file" "$sel")" "done:Second"

# --- Selector replaced by a regular menu -------------------------------------------
new_request
ipc dmenu "$(payload input '{"prompt":"Text"}')" >/dev/null
ipc setFilter "must not be returned" >/dev/null
ipc open root >/dev/null
check "selector->menu: old request completes as cancelled" "$(outcome "$done_file" "$sel")" "done:"
check "selector->menu: regular menu open" "$(field 's.opened+"|"+s.mode')" "true|menu"
check "selector->menu: completion delivered once" "$(once "$done_file")" once
ipc close >/dev/null

# --- Rapid replacements: every request completes exactly once -----------------------
burst=()
for i in 1 2 3 4 5; do
    new_request
    burst+=("$sel|$done_file")
    ipc dmenu "$(payload select "{\"options\":[\"Burst$i\"]}")" >/dev/null
done
ipc activate >/dev/null
results=()
for i in "${!burst[@]}"; do
    IFS='|' read -r s d <<<"${burst[$i]}"
    results+=("$(outcome "$d" "$s")")
done
check "burst: four replaced requests cancelled, last selected" "$(printf '%s,' "${results[@]}")" "done:,done:,done:,done:,done:Burst5,"
dups=0
for entry in "${burst[@]}"; do
    IFS='|' read -r _ d <<<"$entry"
    rm -f -- "$d"
done
sleep 1
for entry in "${burst[@]}"; do
    IFS='|' read -r _ d <<<"$entry"
    [[ -e "$d" ]] && dups=$((dups + 1))
done
check "burst: no repeated completion" "$dups" 0

# --- Failed delivery does not block later requests ----------------------------------
gone="$tmp/gone"
mkdir -p "$gone"
new_request "$gone"
ipc dmenu "$(payload select '{"options":["Lost"]}')" >/dev/null
rm -rf "$gone"
new_request
ipc dmenu "$(payload select '{"options":["After"]}')" >/dev/null
check "failure: replaced request with unwritable done path left nothing" "$([[ -e "$gone" ]] && echo created || echo none)" none
ipc activate >/dev/null
check "failure: next request still completes" "$(outcome "$done_file" "$sel")" "done:After"

kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
pid=""
check "failure: undelivered result reported in the log" \
    "$(grep -c 'Selector result could not be delivered' "$tmp/shell.log")" 1
noisy=$(grep -Ei 'warn|error' "$tmp/shell.log" \
    | grep -v 'Selector result could not be delivered' \
    | grep -v 'qt.qpa.wayland.textinput.*has focus' \
    | grep -v 'QWaylandTextInputv3::disableSurface.*is focused')
if [[ -n "$noisy" ]]; then fail "log is otherwise quiet"; printf '%s\n' "$noisy"; else pass "log is otherwise quiet"; fi

if ((failures > 0)); then
    printf '%d check(s) failed\n' "$failures"
    exit 1
fi
printf 'All checks passed\n'
