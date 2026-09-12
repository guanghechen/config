import assert from 'node:assert/strict'
import { test } from 'node:test'
import { imageNodes, rasterMime } from '../shared/whiteboard/images.ts'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'

test('image import recognizes raster signatures without trusting names or supplied MIME types', () => {
  const bytes = text => new TextEncoder().encode(text)
  assert.equal(rasterMime(Uint8Array.from([137, 80, 78, 71, 13, 10, 26, 10])), 'image/png')
  assert.equal(rasterMime(Uint8Array.from([255, 216, 255, 224])), 'image/jpeg')
  assert.equal(rasterMime(bytes('GIF89a\0\0\0\0\0\0')), 'image/gif')
  assert.equal(rasterMime(bytes('GIF87a\0\0\0\0\0\0')), 'image/gif')
  assert.equal(rasterMime(bytes('RIFF1234WEBP')), 'image/webp')
  for (const content of ['', '<svg></svg>', '<html>', 'PNG', 'RIFF1234WAVE'])
    assert.equal(rasterMime(bytes(content)), undefined)
})

test('batch image placement keeps aspect ratios, caps initial display size and retains portable URLs', () => {
  const url =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9XkAAAAASUVORK5CYII='
  const images = [
    { url, width: 2400, height: 1200, optimized: false },
    { url, width: 300, height: 600, optimized: false },
    { url, width: 1, height: 2000, optimized: true },
  ]
  const nodes = imageNodes(images, { x: -400, y: 200 }, DEFAULT_STYLE)
  assert.deepEqual(
    nodes.map(({ x, y, width, height }) => ({ x, y, width, height })),
    [
      { x: -800, y: 0, width: 800, height: 400 },
      { x: -526, y: -76, width: 300, height: 600 },
      { x: -352.5, y: -52, width: 1, height: 600 },
    ],
  )
  assert.equal(new Set(nodes.map(node => node.id)).size, 3)
  assert.ok(nodes.every(node => node.url === url))
  const initial = createDocument()
  const store = new BoardStore(initial)
  const document = parseDocument(JSON.stringify({ ...initial, elements: nodes }))
  store.commit(document)
  store.undo()
  assert.equal(store.getDocument(), initial)
  store.redo()
  assert.deepEqual(store.getDocument(), document)
})
