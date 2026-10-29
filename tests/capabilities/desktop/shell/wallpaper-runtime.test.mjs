// Isolated Weston decoding/lifecycle probe, not input or visual qualification.
import test from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, mkdtempSync, mkdirSync, cpSync, writeFileSync, readFileSync, readlinkSync, symlinkSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'
import { deflateSync } from 'node:zlib'

const available = existsSync('/usr/bin/qs') && existsSync('/usr/bin/dbus-run-session') && existsSync('/usr/bin/weston')

function crc32(buffer) {
  let crc = 0xffffffff
  for (const byte of buffer) {
    crc ^= byte
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0)
  }
  return (crc ^ 0xffffffff) >>> 0
}
function chunk(type, data) {
  const body = Buffer.concat([Buffer.from(type), data])
  const length = Buffer.alloc(4)
  const crc = Buffer.alloc(4)
  length.writeUInt32BE(data.length)
  crc.writeUInt32BE(crc32(body))
  return Buffer.concat([length, body, crc])
}
function png(red, green, blue) {
  const header = Buffer.alloc(13)
  header.writeUInt32BE(1, 0)
  header.writeUInt32BE(1, 4)
  header[8] = 8
  header[9] = 2
  return Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), chunk('IHDR', header),
    chunk('IDAT', deflateSync(Buffer.from([0, red, green, blue]))), chunk('IEND', Buffer.alloc(0))])
}

test('isolated shared reveal, corrupt persistence, startup and integrated picker', { skip: !available }, (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-wallpaper-runtime-'))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  const runtime = join(dir, 'runtime')
  mkdirSync(runtime, { mode: 0o700 })
  const shell = join(dir, 'qs')
  cpSync(resolve('capabilities/desktop/shell'), shell, { recursive: true })
  const current = join(dir, 'state/mirroros/current')
  mkdirSync(current, { recursive: true })
  const first = join(dir, 'first.png')
  const second = join(dir, 'second.png')
  const corrupt = join(dir, 'corrupt.png')
  writeFileSync(first, png(20, 120, 60))
  writeFileSync(second, png(30, 60, 140))
  writeFileSync(corrupt, 'not an image')
  symlinkSync(first, join(current, 'background'))
  const composition = `
  WallpaperLibrary { id: library }
  WallpaperActions { id: actions; library: library; wallpaper: wallpaper }
  Wallpaper { id: wallpaper }
  WallpaperPicker {
    id: picker
    images: [{ filePath: ${JSON.stringify(first)}, thumbnailPath: ${JSON.stringify(first)} },
      { filePath: ${JSON.stringify(second)}, thumbnailPath: ${JSON.stringify(second)} }]
    onSelected: function(path) { console.log("PICKED " + path); actions.selectPath(path) }
  }
  function snapshot(label) { console.log(label + " " + JSON.stringify({
    current: wallpaper.currentBackground, displayed: wallpaper.displayedBackground,
    incoming: wallpaper.incomingBackground, progress: wallpaper.revealProgress, busy: actions.busy })) }
`
  const probe = join(shell, 'probe.qml')
  const restart = join(shell, 'restart.qml')
  writeFileSync(probe, `import Quickshell
import QtQuick
import "services"
import "menu"
ShellRoot {
  ${composition}
  QtObject {
    id: menuActions
    function openPicker(output) { console.log("MENU_BACKGROUND"); return "accepted" }
    function install() { console.log("MENU_INSTALL_BACKGROUND"); return "accepted" }
  }
  Menu { id: backgroundMenu; wallpaperActions: menuActions }
  Timer { interval: 100; running: true; onTriggered: {
    backgroundMenu.openRoute("wallpaper")
    backgroundMenu.openRoute("install.style.background")
  } }
  Timer { interval: 600; running: true; onTriggered: snapshot("INITIAL") }
  Timer { interval: 700; running: true; onTriggered: actions.selectPath(${JSON.stringify(second)}) }
  Timer { interval: 1400; running: true; onTriggered: snapshot("SECOND") }
  Timer { interval: 1500; running: true; onTriggered: actions.selectPath(${JSON.stringify(corrupt)}) }
  Timer { interval: 2100; running: true; onTriggered: snapshot("CORRUPT") }
  Timer { interval: 2200; running: true; onTriggered: {
    picker.open(Quickshell.screens[0], ${JSON.stringify(first)})
    console.log("PICKER_OPEN " + picker.opened)
    picker.selectAdjacent(1)
    picker.applySelected()
    console.log("PICKER_CLOSED " + !picker.opened)
  } }
  Timer { interval: 2900; running: true; onTriggered: snapshot("RECOVERED") }
  Timer { interval: 3000; running: true; onTriggered: actions.selectPath(${JSON.stringify(corrupt)}) }
  Timer { interval: 3400; running: true; onTriggered: Qt.quit() }
}
`)
  writeFileSync(restart, `import Quickshell
import QtQuick
import "services"
ShellRoot {
  ${composition}
  Timer { interval: 800; running: true; onTriggered: { snapshot("RESTART"); Qt.quit() } }
}
`)
  const fullProbe = join(shell, 'shell.qml')
  const fullSource = readFileSync(fullProbe, 'utf8').replace('import Quickshell', 'import QtQuick\nimport Quickshell')
  const closing = fullSource.lastIndexOf('}')
  writeFileSync(fullProbe, fullSource.slice(0, closing)
    + '  Timer { interval: 1200; running: true; onTriggered: { console.log("FULL_SHELL_LOADED"); Qt.quit() } }\n'
    + fullSource.slice(closing))
  const result = spawnSync('/usr/bin/dbus-run-session', ['--', 'bash', '-c', `
    set -e
    weston --backend=headless --renderer=pixman --socket=wallpaper-test --idle-time=0 --width=800 --height=600 > "$2" 2>&1 &
    compositor=$!
    trap 'kill "$compositor" 2>/dev/null || :; wait "$compositor" 2>/dev/null || :' EXIT
    for ((i=0; i<100; i++)); do
      [[ -S $XDG_RUNTIME_DIR/wallpaper-test ]] && break
      kill -0 "$compositor" 2>/dev/null || exit 1
      sleep 0.05
    done
    timeout 8 qs -p "$1"
    timeout 8 qs -p "$3"
    timeout 8 qs -p "$4"
  `, 'mirroros-wallpaper-test', probe, join(dir, 'weston.log'), restart, fullProbe], {
    env: { ...process.env, QT_QPA_PLATFORM: 'wayland', QT_QUICK_BACKEND: 'software',
      XDG_RUNTIME_DIR: runtime, WAYLAND_DISPLAY: 'wallpaper-test', NO_COLOR: '1', QML_IMPORT_PATH: dir,
      XDG_CONFIG_HOME: join(dir, 'config'), XDG_STATE_HOME: join(dir, 'state'), XDG_CACHE_HOME: join(dir, 'cache') },
    encoding: 'utf8', timeout: 22000,
  })
  const output = (result.stdout || '') + (result.stderr || '')
  assert.equal(result.status, 0, output)
  function state(label) {
    const match = output.match(new RegExp(label + ' (\\{[^\\n]*\\})'))
    assert.ok(match, output)
    return JSON.parse(match[1])
  }
  assert.equal(state('INITIAL').displayed, first, output)
  assert.equal(state('SECOND').displayed, second, output)
  assert.equal(state('SECOND').progress, 1, output)
  assert.equal(state('CORRUPT').current, corrupt, output)
  assert.equal(state('CORRUPT').displayed, second, output)
  assert.equal(state('CORRUPT').incoming, corrupt, output)
  assert.equal(state('CORRUPT').progress, 0, output)
  assert.equal(state('RECOVERED').displayed, second, output)
  assert.equal(state('RESTART').displayed, corrupt, output)
  assert.equal(state('RESTART').incoming, '', output)
  assert.equal(readlinkSync(join(current, 'background')), corrupt)
  assert.match(output, /PICKER_OPEN true/)
  assert.match(output, /PICKER_CLOSED true/)
  assert.match(output, /PICKED .*second.png/)
  assert.match(output, /FULL_SHELL_LOADED/)
  assert.match(output, /MENU_BACKGROUND/)
  assert.match(output, /MENU_INSTALL_BACKGROUND/)
  assert.doesNotMatch(output, /ReferenceError|TypeError|Binding loop|Failed to load configuration/)
})
