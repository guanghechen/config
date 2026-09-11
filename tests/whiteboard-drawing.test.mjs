import assert from 'node:assert/strict'
import { test } from 'node:test'
import {
  constrainAngle,
  drawingBounds,
  prepareMoveSnap,
  snapMove,
} from '../shared/whiteboard/drawing.ts'
import { moveElements, resolveEndpoint } from '../shared/whiteboard/geometry.ts'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'

const node = (id, x, y, width = 100, height = 80) => ({
  id,
  type: 'shape',
  shape: 'rectangle',
  x,
  y,
  width,
  height,
  style: DEFAULT_STYLE,
})
const near = (a, b) => assert.ok(Math.abs(a - b) < 1e-8, `${a} differs from ${b}`)

test('constrained drawing works in every quadrant and centered drawing keeps its origin fixed', () => {
  const start = { x: 300, y: -200 }
  for (const x of [-120, 120])
    for (const y of [-40, 40]) {
      const point = { x: start.x + x, y: start.y + y }
      const bounds = drawingBounds(start, point, false, false)
      assert.equal(bounds.width, 120)
      assert.equal(bounds.height, 40)
      assert.equal(bounds.x, Math.min(start.x, point.x))
      assert.equal(bounds.y, Math.min(start.y, point.y))
      for (const square of [false, true]) {
        const centered = drawingBounds(start, point, square, true)
        near(centered.x + centered.width / 2, start.x)
        near(centered.y + centered.height / 2, start.y)
        assert.equal(centered.width, 240)
        assert.equal(centered.height, square ? 240 : 80)
      }
      const square = drawingBounds(start, point, true, false)
      assert.equal(square.width, square.height)
      assert.equal(square.width, 120)
    }
})

test('modifier recomputation uses the original pointer anchor without accumulating transformations', () => {
  const start = { x: 100, y: 100 },
    point = { x: 180, y: 140 }
  const original = drawingBounds(start, point, false, false)
  drawingBounds(start, point, true, true)
  assert.deepEqual(drawingBounds(start, point, false, false), original)
  assert.deepEqual(start, { x: 100, y: 100 })
  for (const square of [false, true])
    for (const centered of [false, true]) {
      const collapsed = drawingBounds(start, start, square, centered)
      assert.ok(collapsed.width >= 1 && collapsed.height >= 1)
    }
})

test('arrow angle constraints preserve length and the resolved source anchor in all directions', () => {
  const start = { x: 234, y: -567 }
  for (let degrees = -180; degrees <= 180; degrees += 5) {
    const angle = (degrees * Math.PI) / 180
    const result = constrainAngle(start, {
      x: start.x + Math.cos(angle) * 123,
      y: start.y + Math.sin(angle) * 123,
    })
    near(Math.hypot(result.x - start.x, result.y - start.y), 123)
    const snapped = Math.atan2(result.y - start.y, result.x - start.x) / (Math.PI / 4)
    near(snapped, Math.round(snapped))
  }
  assert.deepEqual(constrainAngle(start, start), start)
})

test('move snapping matches edges and centers at a screen-space tolerance without mutating inputs', () => {
  const elements = [node('moving', 0, 0), node('target', 300, 160)]
  const snap = prepareMoveSnap(elements, new Set(['moving']))
  const before = JSON.stringify(snap)
  for (const zoom of [0.05, 0.5, 1, 4, 8]) {
    const tolerance = 6 / zoom
    const result = snapMove(snap, { x: 300 + Math.min(5 / zoom, 10), y: 160 }, tolerance)
    near(result.delta.x, 300)
    near(result.delta.y, 160)
    assert.equal(result.guides.length, 2)
  }
  const center = snapMove(snap, { x: 253, y: 83 }, 6)
  assert.deepEqual(center.delta, { x: 250, y: 80 })
  assert.ok(center.guides.some(guide => guide.axis === 'x' && guide.position === 300))
  assert.equal(JSON.stringify(snap), before)
})

test('snapping ignores selected members, edges, strokes and unrelated distant rows', () => {
  const edge = {
    id: 'e',
    type: 'edge',
    from: { x: 0, y: 0 },
    to: { x: 300, y: 0 },
    style: DEFAULT_STYLE,
  }
  const stroke = {
    ...node('stroke', 100, 0),
    type: 'stroke',
    points: [
      { x: 0, y: 0 },
      { x: 1, y: 1 },
    ],
  }
  const a = node('a', 0, 0),
    b = node('b', 200, 0),
    distant = node('far', 3, 10000)
  const snap = prepareMoveSnap([a, b, edge, stroke, distant], new Set(['a', 'b']))
  assert.deepEqual(snap.bounds, { x: 0, y: 0, width: 300, height: 80 })
  assert.deepEqual(snap.targets, [distant])
  assert.deepEqual(snapMove(snap, { x: 1, y: 0 }, 6), { delta: { x: 1, y: 0 }, guides: [] })
  assert.equal(prepareMoveSnap([edge, stroke], new Set(['e', 'stroke'])), null)
})

test('nearest alignment wins and movements outside tolerance stay exact', () => {
  const snap = prepareMoveSnap(
    [node('a', 0, 0), node('b', 200, 200), node('c', 205, 200)],
    new Set(['a']),
  )
  const result = snapMove(snap, { x: 204, y: 199 }, 6)
  assert.deepEqual(result.delta, { x: 205, y: 200 })
  const free = { x: 221, y: 219 }
  assert.deepEqual(snapMove(snap, free, 6), { delta: free, guides: [] })
})

test('a snapped group moves once, attached edges follow, and undo or cancellation restores the scene', () => {
  const a = { ...node('a', 0, 0), groupId: 'g' },
    b = { ...node('b', 200, 0), groupId: 'g' }
  const edge = {
    id: 'edge',
    type: 'edge',
    from: { nodeId: 'a', x: 1, y: 0.5 },
    to: { nodeId: 'b', x: 0, y: 0.5 },
    style: DEFAULT_STYLE,
  }
  const document = { ...createDocument(), elements: [a, b, edge, node('target', 500, 200)] }
  const store = new BoardStore(document)
  store.select(new Set(['a']))
  const selected = store.getSnapshot().selected
  const snap = prepareMoveSnap(document.elements, selected)
  const { delta } = snapMove(snap, { x: 503, y: 198 }, 6)
  assert.deepEqual(delta, { x: 500, y: 200 })
  store.preview(moveElements(document.elements, selected, delta))
  const moved = store.getSnapshot().document.elements
  assert.equal(moved[1].x - moved[0].x, 200)
  assert.deepEqual(resolveEndpoint(edge.from, new Map(moved.map(item => [item.id, item]))), {
    x: 600,
    y: 240,
  })
  assert.equal(store.getDocument(), document)
  store.cancel()
  assert.equal(store.getSnapshot().document, document)
  store.preview(moved)
  store.commit()
  store.undo()
  assert.equal(store.getDocument(), document)
})
