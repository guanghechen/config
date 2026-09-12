import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import {
  framePoint,
  nodeBounds,
  nodeLocalPoint,
  nodePoint,
  normalizeAngle,
  resizeNodeBox,
  rotatePoint,
  rotationHandle,
} from '../shared/whiteboard/pose.ts'
import { attachEndpoint, hitTest, resolveEndpoint } from '../shared/whiteboard/geometry.ts'
import { connectorPath } from '../shared/whiteboard/edges.ts'
import {
  flipElements,
  resizeBounds,
  resizeCornerAt,
  resizeElements,
  rotateElements,
  transformBounds,
  transformPivot,
} from '../shared/whiteboard/transforms.ts'
import { arrangeElements } from '../shared/whiteboard/organization.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'

const node = (id = 'node', patch = {}) => ({
  id,
  type: 'shape',
  shape: 'rectangle',
  x: 100,
  y: 100,
  width: 160,
  height: 80,
  style: DEFAULT_STYLE,
  ...patch,
})
const edge = (patch = {}) => ({
  id: 'edge',
  type: 'edge',
  from: { x: 0, y: 0 },
  to: { x: 200, y: 100 },
  style: DEFAULT_STYLE,
  ...patch,
})
const document = elements => ({ ...createDocument(), elements })
const near = (a, b) => {
  assert.ok(Math.abs(a.x - b.x) < 1e-7, `${a.x} != ${b.x}`)
  assert.ok(Math.abs(a.y - b.y) < 1e-7, `${a.y} != ${b.y}`)
}

test('pose metadata is optional, round trips for every node kind and rejects invalid values', () => {
  for (const item of [
    node(),
    { ...node(), type: 'text', text: 'Caption' },
    { ...node(), type: 'markdown', source: { kind: 'inline', content: '# Notes' } },
    { ...node(), type: 'image', url: '/image.png' },
    {
      ...node(),
      type: 'stroke',
      points: [
        { x: 0, y: 0 },
        { x: 1, y: 1 },
      ],
    },
  ]) {
    const doc = document([{ ...item, rotation: 270, flipX: true, flipY: false }])
    assert.deepEqual(parseDocument(JSON.stringify(doc)), doc)
  }
  for (const patch of [{ rotation: '90' }, { rotation: Infinity }, { flipX: 1 }, { flipY: null }])
    assert.throws(() => parseDocument(JSON.stringify(document([node('node', patch)]))))
  assert.throws(() => parseDocument(JSON.stringify(document([edge({ rotation: 90 })]))))
  assert.equal(normalizeAngle(720), 0)
  assert.equal(normalizeAngle(270), -90)
})

test('local/world transforms invert across rotations and reflections; bounds cover every transformed corner', () => {
  for (const rotation of [-179, -90, -33, 0, 45, 90, 180, 270])
    for (const flipX of [false, true])
      for (const flipY of [false, true]) {
        const item = node('node', { rotation, flipX, flipY }),
          bounds = nodeBounds(item)
        for (const point of [
          { x: 0, y: 0 },
          { x: 160, y: 0 },
          { x: 0, y: 80 },
          { x: 160, y: 80 },
          { x: 37, y: 29 },
        ]) {
          const world = nodePoint(item, point)
          near(nodeLocalPoint(item, world), point)
          assert.ok(
            world.x >= bounds.x - 1e-8 &&
              world.x <= bounds.x + bounds.width + 1e-8 &&
              world.y >= bounds.y - 1e-8 &&
              world.y <= bounds.y + bounds.height + 1e-8,
          )
        }
      }
})

test('rotated shape and stroke hit testing uses local geometry; attachments remain local boundary anchors', () => {
  const item = node('node', { rotation: 45 })
  assert.equal(hitTest([item], nodePoint(item, { x: 80, y: 40 }), 1)?.id, 'node')
  const bounds = nodeBounds(item)
  assert.equal(hitTest([item], { x: bounds.x, y: bounds.y }, 1), undefined)
  for (const shape of ['rectangle', 'ellipse', 'diamond']) {
    const target = node('node', { shape, rotation: 65, flipX: true })
    const world = nodePoint(target, { x: 160, y: 40 })
    const attached = attachEndpoint(target, world)
    near(attached, { x: 1, y: 0.5 })
    near(resolveEndpoint(attached, new Map([['node', target]])), world)
  }
  const stroke = {
    ...node('stroke', { rotation: 90, flipY: true }),
    type: 'stroke',
    points: [
      { x: 0, y: 0 },
      { x: 1, y: 0 },
    ],
  }
  assert.equal(hitTest([stroke], nodePoint(stroke, { x: 80, y: 0 }), 1)?.id, 'stroke')
  assert.equal(hitTest([stroke], nodePoint(stroke, { x: 80, y: 70 }), 1), undefined)
})

test('group rotation transforms geometry and default curve controls once while outside nodes remain fixed', () => {
  const a = node('a', { rotation: 25, flipX: true }),
    b = node('b', { x: 500, y: 300, rotation: -40 })
  const connection = edge({
    routing: 'curve',
    from: { nodeId: 'a', x: 1, y: 0.5 },
    to: { nodeId: 'b', x: 0, y: 0.5 },
  })
  const outside = node('outside', { x: 900 })
  const external = edge({
    id: 'external',
    from: { nodeId: 'a', x: 0, y: 0.5 },
    to: { nodeId: 'outside', x: 0, y: 0.5 },
  })
  const elements = [a, b, connection, outside, external],
    selected = new Set(['a', 'b', 'edge'])
  const frame = transformBounds(elements, selected),
    pivot = transformPivot(elements, selected, frame)
  const before = new Map(elements.map(item => [item.id, item]))
  const path = connectorPath(
    connection,
    resolveEndpoint(connection.from, before),
    resolveEndpoint(connection.to, before),
  )
  const result = rotateElements(elements, selected, 67),
    after = new Map(result.map(item => [item.id, item]))
  for (const original of [a, b])
    for (const point of [
      { x: 0, y: 0 },
      { x: 80, y: 40 },
      { x: 160, y: 80 },
    ])
      near(
        nodePoint(after.get(original.id), point),
        rotatePoint(nodePoint(original, point), pivot, 67),
      )
  const routed = connectorPath(
    after.get('edge'),
    resolveEndpoint(connection.from, after),
    resolveEndpoint(connection.to, after),
  )
  routed.points.forEach((point, index) => near(point, rotatePoint(path.points[index], pivot, 67)))
  assert.equal(after.get('outside'), outside)
  assert.equal(after.get('external'), external)
  near(resolveEndpoint(external.to, after), resolveEndpoint(external.to, before))
})

test('world-axis flips compose with rotated and previously mirrored nodes and remain reversible', () => {
  const a = node('a', { rotation: 35, flipY: true }),
    b = node('b', { x: 400, y: 300, rotation: -80, flipX: true })
  const connector = edge({
    routing: 'polyline',
    controls: [
      { x: 260, y: 20 },
      { x: 330, y: 350 },
    ],
  })
  const elements = [a, b, connector],
    selected = new Set(['a', 'b', 'edge'])
  for (const axis of ['x', 'y']) {
    const pivot = transformPivot(elements, selected, transformBounds(elements, selected))
    const result = flipElements(elements, selected, axis)
    const reflected = point => ({ ...point, [axis]: 2 * pivot[axis] - point[axis] })
    for (let index = 0; index < 2; index++)
      for (const point of [
        { x: 0, y: 0 },
        { x: 160, y: 80 },
      ])
        near(nodePoint(result[index], point), reflected(nodePoint(elements[index], point)))
    near(result[2].controls[0], reflected(connector.controls[0]))
    const twice = flipElements(result, selected, axis)
    for (let index = 0; index < 2; index++)
      near(nodePoint(twice[index], { x: 37, y: 29 }), nodePoint(elements[index], { x: 37, y: 29 }))
  }
})

test('single rotated resizing fixes the opposite geometric corner and supports independent dimensions', () => {
  for (const rotation of [35, 90, -120])
    for (const flipX of [false, true]) {
      const item = node('node', { rotation, flipX, autoSize: true }),
        elements = [item],
        selected = new Set(['node'])
      const bounds = resizeBounds(elements, selected),
        corner = { x: 1, y: 1 },
        anchor = framePoint(bounds, { x: 0, y: 0 })
      const target = rotatePoint({ x: anchor.x + 240, y: anchor.y + 120 }, anchor, rotation)
      const result = resizeElements(elements, selected, bounds, corner, target, false)[0]
      assert.ok(Math.abs(result.width - 240) < 1e-8 && Math.abs(result.height - 120) < 1e-8)
      near(framePoint(result, { x: 0, y: 0 }), anchor)
      assert.equal(result.autoSize, false)
      assert.deepEqual(resizeCornerAt(bounds, framePoint(bounds, corner), 1), corner)
      assert.equal(
        resizeElements(elements, selected, bounds, corner, framePoint(bounds, corner), false),
        elements,
      )
    }
})

test('quarter-turn groups support exact nonuniform scaling; angled groups preserve proportions', () => {
  const elements = [node('a', { rotation: 90 }), node('b', { x: 500, rotation: 0 })],
    selected = new Set(['a', 'b'])
  const bounds = resizeBounds(elements, selected),
    result = resizeElements(
      elements,
      selected,
      bounds,
      { x: 1, y: 1 },
      { x: bounds.x + bounds.width * 2, y: bounds.y + bounds.height * 3 },
      false,
    )
  for (let index = 0; index < 2; index++)
    for (const point of [
      { x: 0, y: 0 },
      { x: 1, y: 1 },
    ]) {
      const old = nodePoint(elements[index], {
        x: point.x * elements[index].width,
        y: point.y * elements[index].height,
      })
      const actual = nodePoint(result[index], {
        x: point.x * result[index].width,
        y: point.y * result[index].height,
      })
      near(actual, { x: bounds.x + (old.x - bounds.x) * 2, y: bounds.y + (old.y - bounds.y) * 3 })
    }
  const angled = [node('a', { rotation: 35 }), node('b', { x: 500 })]
  const frame = resizeBounds(angled, selected),
    scaled = resizeElements(
      angled,
      selected,
      frame,
      { x: 1, y: 1 },
      { x: frame.x + frame.width * 2, y: frame.y + frame.height * 3 },
      false,
    )
  assert.equal(scaled[0].width / angled[0].width, scaled[0].height / angled[0].height)
  const aligned = arrangeElements(angled, selected, 'x', 'end')
  const boxes = aligned.map(nodeBounds)
  assert.ok(Math.abs(boxes[0].x + boxes[0].width - boxes[1].x - boxes[1].width) < 1e-8)
})

test('auto-size preserves transformed local origin and partially bound lines pivot around their fixed anchor', () => {
  const item = node('node', { rotation: 37, flipX: true, flipY: true })
  near(nodePoint(resizeNodeBox(item, 280, 140), { x: 0, y: 0 }), nodePoint(item, { x: 0, y: 0 }))
  const source = node('source', { x: 0, y: 0, width: 100, height: 100 })
  const bound = edge({ from: { nodeId: 'source', x: 1, y: 0.5 }, to: { x: 200, y: 50 } }),
    selected = new Set(['edge'])
  const result = rotateElements([source, bound], selected, 90)[1]
  near(result.to, { x: 100, y: 150 })
  assert.deepEqual(result.from, bound.from)
  assert.equal(
    transformBounds([source, edge({ from: bound.from, to: bound.from })], selected),
    null,
  )
  assert.ok(rotationHandle(resizeBounds([item], new Set(['node'])), 0.5))
})

test('store and agent transforms are atomic and preserve IDs, groups, contents and undo/redo', () => {
  const initial = document([
      { ...node('a'), groupId: 'g' },
      { ...node('b', { x: 400 }), groupId: 'g' },
    ]),
    store = new BoardStore(initial)
  store.select(new Set(['a']))
  store.rotateSelected(45)
  const rotated = store.getDocument()
  assert.ok(rotated.elements.every(item => item.rotation === 45 && item.groupId === 'g'))
  store.undo()
  assert.equal(store.getDocument(), initial)
  store.redo()
  assert.equal(store.getDocument(), rotated)
  store.applyCommands({
    kind: 'yoz.whiteboard.commands',
    schemaVersion: 1,
    documentId: initial.id,
    commands: [
      { op: 'flip', ids: ['a'], axis: 'x' },
      { op: 'rotate', ids: ['a'], degrees: 15 },
    ],
  })
  assert.ok(
    store.getDocument().elements.every(item => item.flipX === true && item.rotation === -30),
  )
  store.undo()
  assert.equal(store.getDocument(), rotated)
  assert.deepEqual(parseDocument(JSON.stringify(rotated)), rotated)
})
