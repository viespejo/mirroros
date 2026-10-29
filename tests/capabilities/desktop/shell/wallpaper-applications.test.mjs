// Real application smoke tests; not input, visual or installed-session qualification.
import test from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, mkdtempSync, mkdirSync, cpSync, writeFileSync, readFileSync, readdirSync, statSync, rmSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { tmpdir } from 'node:os'
import { pathToFileURL } from 'node:url'
import { spawnSync } from 'node:child_process'

const hasVips = existsSync('/usr/bin/vipsthumbnail') && existsSync('/usr/bin/vipsheader')
const hasNautilus = ['nautilus', 'dbus-run-session', 'weston', 'gdbus'].every((name) => existsSync('/usr/bin/' + name))

function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-wallpaper-applications-'))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  const env = { ...process.env, HOME: dir, XDG_CONFIG_HOME: join(dir, 'config'),
    XDG_STATE_HOME: join(dir, 'state'), XDG_CACHE_HOME: join(dir, 'cache'),
    XDG_DATA_HOME: join(dir, 'data'), XDG_RUNTIME_DIR: join(dir, 'runtime') }
  mkdirSync(env.XDG_RUNTIME_DIR, { mode: 0o700 })
  return { dir, env }
}

test('real libvips decodes all product backgrounds and reuses cached JPEG thumbnails', { skip: !hasVips }, (t) => {
  const { dir, env } = fixture(t)
  const images = join(dir, 'images')
  cpSync(resolve('capabilities/visual/theme/default/backgrounds'), images, { recursive: true })
  writeFileSync(join(images, 'corrupt.png'), 'not an image')
  const helper = resolve('capabilities/desktop/shell/services/wallpaper-thumbnails')
  const run = () => spawnSync('/usr/bin/bash', [helper, images, join(dir, 'personal')], { env, encoding: 'utf8', timeout: 60000 })
  const first = run()
  assert.equal(first.status, 0, first.stderr)
  const rows = first.stdout.split('\0').slice(0, -1)
  assert.equal(rows.length, 12, first.stderr)
  const stamps = new Map()
  for (let i = 0; i < rows.length; i += 2) {
    assert.notEqual(rows[i], join(images, 'corrupt.png'))
    const thumbnail = rows[i + 1]
    assert.equal(readFileSync(thumbnail).subarray(0, 3).toString('hex'), 'ffd8ff')
    for (const [field, expected] of [['width', '1536'], ['height', '864']]) {
      const result = spawnSync('/usr/bin/vipsheader', ['-f', field, thumbnail], { encoding: 'utf8' })
      assert.equal(result.status, 0, result.stderr)
      assert.equal(result.stdout.trim(), expected)
    }
    stamps.set(thumbnail, statSync(thumbnail).mtimeMs)
  }
  const second = run()
  assert.equal(second.status, 0, second.stderr)
  assert.equal(second.stdout, first.stdout)
  for (const [path, stamp] of stamps) assert.equal(statSync(path).mtimeMs, stamp)
  assert.equal(readdirSync(join(env.XDG_CACHE_HOME, 'mirroros/image-selector')).filter((name) => name.endsWith('.jpg')).length, 6)
})

test('real Nautilus starts on private D-Bus and headless Weston with an isolated personal folder', { skip: !hasNautilus }, (t) => {
  const { dir, env } = fixture(t)
  const personal = join(env.XDG_CONFIG_HOME, 'mirroros/backgrounds/default')
  mkdirSync(personal, { recursive: true })
  const result = spawnSync('/usr/bin/dbus-run-session', ['--', '/usr/bin/bash', '-c', `
    set -Eeuo pipefail
    weston --backend=headless --renderer=pixman --socket=wallpaper-app-test --idle-time=0 > "$1/weston.log" 2>&1 &
    compositor=$!
    app=""
    cleanup() {
      if [[ -n $app ]]; then
        kill "$app" 2>/dev/null || :
        wait "$app" 2>/dev/null || :
      fi
      kill "$compositor" 2>/dev/null || :
      wait "$compositor" 2>/dev/null || :
    }
    trap cleanup EXIT
    for ((i=0; i<100; i++)); do
      [[ -S $XDG_RUNTIME_DIR/wallpaper-app-test ]] && break
      kill -0 "$compositor"
      sleep 0.05
    done
    nautilus --new-window "$2" > "$1/nautilus.log" 2>&1 &
    app=$!
    for ((i=0; i<100; i++)); do
      kill -0 "$app"
      if gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.NameHasOwner org.gnome.Nautilus | grep -q true; then
        sleep 2
        kill -0 "$app"
        gdbus introspect --session --dest org.gnome.Nautilus --object-path /org/gnome/Nautilus > "$1/introspection.log"
        grep -q org.freedesktop.Application "$1/introspection.log"
        gdbus call --session --dest org.gnome.Nautilus --object-path /org/freedesktop/FileManager1 --method org.freedesktop.DBus.Properties.Get org.freedesktop.FileManager1 OpenLocations
        printf 'NAUTILUS_READY\\n'
        exit 0
      fi
      sleep 0.05
    done
    exit 1
  `, 'mirroros-wallpaper-app-test', dir, personal], {
    env: { ...env, XDG_SESSION_TYPE: 'wayland', WAYLAND_DISPLAY: 'wallpaper-app-test', GDK_BACKEND: 'wayland', GSK_RENDERER: 'cairo',
      GTK_USE_PORTAL: '0', NO_AT_BRIDGE: '1' },
    encoding: 'utf8', timeout: 20000,
  })
  const log = existsSync(join(dir, 'nautilus.log')) ? readFileSync(join(dir, 'nautilus.log'), 'utf8') : ''
  assert.equal(result.status, 0, result.stdout + result.stderr + log)
  assert.match(result.stdout, /NAUTILUS_READY/)
  assert.ok(result.stdout.includes(pathToFileURL(personal).href), result.stdout)
  if (log.trim()) t.diagnostic(log.trim())
  assert.doesNotMatch(log, /Gtk-ERROR|Failed to open display|cannot open display|assertion failed/)
})
