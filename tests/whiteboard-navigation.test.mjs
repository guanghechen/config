import assert from 'node:assert/strict'
import { test } from 'node:test'
import { createDocument } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import { applyCommands } from '../shared/whiteboard/commands.ts'
import { cameraForBounds, touchCamera, viewportBounds } from '../shared/whiteboard/navigation.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'

const region = { id: 'overview', name: 'Overview', x: 100, y: 200, width: 800, height: 400 }
const batch = (document, commands) => ({
  kind: 'yoz.whiteboard.commands',
  schemaVersion: 1,
  documentId: document.id,
  commands,
})

test('named areas and repeated presentation steps validate without changing element order', () => {
  const document = {
    ...createDocument(),
    regions: [region],
    presentation: ['overview', 'overview'],
  }
  assert.deepEqual(parseDocument(JSON.stringify(document)), document)
  for (const patch of [
    { regions: [region, region] },
    { regions: [{ ...region, name: '' }] },
    { regions: [{ ...region, width: 0 }] },
    { presentation: ['missing'] },
  ])
    assert.throws(() => parseDocument(JSON.stringify({ ...document, ...patch })), /areas|steps/)
})

test('agents atomically replace areas and presentation references, and undo restores the whole change', () => {
  const document = { ...createDocument(), regions: [region], presentation: ['overview'] }
  const commands = [
    { op: 'set-regions', regions: [{ ...region, id: 'detail', name: 'Detail' }] },
    { op: 'set-presentation', steps: ['detail', 'detail'] },
  ]
  const result = applyCommands(document, batch(document, commands))
  assert.deepEqual(result.presentation, ['detail', 'detail'])
  assert.throws(() => applyCommands(document, batch(document, commands.slice(0, 1))), /steps/)
  const store = new BoardStore(document)
  store.applyCommands(batch(document, commands))
  store.camera({ x: 0, y: 0, zoom: 2 })
  store.undo()
  assert.equal(store.getDocument(), document)
  assert.equal(store.getSnapshot().camera.zoom, 2)
})

test('area focus uses safe viewport margins and camera navigation does not enter document history', () => {
  const camera = cameraForBounds(region, 1200, 800)
  assert.equal((region.x + region.width / 2) * camera.zoom + camera.x, 600)
  assert.equal((region.y + region.height / 2) * camera.zoom + camera.y, 400)
  assert.ok(region.width * camera.zoom <= 1040)
  assert.deepEqual(viewportBounds({ x: 50, y: -100, zoom: 2 }, 800, 600), {
    x: -25,
    y: 50,
    width: 400,
    height: 300,
  })
  assert.equal(cameraForBounds({ x: 0, y: 0, width: 1, height: 1 }, 1200, 800).zoom, 2)
})

test('two-finger movement combines pan and zoom around the original midpoint and clamps extreme pinches', () => {
  const initial = { x: 30, y: 40, zoom: 1 }
  const result = touchCamera(
    initial,
    [
      { x: 100, y: 100 },
      { x: 200, y: 100 },
    ],
    [
      { x: 120, y: 160 },
      { x: 320, y: 160 },
    ],
  )
  assert.deepEqual(result, { x: -20, y: 40, zoom: 2 })
  assert.equal(
    touchCamera(
      initial,
      [
        { x: 0, y: 0 },
        { x: 1, y: 0 },
      ],
      [
        { x: 0, y: 0 },
        { x: 1e6, y: 0 },
      ],
    ).zoom,
    4,
  )
  assert.equal(
    touchCamera(
      initial,
      [
        { x: 0, y: 0 },
        { x: 100, y: 0 },
      ],
      [
        { x: 0, y: 0 },
        { x: 0, y: 0 },
      ],
    ).zoom,
    0.05,
  )
  assert.equal(touchCamera(initial, [], []), initial)
})
