import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import { hitTest, resolveEndpoint } from '../shared/whiteboard/geometry.ts'
import { expandSelection } from '../shared/whiteboard/organization.ts'
import {
  orderedDocument,
  reorderElements,
  stackingDirections,
} from '../shared/whiteboard/stacking.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'

const node = id => ({
  id,
  type: 'shape',
  shape: 'rectangle',
  x: 0,
  y: 0,
  width: 100,
  height: 100,
  style: DEFAULT_STYLE,
})
const card = id => ({ ...node(id), type: 'markdown', source: { kind: 'inline', content: id } })
const edge = id => ({
  id,
  type: 'edge',
  from: { x: 0, y: 0 },
  to: { x: 100, y: 100 },
  style: DEFAULT_STYLE,
})
const ids = elements => elements.map(element => element.id)
const orders = ['back', 'backward', 'forward', 'front']

test('front/back preserve relative order for disjoint selections and leave inputs untouched', () => {
  const elements = Object.freeze(['a', 'b', 'c', 'd', 'e'].map(id => Object.freeze(node(id))))
  const selected = new Set(['b', 'd'])
  assert.deepEqual(ids(reorderElements(elements, selected, 'front')), ['a', 'c', 'e', 'b', 'd'])
  assert.deepEqual(ids(reorderElements(elements, selected, 'back')), ['b', 'd', 'a', 'c', 'e'])
  assert.deepEqual(ids(elements), ['a', 'b', 'c', 'd', 'e'])
  assert.deepEqual(selected, new Set(['b', 'd']))
})

test('one-step commands move contiguous runs once, preserve selection order and stop at boundaries', () => {
  const elements = ['a', 'b', 'c', 'd', 'e', 'f', 'g'].map(node)
  const selected = new Set(['b', 'c', 'e', 'g'])
  assert.deepEqual(ids(reorderElements(elements, selected, 'forward')), [
    'a',
    'd',
    'b',
    'c',
    'f',
    'e',
    'g',
  ])
  assert.deepEqual(ids(reorderElements(elements, selected, 'backward')), [
    'b',
    'c',
    'a',
    'e',
    'd',
    'g',
    'f',
  ])
  assert.equal(reorderElements(elements, new Set(['f', 'g']), 'forward'), elements)
  assert.equal(reorderElements(elements, new Set(['a', 'b']), 'backward'), elements)
})

test('drawings, cards and connections reorder together without changing element objects', () => {
  const elements = [node('a'), card('m'), edge('e'), node('b'), card('n'), edge('f'), node('c')]
  const selected = new Set(['a', 'm', 'e'])
  assert.deepEqual(ids(reorderElements(elements, selected, 'front')), [
    'b',
    'n',
    'f',
    'c',
    'a',
    'm',
    'e',
  ])
  assert.deepEqual(ids(reorderElements(elements, selected, 'forward')), [
    'b',
    'a',
    'm',
    'e',
    'n',
    'f',
    'c',
  ])
  assert.deepEqual(ids(reorderElements(elements, new Set(['a']), 'front')), [
    'm',
    'e',
    'b',
    'n',
    'f',
    'c',
    'a',
  ])
  for (const order of orders)
    for (const element of reorderElements(elements, selected, order))
      assert.equal(
        element,
        elements.find(item => item.id === element.id),
      )
})

test('group expansion includes disconnected members and connections without changing any geometry or bindings', () => {
  const a = { ...node('a'), groupId: 'g' }
  const b = { ...node('b'), groupId: 'g', x: 200 }
  const connection = {
    ...edge('e'),
    groupId: 'g',
    from: { nodeId: 'a', x: 1, y: 0.5 },
    to: { nodeId: 'b', x: 0, y: 0.5 },
  }
  const elements = [a, node('outside'), b, connection, edge('other'), node('top')]
  const result = reorderElements(elements, new Set(['a']), 'front')
  assert.deepEqual(ids(result), ['outside', 'other', 'top', 'a', 'b', 'e'])
  const map = new Map(result.map(element => [element.id, element]))
  assert.deepEqual(resolveEndpoint(connection.from, map), { x: 100, y: 50 })
  assert.deepEqual(resolveEndpoint(connection.to, map), { x: 200, y: 50 })
  assert.deepEqual(expandSelection(result, new Set(['b'])), new Set(['b', 'a', 'e']))
  for (const element of elements) assert.equal(map.get(element.id), element)
})

test('availability matches actual movement for every subset of an mixed scene', () => {
  const elements = [edge('e'), node('a'), card('m'), node('b'), edge('f'), card('n'), node('c')]
  for (let mask = 0; mask < 2 ** elements.length; mask++) {
    const selected = new Set(
      elements.filter((_, index) => mask & (1 << index)).map(element => element.id),
    )
    const available = stackingDirections(elements, selected)
    for (const order of orders) {
      const result = reorderElements(elements, selected, order)
      const direction = order === 'back' || order === 'backward' ? 'backward' : 'forward'
      assert.equal(result !== elements, available[direction])
      for (const included of [false, true]) {
        const partition = items => items.filter(item => selected.has(item.id) === included)
        assert.deepEqual(partition(result), partition(elements))
      }
    }
  }
  for (const order of orders) {
    assert.equal(reorderElements(elements, new Set(['missing']), order), elements)
    assert.equal(reorderElements(elements, new Set(ids(elements)), order), elements)
    assert.deepEqual(reorderElements([], new Set(), order), [])
  }
})

test('hit testing follows reordered drawings, cards and edges across all element types', () => {
  for (const create of [node, card, edge]) {
    const elements = [create('a'), create('b')]
    assert.equal(hitTest(elements, { x: 50, y: 50 }, 1)?.id, 'b')
    assert.equal(
      hitTest(reorderElements(elements, new Set(['b']), 'back'), { x: 50, y: 50 }, 1)?.id,
      'a',
    )
  }
  const elements = [card('card'), edge('edge'), node('node')]
  for (const order of orders) {
    assert.equal(
      hitTest(reorderElements(elements, new Set(['node']), order), { x: 50, y: 50 }, 1)?.id,
      order === 'back' || order === 'backward' ? 'edge' : 'node',
    )
  }
})

test('reordering persists without a schema change and undo/redo are atomic; boundary no-ops keep redo', () => {
  const initial = { ...createDocument(), elements: ['a', 'b', 'c'].map(node) }
  const store = new BoardStore(initial)
  store.select(new Set(['b']))
  store.reorderSelected('front')
  const reordered = store.getDocument()
  assert.deepEqual(ids(reordered.elements), ['a', 'c', 'b'])
  assert.deepEqual(store.getSnapshot().selected, new Set(['b']))
  assert.deepEqual(parseDocument(JSON.stringify(reordered)), reordered)
  store.reorderSelected('forward')
  store.undo()
  assert.equal(store.getDocument(), initial)
  store.select(new Set(['a']))
  store.reorderSelected('back')
  store.redo()
  assert.equal(store.getDocument(), reordered)
  store.undo()
  store.undo()
  assert.equal(store.getDocument(), initial)
})

test('legacy files retain the visual order once, while explicit document stacking preserves every slot', () => {
  const elements = [card('m'), node('a'), edge('e'), card('n'), node('b')]
  const legacy = { ...createDocument(), stacking: undefined, elements }
  const migrated = orderedDocument(parseDocument(JSON.stringify(legacy)))
  assert.deepEqual(ids(migrated.elements), ['e', 'a', 'b', 'm', 'n'])
  assert.equal(migrated.stacking, 'document')
  assert.equal(orderedDocument(migrated), migrated)
  const explicit = { ...legacy, stacking: 'document' }
  assert.equal(orderedDocument(explicit), explicit)
  assert.deepEqual(ids(new BoardStore(legacy).getDocument().elements), ['e', 'a', 'b', 'm', 'n'])
  assert.throws(
    () => parseDocument(JSON.stringify({ ...legacy, stacking: 'unknown' })),
    /Invalid whiteboard/,
  )
})
