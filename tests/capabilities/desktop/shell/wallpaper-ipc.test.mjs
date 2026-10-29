// Isolated native IPC and filesystem contract; not input or visual qualification.
import test from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, mkdtempSync, mkdirSync, cpSync, writeFileSync, readFileSync, readlinkSync, symlinkSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'

const available = existsSync('/usr/bin/qs') && existsSync('/usr/bin/dbus-run-session') &&
  existsSync('/usr/lib/qt6/plugins/platforms/libqoffscreen.so')

test('native wallpaper IPC uses links, fresh scans, outside files and integrated picker', { skip: !available }, (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-wallpaper-ipc-'))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  mkdirSync(join(dir, 'runtime'), { mode: 0o700 })
  cpSync(resolve('capabilities/desktop/shell/services'), join(dir, 'services'), { recursive: true })
  cpSync(resolve('capabilities/desktop/shell/Commons'), join(dir, 'Commons'), { recursive: true })
  const theme = join(dir, 'a-theme')
  const product = join(theme, 'backgrounds')
  const config = join(dir, 'z-config')
  const personal = join(config, 'mirroros/backgrounds/a-theme')
  const current = join(dir, 'state/mirroros/current')
  mkdirSync(product, { recursive: true })
  mkdirSync(personal, { recursive: true })
  mkdirSync(current, { recursive: true })
  symlinkSync(theme, join(current, 'theme'))
  const first = join(product, 'first.png')
  const special = join(personal, 'a space\n$(touch should-not-exist).png')
  const outside = join(dir, 'outside.data')
  for (const file of [first, special, outside]) writeFileSync(file, 'existing but not decodable')
  symlinkSync(first, join(current, 'background'))
  const bin = join(dir, 'bin')
  mkdirSync(bin)
  writeFileSync(join(bin, 'vipsthumbnail'), '#!/usr/bin/bash\nsleep 0.1\nprintf thumbnail > "${6%[[]*}"\n', { mode: 0o755 })
  writeFileSync(join(bin, 'nautilus'), '#!/usr/bin/bash\nprintf "%s" "$1" > "$FILE_MANAGER_LOG"\n', { mode: 0o755 })
  const probe = join(dir, 'probe.qml')
  const log = join(dir, 'shell.log')
  writeFileSync(probe, `import QtQuick
import Quickshell
import Quickshell.Io
import "services"
ShellRoot {
  QtObject {
    id: fakePicker
    property bool opened: false
    function open(output, current) { opened = true; return true }
    function cancel() { opened = false }
  }
  QtObject { id: notices; property string last: ""; function showPlaceholder(text) { last = text } }
  WallpaperLibrary { id: catalog }
  WallpaperActions { id: actions; picker: fakePicker; library: catalog; notifications: notices }
  IpcHandler {
    target: "probe"
    function snapshot(): string { return JSON.stringify({ busy: actions.busy, path: actions.currentPath,
      opened: fakePicker.opened, images: catalog.images, error: catalog.error, notice: notices.last }) }
    function install(): string { return actions.install() }
  }
  Timer { interval: 15000; running: true; onTriggered: Qt.quit() }
}
`)
  const result = spawnSync('/usr/bin/dbus-run-session', ['--', 'bash', '-c', `
    set -e
    qs -p "$1" > "$2" 2>&1 &
    pid=$!
    trap 'kill "$pid" 2>/dev/null || :; wait "$pid" 2>/dev/null || :' EXIT
    call() { qs ipc -p "$1" call wallpaper "${'${@:2}'}"; }
    snapshot() { qs ipc -p "$1" call probe snapshot; }
    wait_idle() {
      for ((i=0; i<150; i++)); do
        state=$(snapshot "$1" 2>/dev/null) || state=""
        if [[ $state == *'"busy":false'* ]]; then printf '%s\n' "$state"; return; fi
        kill -0 "$pid" 2>/dev/null || exit 1
        sleep 0.03
      done
      exit 1
    }
    wait_idle "$1"
    call "$1" set "$3"
    wait_idle "$1"
    call "$1" next
    wait_idle "$1"
    call "$1" set "$4"
    wait_idle "$1"
    call "$1" next
    wait_idle "$1"
    call "$1" set /missing.png
    wait_idle "$1"
    call "$1" open >/dev/null
    call "$1" close >/dev/null
    wait_idle "$1" | grep -q '"opened":false'
    call "$1" open
    wait_idle "$1"
    call "$1" close
    wait_idle "$1"
    mv -- "$3" "$4.image"
    rmdir -- "${'${3%/*}'}"
    qs ipc -p "$1" call probe install
    wait_idle "$1"
    for ((i=0; i<100; i++)); do [[ -f $5 ]] && break; sleep 0.03; done
    [[ -f $5 ]]
    mv -- "$4.image" "$3"
    printf fresh > "$6/0-new.png"
    call "$1" set "$4"
    wait_idle "$1" >/dev/null
    call "$1" next
    wait_idle "$1"
    rm -- "$6/0-new.png" "$6/first.png" "$3"
    call "$1" next
    wait_idle "$1"
  `, 'mirroros-wallpaper-ipc-test', probe, log, special, outside, join(dir, 'nautilus.log'), product], {
    cwd: dir,
    env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', XDG_RUNTIME_DIR: join(dir, 'runtime'),
      XDG_CONFIG_HOME: config, XDG_STATE_HOME: join(dir, 'state'), XDG_CACHE_HOME: join(dir, 'cache'),
      PATH: bin + ':' + process.env.PATH, FILE_MANAGER_LOG: join(dir, 'nautilus.log'), NO_COLOR: '1' },
    encoding: 'utf8', timeout: 20000,
  })
  const output = (result.stdout || '') + (result.stderr || '')
  const diagnostic = output + readFileSync(log, 'utf8')
  assert.equal(result.status, 0, diagnostic)
  const states = output.split('\n').filter((line) => line.startsWith('{')).map((line) => JSON.parse(line))
  assert.deepEqual(states.slice(0, 6).map((s) => s.path), [first, special, first, outside, first, first], diagnostic)
  assert.equal(states[6].opened, true, diagnostic)
  assert.equal(states[6].images.length, 2, diagnostic)
  assert.equal(states[7].opened, false)
  assert.equal(readFileSync(join(dir, 'nautilus.log'), 'utf8'), personal)
  assert.equal(states[9].path, join(product, '0-new.png'), diagnostic)
  assert.equal(states[10].notice, 'No background was found for theme', diagnostic)
  assert.equal(readlinkSync(join(current, 'background')), join(product, '0-new.png'))
  assert.equal(existsSync(join(dir, 'should-not-exist')), false)
  assert.doesNotMatch(diagnostic, /ReferenceError|TypeError|Binding loop|Failed to load configuration/)
})
