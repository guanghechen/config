import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import { hitTest, moveElements } from '../shared/whiteboard/geometry.ts'
import { sketchArrow, sketchShape, smoothStroke } from '../shared/whiteboard/sketch.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'

const node = {
  id: 'block',
  type: 'shape',
  shape: 'rectangle',
  x: 100,
  y: 100,
  width: 200,
  height: 120,
  style: DEFAULT_STYLE,
}
const document = elements => ({ ...createDocument(), elements })

test('fill patterns round trip without changing old solid-fill documents or roughness values', () => {
  const legacy = document([
    { ...node, style: { stroke: '#293241', fill: '#ffffff', strokeWidth: 2, roughness: 1 } },
  ])
  assert.deepEqual(parseDocument(JSON.stringify(legacy)), legacy)
  for (const fillPattern of ['solid', 'hachure', 'cross-hatch']) {
    const current = document([{ ...node, style: { ...DEFAULT_STYLE, fillPattern } }])
    assert.deepEqual(parseDocument(JSON.stringify(current)), current)
  }
  for (const fillPattern of [null, [], ['solid'], 1, {}, 'dots']) {
    assert.throws(
      () =>
        parseDocument(
          JSON.stringify(document([{ ...node, style: { ...DEFAULT_STYLE, fillPattern } }])),
        ),
      /Invalid style/,
    )
  }
})

test('sketch outlines are reproducible, translation invariant and distinct across element IDs', () => {
  for (const shape of ['rectangle', 'diamond', 'ellipse']) {
    const render = node =>
      sketchShape(node.id, node.width, node.height, shape, node.style.roughness)
    const original = render(node)
    assert.deepEqual(original, render(node))
    assert.deepEqual(
      original,
      render(moveElements([node], new Set([node.id]), { x: 777, y: -999 })[0]),
    )
    assert.notEqual(original.outline, render({ ...node, id: 'another' }).outline)
    assert.notEqual(original.outline, render({ ...node, width: 400 }).outline)
    assert.equal((original.outline.match(/C/g) || []).length, shape === 'ellipse' ? 16 : 8)
    assert.notEqual(original.outline, original.fill)
    assert.ok(!/NaN|Infinity/.test(original.outline))
  }
})

test('clean shapes use exact closed geometry; roughness preserves their fill silhouette', () => {
  for (const shape of ['rectangle', 'diamond', 'ellipse']) {
    const clean = sketchShape('shape', 100, 80, shape, 0)
    assert.equal(clean.outline, clean.fill)
    assert.ok(clean.fill.endsWith('Z'))
    assert.equal(clean.hachure, '')
    for (const roughness of [0.5, 1, 2, 3]) {
      const sketch = sketchShape('shape', 100, 80, shape, roughness)
      assert.equal(sketch.fill, clean.fill)
      assert.notEqual(sketch.outline, clean.outline)
    }
  }
})

test('hachure and cross hatch generation is deterministic and bounded for very large nodes', () => {
  const hatch = sketchShape('hatch', 200, 120, 'diamond', 2, 'hachure')
  const cross = sketchShape('hatch', 200, 120, 'diamond', 2, 'cross-hatch')
  assert.equal(cross.hachure.match(/M/g).length, hatch.hachure.match(/M/g).length * 2)
  assert.equal(cross.hachure, sketchShape('hatch', 200, 120, 'diamond', 2, 'cross-hatch').hachure)
  assert.equal(hatch.fill, cross.fill)
  for (const [width, height] of [
    [1, 1],
    [1, 1e7],
    [1e7, 1],
    [1e7, 1e7],
  ]) {
    const paths = sketchShape('huge', width, height, 'ellipse', 3, 'cross-hatch')
    assert.ok((paths.hachure.match(/M/g) || []).length <= 320)
    assert.ok(paths.hachure.length < 100000)
    assert.ok(!/NaN|Infinity/.test(JSON.stringify(paths)))
  }
})

test('hand-drawn arrow strokes share an exact tip and handle reversed or collapsed endpoints', () => {
  for (const to of [
    { x: 300, y: 200 },
    { x: -200, y: 50 },
    { x: 0, y: 0 },
  ]) {
    const path = sketchArrow('arrow', to, 2, 2)
    assert.equal(path, sketchArrow('arrow', to, 2, 2))
    assert.equal((path.match(/M/g) || []).length, 6)
    for (const segment of path.split('M').filter(Boolean)) {
      const coordinates = segment.match(/-?\d+(?:\.\d+)?/g).map(Number)
      assert.deepEqual(coordinates.slice(-2), [to.x, to.y])
    }
    assert.ok(!/NaN|Infinity/.test(path))
    assert.equal((sketchArrow('arrow', to, 0, 2).match(/L/g) || []).length, 3)
  }
})

test('smoothed freehand strokes remain selectable along the curve rather than the discarded sharp corner', () => {
  const points = Object.freeze([
    Object.freeze({ x: 0, y: 0 }),
    Object.freeze({ x: 1, y: 0 }),
    Object.freeze({ x: 1, y: 1 }),
  ])
  const path = smoothStroke(points, 100, 100)
  assert.equal(path, 'M0 0Q100 0 100 50L100 100')
  const stroke = { ...node, type: 'stroke', x: 0, y: 0, width: 100, height: 100, points }
  assert.equal(hitTest([stroke], { x: 75, y: 12.5 }, 1)?.id, node.id)
  assert.equal(hitTest([stroke], { x: 100, y: 0 }, 1), undefined)
  assert.equal(hitTest([stroke], { x: 100, y: 100 }, 1)?.id, node.id)
  const large = { ...stroke, width: 1e7, height: 1e7 }
  assert.equal(hitTest([large], { x: 7.5e6, y: 1.25e6 }, 0.75)?.id, node.id)
  assert.equal(
    smoothStroke(
      [
        { x: 0, y: 0 },
        { x: 1, y: 1 },
      ],
      100,
      100,
    ),
    'M0 0L100 100',
  )
})

test('style undo restores the exact generated paths and keeps geometry and content intact', () => {
  const original = document([{ ...node, label: '服务边界', groupId: 'service' }]),
    store = new BoardStore(original)
  const before = sketchShape(node.id, node.width, node.height, node.shape, node.style.roughness)
  store.commit({
    ...original,
    elements: original.elements.map(item => ({
      ...item,
      style: { ...item.style, roughness: 3, fillPattern: 'cross-hatch' },
    })),
  })
  store.undo()
  assert.equal(store.getDocument(), original)
  const restored = store.getDocument().elements[0]
  assert.deepEqual(
    sketchShape(
      restored.id,
      restored.width,
      restored.height,
      restored.shape,
      restored.style.roughness,
    ),
    before,
  )
  store.redo()
  assert.equal(store.getDocument().elements[0].label, '服务边界')
  assert.equal(store.getDocument().elements[0].groupId, 'service')
})
