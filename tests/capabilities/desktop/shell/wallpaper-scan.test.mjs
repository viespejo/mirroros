// Extension/catalog tests: fixture contents are not image decoding evidence.
import test from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { mkdtempSync, mkdirSync, writeFileSync, symlinkSync, readFileSync, rmSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { tmpdir } from 'node:os'
import { spawnSync } from 'node:child_process'

const require = createRequire(import.meta.url)
const { parse } = require('../../../../capabilities/desktop/shell/Commons/WallpaperCatalog.js')
const scanner = resolve('capabilities/desktop/shell/services/list-wallpapers')

test('scan combines direct product and personal images with opaque paths and links', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-wallpaper-scan-'))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  const product = join(dir, 'product')
  const personal = join(dir, 'personal')
  mkdirSync(product)
  mkdirSync(personal)
  const names = ['a space.png', 'line\nbreak.PNG', '$(touch file).webp']
  for (const name of names) writeFileSync(join(personal, name), 'fixture')
  writeFileSync(join(product, 'a space.png'), 'product fixture')
  writeFileSync(join(personal, 'notes.txt'), 'preserved')
  symlinkSync(join(personal, names[0]), join(personal, 'linked.png'))
  mkdirSync(join(personal, 'nested'))
  writeFileSync(join(personal, 'nested/hidden.png'), 'fixture')
  const result = spawnSync('bash', [scanner, product, personal], { encoding: 'utf8' })
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(new Set(parse(result.stdout)), new Set([
    ...names.map((name) => join(personal, name)), join(product, 'a space.png'), join(personal, 'linked.png'),
  ]))
  assert.equal(readFileSync(join(personal, 'notes.txt'), 'utf8'), 'preserved')
  assert.equal(readFileSync(join(product, 'a space.png'), 'utf8'), 'product fixture')
})

test('theme directory links are resolved before listing, matching the saved real path', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-wallpaper-scan-'))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  const theme = join(dir, 'themes/default')
  const backgrounds = join(theme, 'backgrounds')
  mkdirSync(backgrounds, { recursive: true })
  writeFileSync(join(backgrounds, '1-first.png'), 'fixture')
  const current = join(dir, 'current-theme')
  symlinkSync(theme, current)
  const result = spawnSync('bash', [scanner, join(current, 'backgrounds'), join(dir, 'personal')], { encoding: 'utf8' })
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(parse(result.stdout), [join(backgrounds, '1-first.png')])
})

test('missing catalogs are empty but conflicting paths and malformed arguments fail', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'mirroros-wallpaper-scan-'))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  const missing = join(dir, 'missing')
  let result = spawnSync('bash', [scanner, missing, missing], { encoding: 'utf8' })
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(parse(result.stdout), [])
  const conflict = join(dir, 'conflict')
  writeFileSync(conflict, 'preserve')
  result = spawnSync('bash', [scanner, conflict, missing], { encoding: 'utf8' })
  assert.notEqual(result.status, 0)
  assert.equal(readFileSync(conflict, 'utf8'), 'preserve')
  result = spawnSync('bash', [scanner, 'relative', missing], { encoding: 'utf8' })
  assert.equal(result.status, 2)
})
