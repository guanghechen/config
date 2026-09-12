import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { exportBounds, exportSelection, rasterSize } from '../shared/whiteboard/export.ts'

const node = (id, x, patch = {}) => ({
  id,
  type: 'shape',
  shape: 'rectangle',
  x,
  y: 0,
  width: 100,
  height: 80,
  style: DEFAULT_STYLE,
  ...patch,
})

test('export excludes hidden nodes and dependent edges but keeps locked content and precise selections', () => {
  const elements = [
    node('a', 0, { hidden: true }),
    node('b', 300, { locked: true }),
    {
      id: 'e',
      type: 'edge',
      from: { nodeId: 'a', x: 1, y: 0.5 },
      to: { nodeId: 'b', x: 0, y: 0.5 },
      style: DEFAULT_STYLE,
    },
  ]
  const document = { ...createDocument(), elements }
  assert.deepEqual(exportSelection(document), [elements[1]])
  assert.throws(() => exportSelection(document, new Set(['a', 'e'])), /no visible elements/)
  assert.deepEqual(exportSelection(document, new Set(['b'])), [elements[1]])
  assert.throws(() => exportSelection(createDocument()), /no visible elements/)
})

test('selected edge export resolves endpoints against the entire document and includes rotated bounds', () => {
  const a = node('a', 0),
    b = node('b', 300),
    edge = {
      id: 'e',
      type: 'edge',
      from: { nodeId: 'a', x: 1, y: 0.5 },
      to: { nodeId: 'b', x: 0, y: 0.5 },
      arrowEnd: 'none',
      style: DEFAULT_STYLE,
    }
  const area = exportBounds([edge], [a, b, edge])
  assert.ok(area.x <= 76 && area.x + area.width >= 324)
  assert.ok(area.width < 300, 'bound endpoints became fallback coordinates')
  const rotated = exportBounds([node('rotated', 0, { rotation: 90 })], [])
  assert.ok(rotated.y <= -34 && rotated.height >= 148)
})

test('PNG limits are checked before rendering, with explicit smaller-scale and SVG alternatives', () => {
  assert.deepEqual(rasterSize({ x: 0, y: 0, width: 120.5, height: 80 }, 2), {
    width: 241,
    height: 160,
  })
  for (const [width, height, scale] of [
    [20000, 10, 1],
    [8000, 5000, 1],
    [100, 100, 0],
    [100, 100, NaN],
  ])
    assert.throws(() => rasterSize({ x: 0, y: 0, width, height }, scale), /PNG exceeds/)
  assert.deepEqual(rasterSize({ x: 0, y: 0, width: 16000, height: 1000 }, 1), {
    width: 16000,
    height: 1000,
  })
})
