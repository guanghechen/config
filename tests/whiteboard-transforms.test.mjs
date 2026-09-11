import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import { resolveEndpoint } from '../shared/whiteboard/geometry.ts'
import {
  RESIZE_CORNERS,
  resizeBounds,
  resizeCornerAt,
  resizeElements,
} from '../shared/whiteboard/transforms.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'

const shape = (id, x, y, width = 100, height = 80) => ({
  id,
  type: 'shape',
  shape: 'rectangle',
  x,
  y,
  width,
  height,
  style: DEFAULT_STYLE,
})
const scene = () => [
  { ...shape('a', 100, 100), groupId: 'g', label: '节点 A' },
  {
    ...shape('b', 300, 200, 160, 100),
    type: 'markdown',
    groupId: 'g',
    source: { kind: 'inline', content: '# Formula\n\n$$E=mc^2$$' },
  },
  {
    id: 'free',
    type: 'edge',
    groupId: 'g',
    from: { nodeId: 'a', x: 1, y: 0.5 },
    to: { x: 600, y: 500 },
    style: DEFAULT_STYLE,
  },
  {
    id: 'internal',
    type: 'edge',
    groupId: 'g',
    from: { nodeId: 'a', x: 1, y: 0.5 },
    to: { nodeId: 'b', x: 0, y: 0.5 },
    style: DEFAULT_STYLE,
    label: 'Flow',
  },
  {
    id: 'external',
    type: 'edge',
    groupId: 'g',
    from: { nodeId: 'b', x: 1, y: 0.5 },
    to: { nodeId: 'outside', x: 0, y: 0.5 },
    style: DEFAULT_STYLE,
  },
  shape('outside', 10000, 8000),
]
const selected = new Set(['a', 'b', 'free', 'internal', 'external'])
const near = (actual, expected) =>
  assert.ok(Math.abs(actual - expected) < 1e-8, `${actual} ≠ ${expected}`)

test('resize bounds include selected free endpoints but exclude labels and external bound targets', () => {
  const elements = scene()
  assert.deepEqual(resizeBounds(elements, selected), { x: 100, y: 100, width: 500, height: 400 })
  assert.deepEqual(resizeBounds(elements, new Set(['a', 'external'])), {
    x: 100,
    y: 100,
    width: 100,
    height: 80,
  })
  assert.equal(resizeBounds(elements, new Set(['free', 'internal', 'external'])), null)
  assert.equal(resizeBounds(elements, new Set()), null)
})

test('resizing a mixed group transforms nodes and free endpoints once while bound endpoints follow their nodes', () => {
  const elements = scene(),
    bounds = resizeBounds(elements, selected)
  const resized = resizeElements(
    elements,
    selected,
    bounds,
    { x: 1, y: 1 },
    { x: 850, y: 900 },
    false,
  )
  assert.deepEqual(resizeBounds(resized, selected), { x: 100, y: 100, width: 750, height: 800 })
  assert.deepEqual(
    [resized[1].x, resized[1].y, resized[1].width, resized[1].height],
    [400, 300, 240, 200],
  )
  assert.equal(resized[1].source, elements[1].source)
  assert.equal(resized[0].label, elements[0].label)
  assert.deepEqual(resized[2].to, { x: 850, y: 900 })
  for (const index of [2, 3, 4]) assert.equal(resized[index].from, elements[index].from)
  const map = new Map(resized.map(element => [element.id, element]))
  assert.deepEqual(resolveEndpoint(resized[3].to, map), { x: 400, y: 400 })
  assert.deepEqual(resolveEndpoint(resized[4].to, map), { x: 10000, y: 8040 })
  assert.equal(resized[5], elements[5])
  assert.ok(
    resized
      .slice(0, 5)
      .every(element => element.groupId === 'g' && element.style === DEFAULT_STYLE),
  )
  assert.doesNotThrow(() =>
    parseDocument(JSON.stringify({ ...createDocument(), elements: resized })),
  )
})

test('each corner keeps its opposite fixed and scales all positions from the same origin', () => {
  const elements = scene(),
    bounds = resizeBounds(elements, selected)
  for (const corner of RESIZE_CORNERS) {
    const anchor = {
      x: bounds.x + (1 - corner.x) * bounds.width,
      y: bounds.y + (1 - corner.y) * bounds.height,
    }
    const point = {
      x: anchor.x + (corner.x ? 1 : -1) * bounds.width * 1.4,
      y: anchor.y + (corner.y ? 1 : -1) * bounds.height * 0.8,
    }
    const resized = resizeElements(elements, selected, bounds, corner, point, false)
    const result = resizeBounds(resized, selected)
    near(result.x + (1 - corner.x) * result.width, anchor.x)
    near(result.y + (1 - corner.y) * result.height, anchor.y)
    for (const index of [0, 1]) {
      near(resized[index].x, anchor.x + (elements[index].x - anchor.x) * 1.4)
      near(resized[index].y, anchor.y + (elements[index].y - anchor.y) * 0.8)
    }
  }
})

test('aspect lock uses the dominant relative change and preserves normalized strokes and content', () => {
  const node = {
    ...shape('stroke', 100, 100, 100, 200),
    type: 'stroke',
    points: [
      { x: 0, y: 0 },
      { x: 1, y: 1 },
    ],
  }
  const ids = new Set(['stroke'])
  for (const [point, scale] of [
    [{ x: 150, y: 300 }, 0.5],
    [{ x: 250, y: 320 }, 1.5],
  ]) {
    const [resized] = resizeElements([node], ids, node, { x: 1, y: 1 }, point, true)
    near(resized.width / node.width, scale)
    near(resized.height / node.height, scale)
    assert.equal(resized.points, node.points)
    assert.equal(resized.style, node.style)
  }
})

test('minimum member sizes clamp the entire group without flipping or distorting its relative layout', () => {
  const elements = [shape('small', 20, 40, 20, 40), shape('large', 300, 200, 200, 100)]
  const ids = new Set(['small', 'large']),
    bounds = resizeBounds(elements, ids)
  for (const corner of RESIZE_CORNERS) {
    const anchor = {
      x: bounds.x + (1 - corner.x) * bounds.width,
      y: bounds.y + (1 - corner.y) * bounds.height,
    }
    const beyond = { x: anchor.x + (corner.x ? -100 : 100), y: anchor.y + (corner.y ? -100 : 100) }
    const resized = resizeElements(elements, ids, bounds, corner, beyond, false)
    near(resized[0].width, 16)
    near(resized[0].height, 16)
    near(resized[1].width / elements[1].width, 0.8)
    near(resized[1].height / elements[1].height, 0.4)
    const constrained = resizeElements(elements, ids, bounds, corner, beyond, true)
    near(constrained[0].height, 32)
    near(constrained[1].width / elements[1].width, constrained[1].height / elements[1].height)
  }
})

test('small imported nodes do not jump on a stationary handle or shrink below their original size', () => {
  const tiny = shape('tiny', 10, 20, 4, 8),
    elements = [tiny],
    ids = new Set(['tiny'])
  assert.equal(
    resizeElements(elements, ids, tiny, { x: 1, y: 1 }, { x: 14, y: 28 }, false),
    elements,
  )
  assert.equal(
    resizeElements(elements, ids, tiny, { x: 1, y: 1 }, { x: 11, y: 21 }, false),
    elements,
  )
})

test('handle hit testing remains screen-sized and chooses the nearest corner when targets overlap', () => {
  const bounds = { x: 100, y: 200, width: 80, height: 60 }
  for (const zoom of [0.05, 0.5, 1, 4, 8]) {
    for (const corner of RESIZE_CORNERS) {
      assert.deepEqual(
        resizeCornerAt(
          bounds,
          { x: bounds.x + corner.x * bounds.width, y: bounds.y + corner.y * bounds.height },
          10 / zoom,
        ),
        corner,
      )
    }
    assert.equal(
      resizeCornerAt(bounds, { x: bounds.x - 11 / zoom, y: bounds.y }, 10 / zoom),
      undefined,
    )
  }
})

test('resize previews are not saved; cancellation and undo restore an entire group in one transaction', () => {
  const initial = { ...createDocument(), elements: scene() },
    store = new BoardStore(initial)
  store.select(new Set(['a']))
  assert.deepEqual(store.getSnapshot().selected, selected)
  const bounds = resizeBounds(initial.elements, selected)
  for (let i = 0; i < 30; i++)
    store.preview(
      resizeElements(
        initial.elements,
        selected,
        bounds,
        { x: 1, y: 1 },
        { x: 600 + i * 5, y: 500 + i * 3 },
        false,
      ),
    )
  assert.equal(store.getDocument(), initial)
  store.cancel()
  assert.equal(store.getSnapshot().document, initial)
  store.preview(
    resizeElements(initial.elements, selected, bounds, { x: 1, y: 1 }, { x: 850, y: 900 }, false),
  )
  store.commit()
  const changed = store.getDocument()
  store.undo()
  assert.equal(store.getDocument(), initial)
  store.redo()
  assert.equal(store.getDocument(), changed)
})
