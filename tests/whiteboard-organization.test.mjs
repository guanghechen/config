import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import { duplicateElements, moveElements, resolveEndpoint } from '../shared/whiteboard/geometry.ts'
import { arrangeElements, expandSelection, layoutUnits } from '../shared/whiteboard/organization.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'

const node = (id, x = 0, y = 0, width = 100, height = 80) => ({
  id,
  type: 'shape',
  shape: 'rectangle',
  x,
  y,
  width,
  height,
  style: DEFAULT_STYLE,
})
const edge = (id, from, to) => ({ id, type: 'edge', from, to, style: DEFAULT_STYLE })
const document = elements => ({ ...createDocument(), elements })

test('group IDs round trip, legacy documents remain valid, invalid imports keep the current scene', () => {
  const original = document([node('a')]),
    store = new BoardStore(original)
  assert.deepEqual(parseDocument(JSON.stringify(original)), original)
  const grouped = document([
    { ...node('a'), groupId: 'group' },
    { ...node('b'), groupId: 'group' },
  ])
  assert.deepEqual(parseDocument(JSON.stringify(grouped)), grouped)
  for (const groupId of ['', null, 0, [], {}, 'g'.repeat(129)]) {
    assert.throws(
      () => store.replace(parseDocument(JSON.stringify(document([{ ...node('a'), groupId }])))),
      /Invalid group ID/,
    )
    assert.equal(store.getDocument(), original)
  }
})

test('selection expands whole groups, merging is flat, and group/ungroup undo atomically', () => {
  const initial = document([
    { ...node('a'), groupId: 'old' },
    { ...node('b', 200), groupId: 'old' },
    node('c', 400),
  ])
  const store = new BoardStore(initial)
  store.select(new Set(['b']))
  assert.deepEqual(store.getSnapshot().selected, new Set(['a', 'b']))
  store.groupSelected()
  store.undo()
  assert.equal(store.getDocument(), initial, 'Grouping an existing group is a no-op')
  store.select(new Set(['b', 'c']))
  store.groupSelected()
  const grouped = store.getDocument()
  assert.equal(new Set(grouped.elements.map(element => element.groupId)).size, 1)
  assert.notEqual(grouped.elements[0].groupId, 'old')
  store.undo()
  assert.equal(store.getDocument(), initial)
  store.redo()
  assert.equal(store.getDocument(), grouped)
  store.select(new Set(['c']))
  assert.equal(store.getSnapshot().selected.size, 3)
  store.ungroupSelected()
  assert.ok(store.getDocument().elements.every(element => !('groupId' in element)))
  store.undo()
  assert.equal(store.getDocument(), grouped)
})

test('group drag moves every member once, preserves external bindings and cancels without saving', () => {
  const a = { ...node('a'), groupId: 'g' },
    b = { ...node('b', 200, 20), groupId: 'g' }
  const outside = node('outside', 800)
  const internal = {
    ...edge('internal', { nodeId: 'a', x: 1, y: 0.5 }, { nodeId: 'b', x: 0, y: 0.5 }),
    groupId: 'g',
  }
  const external = edge(
    'external',
    { nodeId: 'b', x: 1, y: 0.5 },
    { nodeId: 'outside', x: 0, y: 0.5 },
  )
  const free = { ...edge('free', { nodeId: 'a', x: 0.5, y: 1 }, { x: 170, y: 240 }), groupId: 'g' }
  const initial = document([a, b, outside, internal, external, free]),
    store = new BoardStore(initial)
  store.select(new Set(['a']))
  assert.deepEqual(store.getSnapshot().selected, new Set(['a', 'b', 'internal', 'free']))
  store.preview(moveElements(initial.elements, store.getSnapshot().selected, { x: 30, y: 40 }))
  const moved = store.getSnapshot().document.elements,
    map = new Map(moved.map(element => [element.id, element]))
  assert.deepEqual(resolveEndpoint(internal.to, map), { x: 230, y: 100 })
  assert.deepEqual(resolveEndpoint(external.to, map), { x: 800, y: 40 })
  assert.deepEqual(moved.at(-1).to, { x: 200, y: 280 })
  assert.equal(store.getDocument(), initial)
  store.cancel()
  assert.equal(store.getSnapshot().document, initial)
  store.removeSelected()
  assert.deepEqual(store.getDocument().elements, [outside])
  store.undo()
  assert.equal(store.getDocument(), initial)
})

test('copies and repeated pastes remap each group independently, including internal edge targets', () => {
  const elements = [
    { ...node('a'), groupId: 'g' },
    { ...node('b', 200), groupId: 'g' },
    { ...edge('e', { nodeId: 'a', x: 1, y: 0.5 }, { nodeId: 'b', x: 0, y: 0.5 }), groupId: 'g' },
    { ...node('c', 500), groupId: 'h' },
    { ...node('d', 700), groupId: 'h' },
  ]
  const selected = expandSelection(elements, new Set(['a', 'd']))
  const copies = duplicateElements(elements, selected)
  const pasted = duplicateElements(copies, new Set(copies.map(element => element.id)))
  for (const batch of [copies, pasted]) {
    assert.equal(batch[0].groupId, batch[1].groupId)
    assert.equal(batch[1].groupId, batch[2].groupId)
    assert.equal(batch[3].groupId, batch[4].groupId)
    assert.notEqual(batch[0].groupId, batch[3].groupId)
    assert.equal(batch[2].from.nodeId, batch[0].id)
    assert.equal(batch[2].to.nodeId, batch[1].id)
    assert.equal(
      expandSelection([...elements, ...copies, ...pasted], new Set([batch[0].id])).size,
      3,
    )
  }
  assert.equal(new Set([...elements, ...copies, ...pasted].map(element => element.groupId)).size, 6)
  assert.doesNotThrow(() =>
    parseDocument(JSON.stringify(document([...elements, ...copies, ...pasted]))),
  )
})

test('six alignments preserve group geometry; unselected and standalone edges only follow bindings', () => {
  const a = { ...node('a', 10, 20, 40, 30), groupId: 'g' },
    b = { ...node('b', 70, 60, 40, 30), groupId: 'g' }
  const c = node('c', 300, 250, 200, 120),
    outside = node('outside', 2000, 1000)
  const free = { ...edge('free', { nodeId: 'a', x: 1, y: 0.5 }, { x: 900, y: 800 }), groupId: 'g' }
  const attached = edge(
    'attached',
    { nodeId: 'b', x: 1, y: 0.5 },
    { nodeId: 'outside', x: 0, y: 0.5 },
  )
  const elements = [a, b, c, outside, free, attached]
  const selected = new Set(['a', 'c', 'attached'])
  assert.deepEqual(
    layoutUnits(elements.slice(0, 3)).map(unit => unit.bounds),
    [
      { x: 10, y: 20, width: 100, height: 70 },
      { x: 300, y: 250, width: 200, height: 120 },
    ],
  )
  for (const axis of ['x', 'y']) {
    for (const [mode, fraction] of [
      ['start', 0],
      ['center', 0.5],
      ['end', 1],
    ]) {
      const result = arrangeElements(elements, selected, axis, mode)
      const size = axis === 'x' ? 'width' : 'height'
      const units = layoutUnits(
        result.filter(element => ['a', 'b', 'c', 'free'].includes(element.id)),
      )
      assert.equal(
        units[0].bounds[axis] + units[0].bounds[size] * fraction,
        units[1].bounds[axis] + units[1].bounds[size] * fraction,
      )
      assert.equal(result[1].x - result[0].x, 60)
      assert.equal(result[1].y - result[0].y, 40)
      assert.equal(result[3], outside)
      assert.equal(result[5], attached)
      assert.equal(result[4].to.x - free.to.x, result[0].x - a.x)
      assert.equal(result[4].to.y - free.to.y, result[0].y - a.y)
      assert.deepEqual(result[4].from, free.from)
    }
  }
})

test('distribution uses equal boundary gaps, keeps first and last fixed, and accepts overlaps', () => {
  for (const axis of ['x', 'y']) {
    for (const end of [60, 1000]) {
      const elements = [
        node('a', 0, 0, 100, 100),
        { ...node('b', 30, 30, 30, 30), groupId: 'g' },
        { ...node('c', 70, 70, 60, 60), groupId: 'g' },
        node('d', end, end, 200, 200),
      ]
      const store = new BoardStore(document(elements))
      store.select(new Set(['a', 'b', 'd']))
      store.arrangeSelected(axis, 'distribute')
      const result = store.getDocument().elements
      const units = layoutUnits(result),
        size = axis === 'x' ? 'width' : 'height'
      assert.equal(
        units[1].bounds[axis] - units[0].bounds[axis] - units[0].bounds[size],
        units[2].bounds[axis] - units[1].bounds[axis] - units[1].bounds[size],
      )
      assert.equal(result[0], elements[0])
      assert.equal(result[3], elements[3])
      assert.equal(result[2][axis] - result[1][axis], 40)
      store.undo()
      assert.deepEqual(store.getDocument().elements, elements)
      store.redo()
      assert.deepEqual(store.getDocument().elements, result)
    }
  }
})

test('groups count as single layout units; edge-only selections and insufficient units are no-ops', () => {
  const elements = [
    { ...node('a'), groupId: 'g' },
    { ...node('b', 200), groupId: 'g' },
    { ...edge('e', { x: 900, y: 800 }, { x: 1200, y: 900 }), groupId: 'e' },
    { ...edge('f', { x: 1000, y: 1000 }, { x: 1400, y: 1300 }), groupId: 'e' },
  ]
  const selected = new Set(elements.map(element => element.id))
  assert.equal(layoutUnits(elements).length, 1)
  for (const mode of ['start', 'center', 'end', 'distribute']) {
    assert.equal(arrangeElements(elements, selected, 'x', mode), elements)
  }
  const twoUnits = [...elements, node('c', 500)]
  assert.equal(arrangeElements(twoUnits, new Set([...selected, 'c']), 'x', 'distribute'), twoUnits)
})
