import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, rmSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { tmpdir } from 'node:os'
import { spawn, spawnSync } from 'node:child_process'

const helper = resolve('capabilities/desktop/shell/services/wallpaper-thumbnails')
function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-thumbnails-'))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  const bin = join(dir, 'bin')
  const images = join(dir, 'images')
  mkdirSync(bin)
  mkdirSync(images)
  writeFileSync(join(bin, 'vipsthumbnail'), `#!/usr/bin/bash
set -eu
[[ $VIPS_CONCURRENCY == 1 && $2 == --size && $3 == 1536x864 && $4 == --smartcrop=centre && $5 == --path && $6 == *'[Q=82,strip]' ]]
printf '%s\\0' "$1" >> "$GENERATOR_LOG"
[[ $1 != */bad.png ]] || exit 1
sleep 0.03
printf thumbnail > "${'${6%[[]*}'}"
`, { mode: 0o755 })
  const env = { ...process.env, PATH: bin + ':' + process.env.PATH,
    XDG_CACHE_HOME: join(dir, 'cache'), GENERATOR_LOG: join(dir, 'generated') }
  const run = () => spawnSync('bash', [helper, images, join(dir, 'personal')], { env, encoding: 'utf8' })
  return { dir, images, env, run }
}

test('thumbnail cache uses reference settings, opaque NUL rows and stat invalidation', (t) => {
  const { dir, images, run } = fixture(t)
  const image = join(images, 'a\nline\t$(touch sentinel).png')
  writeFileSync(image, 'first')
  const first = run()
  assert.equal(first.status, 0, first.stderr)
  const rows = first.stdout.split('\0')
  assert.equal(rows[0], image)
  assert.match(rows[1], /\/mirroros\/image-selector\/[a-f0-9]{32}\.jpg$/)
  assert.equal(readFileSync(rows[1], 'utf8'), 'thumbnail')
  assert.equal(run().stdout, first.stdout)
  assert.equal(readFileSync(join(dir, 'generated'), 'utf8'), image + '\0')
  writeFileSync(image, 'different size')
  const changed = run()
  assert.equal(changed.status, 0, changed.stderr)
  assert.notEqual(changed.stdout, first.stdout)
  assert.equal(readdirSync(join(dir, 'cache/mirroros/image-selector')).filter((p) => p.endsWith('.jpg')).length, 2)
})

test('parallel calls share thumbnail locks and prune failed generators', async (t) => {
  const { dir, images, env } = fixture(t)
  writeFileSync(join(images, 'good.png'), 'image')
  writeFileSync(join(images, 'bad.png'), 'image')
  const results = await Promise.all([0, 1].map(() => new Promise((resolveResult, reject) => {
    const child = spawn('bash', [helper, images, join(dir, 'personal')], { env })
    let stdout = ''
    let stderr = ''
    child.stdout.on('data', (data) => { stdout += data })
    child.stderr.on('data', (data) => { stderr += data })
    child.on('error', reject)
    child.on('exit', (status) => resolveResult({ status, stdout, stderr }))
  })))
  for (const result of results) {
    assert.equal(result.status, 0, result.stderr)
    assert.match(result.stdout, /good.png/)
    assert.doesNotMatch(result.stdout, /bad.png/)
  }
  const generated = readFileSync(join(dir, 'generated'), 'utf8').split('\0')
  assert.equal(generated.filter((path) => path.endsWith('/good.png')).length, 1)
})
