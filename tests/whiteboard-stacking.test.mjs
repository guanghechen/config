import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_STYLE, createDocument, elementLayer } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import { hitTest, resolveEndpoint } from '../shared/whiteboard/geometry.ts'
import { expandSelection } from '../shared/whiteboard/organization.ts'
import { reorderElements, stackingDirections } from '../shared/whiteboard/stacking.ts'
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

test('each layer reorders independently; unrelated layer slots and element objects are preserved', () => {
  const elements = [node('a'), card('m'), edge('e'), node('b'), card('n'), edge('f'), node('c')]
  const selected = new Set(['a', 'm', 'e'])
  for (const order of ['forward', 'front']) {
    const result = reorderElements(elements, selected, order)
    assert.deepEqual(
      ids(result),
      order === 'front' ? ['b', 'n', 'f', 'c', 'm', 'e', 'a'] : ['b', 'n', 'f', 'a', 'm', 'e', 'c'],
    )
    result.forEach((element, index) => {
      assert.equal(elementLayer(element), elementLayer(elements[index]))
      assert.equal(
        element,
        elements.find(item => item.id === element.id),
      )
    })
  }
  assert.deepEqual(ids(reorderElements(elements, new Set(['a']), 'front')), [
    'b',
    'm',
    'e',
    'c',
    'n',
    'f',
    'a',
  ])
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
  assert.deepEqual(ids(result), ['outside', 'top', 'a', 'other', 'e', 'b'])
  const map = new Map(result.map(element => [element.id, element]))
  assert.deepEqual(resolveEndpoint(connection.from, map), { x: 100, y: 50 })
  assert.deepEqual(resolveEndpoint(connection.to, map), { x: 200, y: 50 })
  assert.deepEqual(expandSelection(result, new Set(['b'])), new Set(['b', 'a', 'e']))
  for (const element of elements) assert.equal(map.get(element.id), element)
})

test('availability matches actual movement for every subset of an interleaved three-layer scene', () => {
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
      for (const layer of [0, 1, 2]) {
        for (const included of [false, true]) {
          const partition = items =>
            items.filter(item => elementLayer(item) === layer && selected.has(item.id) === included)
          assert.deepEqual(partition(result), partition(elements))
        }
      }
    }
  }
  for (const order of orders) {
    assert.equal(reorderElements(elements, new Set(['missing']), order), elements)
    assert.equal(reorderElements(elements, new Set(ids(elements)), order), elements)
    assert.deepEqual(reorderElements([], new Set(), order), [])
  }
})

test('hit testing follows reordered drawings, cards and edges while retaining layer precedence', () => {
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
      'card',
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
