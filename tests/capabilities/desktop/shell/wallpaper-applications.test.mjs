// Real application smoke tests; not input, visual or installed-session qualification.
import test from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, mkdtempSync, mkdirSync, cpSync, writeFileSync, readFileSync, readdirSync, statSync, rmSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { tmpdir } from 'node:os'
import { spawnSync } from 'node:child_process'

const hasVips = existsSync('/usr/bin/vipsthumbnail') && existsSync('/usr/bin/vipsheader')
const hasXdgOpen = ['xdg-open', 'xdg-mime', 'file'].every((name) => existsSync('/usr/bin/' + name))

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

test('install action opens the personal folder through xdg-open and the inode/directory handler', { skip: !hasXdgOpen }, (t) => {
  const { dir, env } = fixture(t)
  const source = readFileSync(resolve('capabilities/desktop/shell/services/WallpaperActions.qml'), 'utf8')
  assert.doesNotMatch(source, /nautilus/i)
  const launches = [...source.matchAll(/Quickshell\.execDetached\((\[[^\]]*\])\)/g)].map((match) => match[1])
  assert.deepEqual(launches, ['["xdg-open", root.library.personalDirectory]'])
  const personal = join(env.XDG_CONFIG_HOME, 'mirroros/backgrounds/default')
  mkdirSync(personal, { recursive: true })
  const handler = join(dir, 'handler')
  const handlerLog = join(dir, 'handler.log')
  writeFileSync(handler, '#!/usr/bin/bash\nprintf "%s" "$1" > "$HANDLER_LOG"\n', { mode: 0o755 })
  mkdirSync(join(env.XDG_DATA_HOME, 'applications'), { recursive: true })
  writeFileSync(join(env.XDG_DATA_HOME, 'applications/mirroros-probe.desktop'),
    `[Desktop Entry]\nType=Application\nName=Probe\nExec=${handler} %f\nMimeType=inode/directory;\n`)
  writeFileSync(join(env.XDG_CONFIG_HOME, 'mimeapps.list'), '[Default Applications]\ninode/directory=mirroros-probe.desktop\n')
  const result = spawnSync('/usr/bin/xdg-open', [personal], {
    env: { PATH: '/usr/bin', HOME: env.HOME, XDG_CONFIG_HOME: env.XDG_CONFIG_HOME, XDG_DATA_HOME: env.XDG_DATA_HOME,
      XDG_CONFIG_DIRS: join(dir, 'none'), XDG_DATA_DIRS: join(dir, 'none'), XDG_RUNTIME_DIR: env.XDG_RUNTIME_DIR,
      WAYLAND_DISPLAY: 'wallpaper-app-test', BROWSER: '/usr/bin/false', HANDLER_LOG: handlerLog },
    encoding: 'utf8', timeout: 20000,
  })
  assert.equal(result.status, 0, result.stdout + result.stderr)
  assert.equal(readFileSync(handlerLog, 'utf8'), personal)
})
