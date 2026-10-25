#!/usr/bin/bash
# Run ONLY after fresh maintainer authorization for the three runtime commands.
# No bindings/configuration files are edited and the compositor is not reloaded.
set -Eeuo pipefail
if [[ "${1:-}" != --authorized-runtime-layout-test ]]; then
    printf 'BLOCKED fresh authorization required for temporary us,es runtime layout test\n'; exit 2
fi
tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
shell_dir=$(cd "$tests_dir/../../../../capabilities/desktop/shell" && pwd)
for tool in node qs hyprctl busctl; do
    command -v "$tool" >/dev/null || { printf 'BLOCKED missing tool: %s\n' "$tool"; exit 2; }
done
node "$tests_dir/qmllint-check.mjs"
hyprctl getoption input:kb_layout | grep -qx 'str: us' || { printf 'BLOCKED initial layout is not us\n'; exit 2; }
owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications)
[[ "$owner" == 'b false' ]] || { printf 'BLOCKED Notifications already owned; no replacement attempted\n'; exit 2; }
hyprctl -j devices | node --input-type=module -e '
import fs from "node:fs";
const keyboards = JSON.parse(fs.readFileSync(0,"utf8")).keyboards;
if(!keyboards.some(k=>k.name==="at-translated-set-2-keyboard" && k.layout==="us"))process.exit(1);
'
tmp=$(mktemp -d)
pid=""
changed=false
cleanup() {
    local result=$?
    trap - EXIT
    if [[ "$changed" == true ]]; then
        printf 'Cleanup: restoring input:kb_layout us\n'
        if ! hyprctl eval 'hl.config({ input = { kb_layout = "us" } })'; then result=1; fi
        if ! hyprctl getoption input:kb_layout | grep -qx 'str: us'; then result=1; fi
    fi
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
    rm -rf "$tmp"
    exit "$result"
}
trap cleanup EXIT
cp -r "$shell_dir" "$tmp/shell"
mkdir -p "$tmp/home" "$tmp/config" "$tmp/data/applications" "$tmp/state"
node --input-type=module - "$tmp/shell/shell.qml" <<'JS'
import fs from 'node:fs';
const file=process.argv[2];
let qml=fs.readFileSync(file,'utf8').replace('import Quickshell\n','import Quickshell\nimport Quickshell.Io\n');
qml=qml.trimEnd().slice(0,-1)+`
  IpcHandler {
    target: "keyboardTest"
    function state(): string {
      var items = desktopShell.bar.moduleWidgets("omarchy.keyboard-layout")
      if (!items.length) return "{}"
      var w = items[0]
      return JSON.stringify({ read: w.layoutsRead, full: w.layoutFull, label: w.layoutLabel,
        keyboard: w.keyboardName, multiple: w.multipleLayouts, visible: w.visible,
        index: w.layoutIndex, count: w.layoutCount })
    }
  }
}
`;
fs.writeFileSync(file,qml);
JS
state() { qs ipc -p "$tmp/shell" call keyboardTest state; }
start() {
    HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" \
        MIRROROS_SHELL_STATE_DIR="$tmp/state" qs -p "$tmp/shell" > "$tmp/shell.log" 2>&1 &
    pid=$!
    for ((i=0; i<100; i++)); do
        if state > "$tmp/state.json" 2>/dev/null && node -e 'if(!JSON.parse(require("fs").readFileSync(process.argv[1])).read)process.exit(1)' "$tmp/state.json"; then return; fi
        if ! kill -0 "$pid" 2>/dev/null; then printf 'FAIL shell exited\n%s\n' "$(<"$tmp/shell.log")"; exit 1; fi
        sleep 0.1
    done
    printf 'FAIL keyboard widget not ready\n%s\n' "$(<"$tmp/shell.log")"; exit 1
}
stop() {
    kill "$pid"; wait "$pid" 2>/dev/null || true; pid=""
    local warnings
    warnings=$(grep -E 'WARN|ERROR|Warning|Error|TypeError|ReferenceError|Binding loop' "$tmp/shell.log" || true)
    [[ -z "$warnings" ]] || { printf 'FAIL keyboard log not quiet\n%s\n' "$warnings"; exit 1; }
}
await_state() {
    for ((i=0; i<100; i++)); do
        state > "$tmp/state.json"
        if node --input-type=module - "$tmp/state.json" "$1" <<'JS'
import fs from 'node:fs';
const s=JSON.parse(fs.readFileSync(process.argv[2]));
if(!new Function('s', 'return '+process.argv[3])(s))process.exit(1);
JS
        then printf '%s\n' "$(<"$tmp/state.json")"; return; fi
        sleep 0.1
    done
    printf 'FAIL keyboard state: %s\n' "$(<"$tmp/state.json")"; exit 1
}
start
await_state 's.read && !s.multiple && !s.visible && s.count===1'
printf 'PASS single us layout is hidden\n'
stop
changed=true
printf 'Authorized: hyprctl eval setting input.kb_layout to us,es\n'
hyprctl eval 'hl.config({ input = { kb_layout = "us,es" } })'
if ! hyprctl getoption input:kb_layout | grep -qx 'str: us,es'; then
    if hyprctl getoption input:kb_layout | grep -qx 'str: us'; then changed=false; fi
    printf 'FAIL authorized Lua layout change did not apply\n'; exit 1
fi
start
await_state 's.read && s.multiple && s.visible && s.label==="EN" && s.index===0 && s.count===2'
printf 'PASS us,es displays EN from real xkb data\n'
printf 'Authorized: hyprctl switchxkblayout at-translated-set-2-keyboard next\n'
hyprctl switchxkblayout at-translated-set-2-keyboard next
await_state 's.visible && s.label==="ES" && s.index===1 && s.full==="Spanish" && s.keyboard==="at-translated-set-2-keyboard"'
printf 'PASS native activelayout updates indicator to ES\n'
printf 'Authorized: hyprctl eval restoring input.kb_layout to us\n'
hyprctl eval 'hl.config({ input = { kb_layout = "us" } })'
hyprctl getoption input:kb_layout | grep -qx 'str: us'
changed=false
await_state 's.read && !s.multiple && !s.visible && s.index===0 && s.count===1'
hyprctl -j devices | node --input-type=module -e '
import fs from "node:fs";
const keyboards=JSON.parse(fs.readFileSync(0,"utf8")).keyboards;
if(!keyboards.every(k=>k.layout==="us" && k.active_layout_index===0))process.exit(1);
'
printf 'PASS restored us on all keyboards; indicator hidden again without reload\n'
stop
printf 'PASS authorized runtime keyboard observation; no bindings or files changed\n'
