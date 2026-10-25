#!/usr/bin/env bash
# Prototype-local checks for the menu's retained dmenu/selector mode
# (Story 4.3 prototype, Brief 3). Synthetic data only.
#
# The test is its own minimal client of the upstream file protocol: it creates
# a private (0700) directory, an empty selection file and a not-yet-existing
# done file, sends the payload through native IPC (`qs ipc ... menu dmenu`)
# and waits, with a bounded timeout, for the done file. IPC "accepted" only
# means the request was taken; completion, cancellation and replacement are
# observed through the files. No product CLI client exists; command-line
# usability end to end is NOT covered here.
#
# onChange runs only a harmless synthetic command that appends to a file in
# the private directory. Values with shell metacharacters verify that results
# are written without re-parsing.
#
# --keyboard additionally types Escape with wtype into the mapped selector
# (attended sessions only; never sends Alt/Super chords). Pointer
# cancellation (click outside) is not automated here.
#
# Usage: tests/capabilities/desktop/shell/check-dmenu.sh [--keyboard]
# Exit codes: 0 pass, 1 a check failed, 2 blocked.
set -u

shell_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../capabilities/desktop/shell" && pwd)
keyboard=0
[[ "${1:-}" == --keyboard ]] && keyboard=1
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

tools=(node qs hyprctl timeout)
((keyboard)) && tools+=(wtype)
for tool in "${tools[@]}"; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
if [[ -z "${WAYLAND_DISPLAY:-}" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY:-}" ]]; then
    printf 'BLOCKED no reachable Wayland session\n'
    exit 2
fi

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
  Menu { appLibrary: shell.appLibrary }
}
QML
mkdir -p "$tmp/home" "$tmp/data/applications"
HOME="$tmp/home" XDG_DATA_HOME="$tmp/home/.local/share" XDG_DATA_DIRS="$tmp/data" \
    "$(command -v qs)" -p "$run_dir" >"$tmp/shell.log" 2>&1 &
pid=$!

ipc() { qs ipc -p "$run_dir" call menu "$@" 2>&1; }
field() { node -e "const s=JSON.parse(process.argv[1]); console.log($1)" "$(ipc state)"; }
layer_count() { hyprctl layers 2>/dev/null | grep -c 'namespace: mirroros-menu'; }
for _ in $(seq 1 25); do [[ "$(ipc isOpen)" == false ]] && break; sleep 0.2; done
check "shell: IPC reachable" "$(ipc isOpen)" false

# Private request directory, one per request.
priv=$(mktemp -d "$tmp/req.XXXXXX")
check "client: private request directory is 0700" "$(stat -c %a "$priv")" 700
n=0
new_request() {
    n=$((n + 1))
    sel="$priv/sel-$n"
    done_file="$priv/done-$n"
    : >"$sel"
}
# payload MODE EXTRA_JSON_FIELDS -> JSON with the current request files.
payload() {
    node -e 'const [mode, extra, sel, done] = process.argv.slice(1);
      console.log(JSON.stringify(Object.assign({ mode, selectionFile: sel, doneFile: done }, JSON.parse(extra))))' \
        "$1" "$2" "$sel" "$done_file"
}
# Bounded wait, as a client would poll; never hangs.
# shellcheck disable=SC2016  # $1 is expanded by the inner bash, not here.
wait_done() { timeout "${2:-5}" bash -c 'while [ ! -e "$1" ]; do sleep 0.05; done' _ "$1"; }
result() { if wait_done "$done_file"; then printf 'done:%s' "$(cat "$sel")"; else printf 'timeout'; fi; }

# --- Request validation (IPC acceptance only) ----------------------------------
check "ipc: invalid JSON rejected" "$(ipc dmenu 'not json')" "error: payload is not JSON"
check "ipc: unknown mode rejected" "$(ipc dmenu '{"mode":"menu"}')" "error: mode must be select or input"

# --- Single select with icon/subtext forms ------------------------------------
new_request
p=$(payload select '{"prompt":"Pick","options":["Alpha","\uf00c\tBeta\tsub-b","\tGamma"]}')
check "select: IPC accepted" "$(ipc dmenu "$p")" accepted
check "select: accepted is not completion" "$([[ -e "$done_file" ]] && echo "done" || echo pending)" pending
check "select: selector state" "$(field 's.opened+"|"+s.mode+"|"+s.prompt+"|"+s.labels.join(",")')" "true|select|Pick|Alpha,Beta,Gamma"
check "select: layer mapped" "$(for _ in $(seq 1 25); do [[ $(layer_count) == 1 ]] && break; sleep 0.2; done; layer_count)" 1
ipc setFilter sub-b >/dev/null
check "select: filter matches subtext" "$(field 's.labels.join(",")')" Beta
ipc activate >/dev/null
check "select: returns label TAB subtext, glyph dropped" "$(result)" $'done:Beta\tsub-b'
check "select: selector closed after completion" "$(ipc isOpen)" false

new_request
ipc dmenu "$(payload select '{"options":["Alpha","Beta"]}')" >/dev/null
ipc move 1 >/dev/null
ipc activate >/dev/null
check "select: plain option returns label" "$(result)" "done:Beta"

# --- Metacharacters stay literal (fixed argv, positional data) -----------------
marker="$priv/must-not-exist"
literal="it's \"q\" \$(touch $marker); \`touch $marker\` & | > x"
new_request
ipc dmenu "$(payload input '{"prompt":"Text"}')" >/dev/null
check "input: mode and placeholder prompt" "$(field 's.mode+"|"+s.prompt+"|"+s.labels.length')" "input|Text|0"
ipc setFilter "$literal" >/dev/null
ipc activate >/dev/null
check "input: typed text returned literally" "$(result)" "done:$literal"
check "input: no command substitution executed" "$([[ -e "$marker" ]] && echo executed || echo literal)" literal
check "input: no stray file from redirection text" "$([[ -e "$priv/x" || -e x ]] && echo created || echo none)" none

# --- Cancellation through IPC close (same cancel() as Escape/click outside) ----
new_request
ipc dmenu "$(payload select '{"options":["Alpha"]}')" >/dev/null
ipc close >/dev/null
check "cancel (ipc close): done file, empty selection" "$(result)" "done:"

# --- Multiple with Apply ---------------------------------------------------------
new_request
ipc dmenu "$(payload select '{"options":["A","B","C"],"multiple":true,"selected":["C"]}')" >/dev/null
check "multiple: Apply row first, current selection marked" "$(field 's.labels.join(",")+"|"+s.rows.map(r=>r.icon).join("")')" "Apply,A,B,C|○○✓"
ipc move 1 >/dev/null
ipc activate >/dev/null
check "multiple: toggle keeps selector open" "$(ipc isOpen)" true
check "multiple: toggled values" "$(field 'JSON.stringify(s.dmenuSelected)')" '["C","A"]'
ipc move -1 >/dev/null
ipc activate >/dev/null
check "multiple: Apply returns JSON in option order" "$(result)" 'done:["A","C"]'

# --- Multiple with onChange (harmless synthetic command) ------------------------
changes="$priv/changes"
new_request
# shellcheck disable=SC2016  # $1/$2 belong to the synthetic onChange command.
on_change=$(node -e 'console.log(JSON.stringify(["sh","-c","printf \"%s\\n\" \"$2\" >> \"$1\"","sh",process.argv[1]]))' "$changes")
ipc dmenu "$(payload select "{\"options\":[\"A\",\"B\"],\"multiple\":true,\"onChange\":$on_change}")" >/dev/null
check "onChange: no Apply row" "$(field 's.labels.join(",")')" "A,B"
ipc activate >/dev/null
sleep 0.5
ipc move 1 >/dev/null
ipc activate >/dev/null
sleep 0.5
check "onChange: command ran per toggle with selection JSON" "$(paste -sd ' ' "$changes" 2>/dev/null)" '["A"] ["A","B"]'
check "onChange: checks follow applied selection" "$(field 's.rows.map(r=>r.icon).join("")')" "✓✓"
ipc close >/dev/null
check "onChange: close completes request with empty selection" "$(result)" "done:"

# Replacing a pending request (DEC-027 cancellation) is covered by
# check-selector-replacement.sh.

# --- Keyboard cancellation (attended, optional) ---------------------------------
if ((keyboard)); then
    new_request
    ipc dmenu "$(payload select '{"options":["Alpha"]}')" >/dev/null
    for _ in $(seq 1 25); do [[ $(layer_count) == 1 ]] && break; sleep 0.2; done
    sleep 0.5
    wtype -k Escape
    check "cancel (keyboard Escape): done file, empty selection" "$(result)" "done:"
    new_request
    ipc dmenu "$(payload select '{"options":["Alpha"]}')" >/dev/null
    for _ in $(seq 1 25); do [[ $(layer_count) == 1 ]] && break; sleep 0.2; done
    sleep 0.5
    wtype x
    wtype -k Escape
    check "cancel (keyboard): first Escape only clears the filter" "$([[ -e "$done_file" ]] && echo "done" || echo pending)|$(field 's.filter')" "pending|"
    wtype -k Escape
    check "cancel (keyboard): second Escape cancels" "$(result)" "done:"
else
    printf 'SKIP keyboard cancellation (run with --keyboard in an attended session)\n'
fi
printf 'UNVERIFIED pointer cancellation (click outside): not automated\n'

kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
pid=""
noisy=$(grep -Ei 'warn|error' "$tmp/shell.log" \
    | grep -v 'qt.qpa.wayland.textinput.*has focus' \
    | grep -v 'QWaylandTextInputv3::disableSurface.*is focused')
if [[ -n "$noisy" ]]; then fail "log is not quiet"; printf '%s\n' "$noisy"; else pass "log is quiet"; fi

if ((failures > 0)); then
    printf '%d check(s) failed\n' "$failures"
    exit 1
fi
printf 'All checks passed\n'
