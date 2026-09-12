import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import { hiddenElements, lockedElements } from '../shared/whiteboard/visibility.ts'
import {
  duplicateElements,
  hitElements,
  hitTest,
  moveElements,
  resolveEndpoint,
} from '../shared/whiteboard/geometry.ts'
import { eraseAlong } from '../shared/whiteboard/erasing.ts'
import { prepareMoveSnap } from '../shared/whiteboard/drawing.ts'
import { applyCommands } from '../shared/whiteboard/commands.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'

const node = (id, x = 0, patch = {}) => ({
  id,
  type: 'shape',
  shape: 'rectangle',
  x,
  y: 0,
  width: 80,
  height: 80,
  style: DEFAULT_STYLE,
  ...patch,
})
const edge = (id, from, to, patch = {}) => ({
  id,
  type: 'edge',
  from,
  to,
  style: DEFAULT_STYLE,
  ...patch,
})
const document = elements => ({ ...createDocument(), elements })
const batch = (doc, commands) => ({
  kind: 'yoz.whiteboard.commands',
  schemaVersion: 1,
  documentId: doc.id,
  commands,
})

test('visibility and lock flags round trip, derive group protection and hide incident connections', () => {
  const elements = [
    node('a', 0, { locked: true, groupId: 'g', hidden: true }),
    node('b', 120, { groupId: 'g' }),
    edge('e', { nodeId: 'a', x: 1, y: 0.5 }, { nodeId: 'b', x: 0, y: 0.5 }),
  ]
  assert.deepEqual(lockedElements(elements), new Set(['a', 'b']))
  assert.deepEqual(hiddenElements(elements), new Set(['a', 'e']))
  const doc = document(elements)
  assert.deepEqual(parseDocument(JSON.stringify(doc)), doc)
  for (const flag of ['locked', 'hidden'])
    for (const value of [null, 1, 'true', []])
      assert.throws(() =>
        parseDocument(JSON.stringify(document([node('a', 0, { [flag]: value })]))),
      )
})

test('locked groups reject direct edits, previews, transforms, layouts and deletions; explicit flags and undo remain available', () => {
  const initial = document([
      node('a', 0, { locked: true, groupId: 'g' }),
      node('b', 120, { groupId: 'g' }),
    ]),
    store = new BoardStore(initial)
  store.select(new Set(['b']))
  assert.equal(store.canEditSelection(), false)
  store.preview(moveElements(initial.elements, store.getSnapshot().selected, { x: 30, y: 40 }))
  assert.equal(store.getSnapshot().document, initial)
  store.commit({
    ...initial,
    elements: initial.elements.map(item => ({
      ...item,
      style: { ...item.style, stroke: 'theme:red' },
    })),
  })
  for (const action of [
    () => store.rotateSelected(90),
    () => store.flipSelected('x'),
    store.removeSelected,
    store.ungroupSelected,
    () => store.arrangeSelected('x', 'end'),
    () => store.reorderSelected('front'),
  ])
    action()
  assert.equal(store.getDocument(), initial)
  store.setSelectedFlags({ hidden: true })
  assert.ok(store.getDocument().elements.every(item => item.hidden))
  store.undo()
  assert.equal(store.getDocument(), initial)
  store.select(new Set(['a']))
  store.setSelectedFlags({ locked: false })
  assert.equal(store.canEditSelection(), true)
  assert.ok(store.getDocument().elements.every(item => item.locked === false))
  store.rotateSelected(90)
  assert.ok(store.getDocument().elements.every(item => item.rotation === 90))
})

test('locked connections prevent cascading deletion while their bindings still follow editable nodes', () => {
  const a = node('a'),
    b = node('b', 200),
    connection = edge(
      'edge',
      { nodeId: 'a', x: 1, y: 0.5 },
      { nodeId: 'b', x: 0, y: 0.5 },
      { locked: true },
    )
  const initial = document([a, b, connection]),
    store = new BoardStore(initial)
  store.select(new Set(['a']))
  assert.equal(store.canEditSelection(), true)
  assert.equal(store.canRemoveSelection(), false)
  store.removeSelected()
  assert.equal(store.getDocument(), initial)
  store.commit({
    ...initial,
    elements: moveElements(initial.elements, new Set(['a']), { x: 20, y: 30 }),
  })
  const moved = store.getDocument().elements
  assert.equal(moved[2], connection)
  assert.deepEqual(resolveEndpoint(connection.from, new Map(moved.map(item => [item.id, item]))), {
    x: 100,
    y: 70,
  })
})

test('hit enumeration respects layer/order and visibility while supporting explicit locked selection and binding', () => {
  const back = node('back'),
    top = node('top', 0, { locked: true }),
    hidden = node('hidden', 0, { hidden: true })
  const elements = [back, top, hidden],
    point = { x: 40, y: 40 }
  assert.deepEqual(
    hitElements(elements, point, 1).map(item => item.id),
    ['back'],
  )
  assert.deepEqual(
    hitElements(elements, point, 1, false, undefined, { includeLocked: true }).map(item => item.id),
    ['top', 'back'],
  )
  assert.equal(hitTest(elements, point, 1, true)?.id, 'top')
  assert.equal(
    hitTest(elements, point, 1, false, undefined, { includeLocked: true, includeHidden: true })?.id,
    'hidden',
  )
  const copies = duplicateElements(elements, new Set(['top', 'hidden']))
  assert.equal(copies[0].locked, true)
  assert.equal(copies[1].hidden, true)
})

test('agent commands require explicit unlocking and forbid editing or joining protected groups', () => {
  const original = document([
    node('a', 0, { locked: true, groupId: 'g' }),
    node('b', 120, { groupId: 'g' }),
    node('c', 240),
  ])
  for (const command of [
    { op: 'update', id: 'b', patch: { x: 50 } },
    { op: 'move', ids: ['a'], delta: { x: 1, y: 0 } },
    { op: 'remove', ids: ['a'] },
    { op: 'group', ids: ['a', 'c'], groupId: 'new' },
    { op: 'add', elements: [node('new', 400, { groupId: 'g' })] },
    { op: 'update', id: 'c', patch: { groupId: 'g' } },
  ])
    assert.throws(() => applyCommands(original, batch(original, [command])), /Unlock/)
  const hidden = applyCommands(
    original,
    batch(original, [{ op: 'set-flags', ids: ['b'], hidden: true }]),
  )
  assert.ok(hidden.elements.slice(0, 2).every(item => item.hidden))
  const result = applyCommands(
    original,
    batch(original, [
      { op: 'set-flags', ids: ['a'], locked: false },
      { op: 'move', ids: ['a'], delta: { x: 20, y: 10 } },
    ]),
  )
  assert.equal(result.elements[0].x, 20)
  assert.equal(result.elements[1].x, 140)
  const store = new BoardStore(original)
  store.applyCommands(
    batch(original, [
      { op: 'set-flags', ids: ['a'], locked: false },
      { op: 'remove', ids: ['a', 'b'] },
    ]),
  )
  assert.deepEqual(store.getDocument().elements, [original.elements[2]])
  store.undo()
  assert.equal(store.getDocument(), original)
})

test('eraser sweeps delete whole groups, preserve hidden/locked objects and cannot erase through a locked foreground', () => {
  const elements = [
    node('a', 20, { groupId: 'g' }),
    node('b', 200, { groupId: 'g' }),
    node('hidden', 400, { hidden: true }),
    node('locked', 600, { locked: true }),
  ]
  const removed = eraseAlong(elements, { x: 0, y: 40 }, { x: 700, y: 40 }, 1, new Set())
  assert.deepEqual(removed, new Set(['a', 'b']))
  const overlap = [node('back'), node('locked', 0, { locked: true })]
  assert.equal(eraseAlong(overlap, { x: 40, y: 40 }, { x: 40, y: 40 }, 1, new Set()).size, 0)
  const protectedEdge = [
    node('a'),
    node('b', 200),
    edge('edge', { nodeId: 'a', x: 1, y: 0.5 }, { nodeId: 'b', x: 0, y: 0.5 }, { locked: true }),
  ]
  assert.equal(eraseAlong(protectedEdge, { x: 0, y: 40 }, { x: 80, y: 40 }, 1, new Set()).size, 0)
  const original = new Set(['earlier'])
  eraseAlong(elements, { x: 0, y: 40 }, { x: 100, y: 40 }, 0.5, original)
  assert.deepEqual(original, new Set(['earlier']))
})

test('hidden nodes do not attract snapping; selected hidden group members keep the group bounds', () => {
  const elements = [node('a'), node('hidden', 200, { hidden: true }), node('visible', 400)]
  assert.deepEqual(prepareMoveSnap(elements, new Set(['a'])).targets, [elements[2]])
  assert.deepEqual(prepareMoveSnap(elements, new Set(['a', 'hidden'])).bounds, {
    x: 0,
    y: 0,
    width: 280,
    height: 80,
  })
})
