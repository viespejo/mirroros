import test from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const { next, parse, loadRows, indexForSelectedImage } = require('../../../../capabilities/desktop/shell/Commons/WallpaperCatalog.js')

test('cycles all ordered entries, wraps, and starts at the first for outside selections', () => {
  const paths = ['/product/one.png', '/personal/one.png', '/personal/two.png']
  assert.equal(next(paths, paths[0]), paths[1])
  assert.equal(next(paths, paths[2]), paths[0])
  assert.equal(next(paths, '/outside.png'), paths[0])
  assert.equal(next([], 'old'), null)
  assert.equal(next(null, 'old'), null)
})

test('parses complete NUL records without deduplication or a selection membership gate', () => {
  const paths = ['/product/same.png', '/personal/same.png', '/personal/line\nbreak\t$(touch file).png']
  assert.deepEqual(parse(paths.join('\0') + '\0'), paths)
  assert.deepEqual(parse(paths[0] + '\0' + paths[0] + '\0'), [paths[0], paths[0]])
  assert.deepEqual(parse(''), [])
  assert.equal(parse('/truncated.png'), null)
  assert.equal(parse('relative.png\0'), null)
})

test('picker uses first sorted basename, thumbnail pairs and current selection identity', () => {
  const images = loadRows('/a/same.png\0/cache/a.jpg\0/z/same.png\0/cache/z.jpg\0/z/other.png\0/cache/other.jpg\0')
  assert.deepEqual(images, [
    { filePath: '/a/same.png', fileName: 'same.png', thumbnailPath: '/cache/a.jpg' },
    { filePath: '/z/other.png', fileName: 'other.png', thumbnailPath: '/cache/other.jpg' },
  ])
  assert.equal(indexForSelectedImage(images, '/z/other.png'), 1)
  assert.equal(indexForSelectedImage(images, '/outside.png'), 0)
  assert.deepEqual(loadRows(''), [])
  assert.equal(loadRows('/unpaired.png\0'), null)
})
