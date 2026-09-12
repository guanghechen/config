import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import {
  addConnectorBend,
  connectorArrowheads,
  connectorBounds,
  connectorControls,
  connectorHit,
  connectorMidpoint,
  connectorPath,
} from '../shared/whiteboard/edges.ts'
import { cubicPoint } from '../shared/whiteboard/curves.ts'
import {
  duplicateElements,
  hitTest,
  labelArea,
  moveElements,
  resolveEndpoint,
} from '../shared/whiteboard/geometry.ts'
import { arrangeElements } from '../shared/whiteboard/organization.ts'
import { resizeBounds, resizeElements } from '../shared/whiteboard/transforms.ts'
import { sketchArrow, sketchConnector } from '../shared/whiteboard/sketch.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'
import { applyCommands } from '../shared/whiteboard/commands.ts'

const edge = (patch = {}) => ({
  id: 'edge',
  type: 'edge',
  from: { x: 0, y: 0 },
  to: { x: 300, y: 120 },
  style: DEFAULT_STYLE,
  ...patch,
})
const node = (id, x, y) => ({
  id,
  type: 'shape',
  shape: 'rectangle',
  x,
  y,
  width: 100,
  height: 80,
  style: DEFAULT_STYLE,
})
const document = elements => ({ ...createDocument(), elements })

test('connector options round trip; malformed enums, counts and coordinates leave imports unchanged', () => {
  const original = document([edge()]),
    store = new BoardStore(original)
  assert.deepEqual(parseDocument(JSON.stringify(original)), original)
  for (const routing of ['straight', 'polyline', 'curve']) {
    const item = edge({ routing, arrowStart: 'arrow', arrowEnd: 'none', lineStyle: 'dotted' })
    const controls = connectorControls(item, item.from, item.to)
    const doc = document([{ ...item, controls }])
    assert.deepEqual(parseDocument(JSON.stringify(doc)), doc)
  }
  for (const patch of [
    { routing: 'unknown' },
    { routing: ['curve'] },
    { arrowStart: ['none'] },
    { arrowEnd: null },
    { lineStyle: ['solid'] },
    { controls: [{ x: 1, y: 2 }] },
    { routing: 'curve', controls: [] },
    { routing: 'curve', controls: [{ x: 0, y: 0 }] },
    { routing: 'polyline', controls: [{ x: Infinity, y: 0 }] },
    { routing: 'polyline', controls: Array(65).fill({ x: 0, y: 0 }) },
  ]) {
    assert.throws(() => store.replace(parseDocument(JSON.stringify(document([edge(patch)])))))
    assert.equal(store.getDocument(), original)
  }
})

test('agent route changes reset old controls unless the patch explicitly supplies replacements', () => {
  const original = document([
    edge({
      routing: 'polyline',
      controls: [
        { x: 10, y: 20 },
        { x: 20, y: 30 },
        { x: 30, y: 40 },
      ],
    }),
  ])
  const batch = patch => ({
    kind: 'yoz.whiteboard.commands',
    schemaVersion: 1,
    documentId: original.id,
    commands: [{ op: 'update', id: 'edge', patch }],
  })
  const changed = applyCommands(original, batch({ routing: 'curve' })).elements[0]
  assert.equal(changed.routing, 'curve')
  assert.equal(changed.controls, undefined)
  assert.deepEqual(
    applyCommands(original, batch({ routing: 'polyline', lineStyle: 'dotted' })).elements[0]
      .controls,
    original.elements[0].controls,
  )
  const controls = [
    { x: 80, y: 60 },
    { x: 120, y: 90 },
  ]
  assert.deepEqual(
    applyCommands(original, batch({ routing: 'curve', controls })).elements[0].controls,
    controls,
  )
})

test('polyline hit testing and labels follow the routed path instead of the endpoint chord', () => {
  const item = edge({
    routing: 'polyline',
    controls: [
      { x: 0, y: 200 },
      { x: 300, y: 200 },
    ],
    label: 'Routed label',
  })
  const route = connectorPath(item, item.from, item.to)
  assert.equal(connectorHit(item, route, { x: 150, y: 200 }, 2), true)
  assert.equal(connectorHit(item, route, { x: 150, y: 60 }, 2), false)
  assert.deepEqual(connectorMidpoint(route), { x: 90, y: 200 })
  assert.equal(hitTest([item], { x: 150, y: 200 }, 2)?.id, 'edge')
  const area = labelArea(item, new Map())
  assert.equal(area.x + area.width / 2, 90)
  assert.equal(area.y + area.height / 2, 200)
  const expanded = addConnectorBend(item, item.from, item.to)
  assert.deepEqual(expanded.controls, [
    { x: 0, y: 200 },
    { x: 150, y: 200 },
    { x: 300, y: 200 },
  ])
})

test('cubic curves remain hittable at every scale, cover their control hull and handle coincident endpoints', () => {
  const item = edge({
    routing: 'curve',
    controls: [
      { x: -100, y: 400 },
      { x: 500, y: -100 },
    ],
  })
  const route = connectorPath(item, item.from, item.to),
    bounds = connectorBounds(route)
  for (let i = 0; i <= 100; i++) {
    const point = cubicPoint(...route.points, i / 100)
    assert.equal(connectorHit(item, route, point, 0.75), true)
    assert.ok(
      point.x >= bounds.x &&
        point.x <= bounds.x + bounds.width &&
        point.y >= bounds.y &&
        point.y <= bounds.y + bounds.height,
    )
  }
  assert.equal(connectorHit(item, route, { x: 900, y: 900 }, 4), false)
  const loop = edge({ routing: 'curve', to: { x: 0, y: 0 } }),
    path = connectorPath(loop, loop.from, loop.to)
  assert.deepEqual(connectorMidpoint(path), { x: 0, y: -60 })
  assert.equal(connectorHit(loop, path, { x: 0, y: -60 }, 1), true)
})

test('arrowheads follow route tangents and remain solid, independently configurable and hittable', () => {
  const item = edge({
    routing: 'curve',
    controls: [
      { x: 0, y: 120 },
      { x: 300, y: 0 },
    ],
    arrowStart: 'arrow',
    arrowEnd: 'arrow',
    lineStyle: 'dashed',
  })
  const route = connectorPath(item, item.from, item.to)
  const heads = connectorArrowheads(route, 2, 'arrow', 'arrow')
  assert.equal(heads.length, 2)
  assert.deepEqual(heads[0][1], item.from)
  assert.deepEqual(heads[1][1], item.to)
  assert.ok(heads[0][0].y > 0 && heads[1][0].y < item.to.y)
  assert.equal(connectorArrowheads(route, 2, 'none', 'none').length, 0)
  assert.equal(connectorHit(item, route, heads[0][0], 0.1), true)
  const drawing = sketchConnector({ ...item, style: { ...DEFAULT_STYLE, roughness: 0 } }, route)
  assert.match(drawing.body, /C/)
  assert.ok(drawing.heads.length > 0)
})

test('manual controls translate, duplicate, align and resize with explicitly selected connectors once', () => {
  const a = { ...node('a', 0, 0), groupId: 'g' },
    b = { ...node('b', 200, 100), groupId: 'g' }
  const item = edge({
    groupId: 'g',
    routing: 'curve',
    from: { nodeId: 'a', x: 1, y: 0.5 },
    to: { nodeId: 'b', x: 0, y: 0.5 },
    controls: [
      { x: 150, y: -100 },
      { x: 180, y: 300 },
    ],
  })
  const elements = [a, b, item],
    selected = new Set(['a', 'b', 'edge'])
  const moved = moveElements(elements, selected, { x: 20, y: 30 })
  assert.deepEqual(moved[2].controls, [
    { x: 170, y: -70 },
    { x: 200, y: 330 },
  ])
  const map = new Map(moved.map(element => [element.id, element]))
  assert.deepEqual(resolveEndpoint(moved[2].from, map), { x: 120, y: 70 })
  assert.deepEqual(duplicateElements(elements, selected)[2].controls, [
    { x: 174, y: -76 },
    { x: 204, y: 324 },
  ])
  const bounds = resizeBounds(elements, selected)
  assert.deepEqual(bounds, { x: 0, y: -100, width: 300, height: 400 })
  const resized = resizeElements(
    elements,
    selected,
    bounds,
    { x: 1, y: 1 },
    { x: 600, y: 700 },
    false,
  )
  assert.deepEqual(resized[2].controls, [
    { x: 300, y: -100 },
    { x: 360, y: 700 },
  ])
  const outside = node('outside', 600, 700)
  const aligned = arrangeElements(
    [...elements, outside],
    new Set([...selected, 'outside']),
    'y',
    'start',
  )
  assert.equal(aligned[3].y, 0)
  assert.deepEqual(aligned[2].controls, item.controls)
  const movedGroup = arrangeElements(
    [...elements, outside],
    new Set([...selected, 'outside']),
    'y',
    'end',
  )
  assert.deepEqual(movedGroup[2].controls, [
    { x: 150, y: 500 },
    { x: 180, y: 900 },
  ])
})

test('legacy arrow paths are unchanged; custom routes are reproducible and editing is one history entry', () => {
  const legacy = edge({ to: { x: 300, y: 120 } })
  assert.equal(
    sketchConnector(legacy, connectorPath(legacy, legacy.from, legacy.to)).body,
    sketchArrow(legacy.id, legacy.to, DEFAULT_STYLE.roughness, DEFAULT_STYLE.strokeWidth),
  )
  const curved = edge({ routing: 'curve' })
  const path = connectorPath(curved, curved.from, curved.to)
  assert.deepEqual(sketchConnector(curved, path), sketchConnector(curved, path))
  const original = document([curved]),
    store = new BoardStore(original)
  store.preview([
    {
      ...curved,
      controls: [
        { x: 100, y: 200 },
        { x: 200, y: 200 },
      ],
    },
  ])
  store.cancel()
  assert.equal(store.getDocument(), original)
  store.preview([
    {
      ...curved,
      controls: [
        { x: 100, y: 200 },
        { x: 200, y: 200 },
      ],
    },
  ])
  store.commit()
  const committed = store.getDocument()
  store.undo()
  assert.equal(store.getDocument(), original)
  store.redo()
  assert.equal(store.getDocument(), committed)
})
