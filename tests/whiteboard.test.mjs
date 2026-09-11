import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import ts from 'typescript'
import { chmod, mkdtemp, readFile, rm, stat, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import {
  attachEndpoint,
  duplicateElements,
  edgeEndpointAt,
  hitTest,
  labelLayout,
  moveElements,
  reconnectEdge,
  resolveEndpoint,
  worldPoint,
  zoomAt,
} from '../shared/whiteboard/geometry.ts'
import { wrapLabel } from '../shared/whiteboard/labels.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'
import {
  TextConflictError,
  readVersionedText,
  saveVersionedText,
} from '../server/util/versioned-text.ts'

const shape = (id, x = 0) => ({
  id,
  type: 'shape',
  shape: 'rectangle',
  x,
  y: 0,
  width: 200,
  height: 100,
  style: DEFAULT_STYLE,
})
const document = elements => ({ ...createDocument(), elements })

test('zoom preserves the world point beneath the cursor at all supported scales', () => {
  const camera = { x: -312, y: 510, zoom: 0.6 },
    cursor = { x: 911, y: 433 }
  for (const zoom of [0.001, 0.05, 0.5, 1, 4, 8, 100]) {
    const next = zoomAt(camera, cursor, zoom)
    assert.ok(next.zoom >= 0.05 && next.zoom <= 8)
    const a = worldPoint(cursor, camera),
      b = worldPoint(cursor, next)
    assert.ok(Math.hypot(a.x - b.x, a.y - b.y) < 1e-8)
  }
})

test('optional shape and edge labels round trip without changing legacy documents', () => {
  const a = { ...shape('a'), label: '验证请求\nValidate request' }
  const b = shape('b', 400)
  const edge = {
    id: 'edge',
    type: 'edge',
    from: { nodeId: 'a', x: 1, y: 0.5 },
    to: { nodeId: 'b', x: 0, y: 0.5 },
    style: DEFAULT_STYLE,
    label: 'HTTP 请求',
  }
  const labeled = document([a, b, edge])
  assert.deepEqual(parseDocument(JSON.stringify(labeled)), labeled)
  assert.equal(parseDocument(JSON.stringify(document([b]))).elements[0].label, undefined)
  for (const label of [null, 12, 'x'.repeat(4001)]) {
    assert.throws(
      () => parseDocument(JSON.stringify(document([{ ...a, label }]))),
      /Invalid element label/,
    )
    assert.throws(
      () => parseDocument(JSON.stringify(document([a, b, { ...edge, label }]))),
      /Invalid element label/,
    )
  }
  const copies = duplicateElements(labeled.elements, new Set(['a', 'b', 'edge']))
  assert.equal(copies[0].label, a.label)
  assert.equal(copies[2].label, edge.label)
})

test('label layout wraps CJK and keeps the original text when a small shape clips its preview', () => {
  assert.deepEqual(wrapLabel('节点A节点B', 60, 78).lines, ['节点A', '节点B'])
  assert.deepEqual(wrapLabel('API\n网关', 120, 78).lines, ['API', '网关'])
  assert.equal(wrapLabel('A long label', 1, 10).lines.length, 0)
  const node = { ...shape('label'), label: '完整文字必须保留\nThe full label remains available' }
  const layout = labelLayout(node, new Map())
  assert.ok(layout.lines.at(-1).endsWith('…'))
  assert.ok(
    layout.bounds.x >= node.x && layout.bounds.x + layout.bounds.width <= node.x + node.width,
  )
  const moved = { ...node, x: node.x + 50, y: node.y + 70 }
  const movedLayout = labelLayout(moved, new Map())
  assert.equal(movedLayout.bounds.x - layout.bounds.x, 50)
  assert.equal(movedLayout.bounds.y - layout.bounds.y, 70)
  assert.equal(parseDocument(JSON.stringify(document([node]))).elements[0].label, node.label)
})

test('edge labels can be selected away from the line and endpoint hit targets scale with the camera', () => {
  const a = shape('a'),
    b = shape('b', 400)
  const edge = {
    id: 'edge',
    type: 'edge',
    from: { nodeId: 'a', x: 1, y: 0.5 },
    to: { nodeId: 'b', x: 0, y: 0.5 },
    style: DEFAULT_STYLE,
    label: '请求\nresponse',
  }
  const elements = [a, b, edge],
    map = new Map(elements.map(item => [item.id, item]))
  assert.equal(hitTest(elements, { x: 300, y: 70 }, 1)?.id, 'edge')
  assert.equal(hitTest([a, b, { ...edge, label: '' }], { x: 300, y: 70 }, 1), undefined)
  assert.equal(edgeEndpointAt(edge, { x: 409, y: 50 }, map, 10 / 2), undefined)
  assert.equal(edgeEndpointAt(edge, { x: 409, y: 50 }, map, 10 / 0.5), 'to')
})

test('reconnecting, detaching and cancelling an edge preserve the other endpoint and undo atomically', () => {
  const a = shape('a'),
    b = shape('b', 400),
    c = { ...shape('c', 700), type: 'markdown', source: { kind: 'inline', content: '# Target' } }
  const edge = {
    id: 'edge',
    type: 'edge',
    from: { nodeId: 'a', x: 1, y: 0.5 },
    to: { nodeId: 'b', x: 0, y: 0.5 },
    style: DEFAULT_STYLE,
    label: 'request',
  }
  const initial = document([a, b, c, edge]),
    store = new BoardStore(initial)
  const connected = reconnectEdge(edge, 'to', { x: 702, y: 50 }, initial.elements, 10)
  assert.equal(connected.to.nodeId, 'c')
  assert.deepEqual(connected.from, edge.from)
  assert.equal(connected.label, 'request')
  store.preview([a, b, c, connected])
  assert.equal(store.getDocument(), initial)
  store.commit()
  store.undo()
  assert.equal(store.getDocument(), initial)
  store.redo()
  assert.equal(store.getDocument().elements.at(-1).to.nodeId, 'c')
  const detached = reconnectEdge(connected, 'to', { x: 1000, y: 500 }, initial.elements, 10)
  assert.deepEqual(detached.to, { x: 1000, y: 500 })
  store.preview([a, b, c, detached])
  store.cancel()
  assert.equal(store.getDocument().elements.at(-1).to.nodeId, 'c')
})

test('bound edge endpoints follow node translation and resize; free ends move independently', () => {
  const a = shape('a'),
    b = shape('b', 400)
  const edge = {
    id: 'edge',
    type: 'edge',
    from: attachEndpoint(a, { x: 198, y: 50 }),
    to: attachEndpoint(b, { x: 401, y: 50 }),
    style: DEFAULT_STYLE,
  }
  assert.deepEqual(edge.from, { nodeId: 'a', x: 1, y: 0.5 })
  const moved = moveElements([a, b, edge], new Set(['a']), { x: 30, y: 40 })
  assert.deepEqual(resolveEndpoint(edge.from, new Map(moved.map(item => [item.id, item]))), {
    x: 230,
    y: 90,
  })
  const resized = { ...a, width: 500, height: 200 }
  assert.deepEqual(resolveEndpoint(edge.from, new Map([['a', resized]])), { x: 500, y: 100 })
  const free = { ...edge, to: { x: 700, y: 600 } }
  const [next] = moveElements([free], new Set(['edge']), { x: 20, y: -30 })
  assert.deepEqual(next.from, free.from)
  assert.deepEqual(next.to, { x: 720, y: 570 })
})

test('precise hit testing rejects empty ellipse corners and freehand bounding-box gaps', () => {
  const ellipse = { ...shape('ellipse'), shape: 'ellipse' }
  assert.equal(hitTest([ellipse], { x: 1, y: 1 }, 0), undefined)
  assert.equal(hitTest([ellipse], { x: 100, y: 50 }, 0)?.id, 'ellipse')
  const stroke = {
    ...shape('stroke'),
    type: 'stroke',
    points: [
      { x: 0, y: 0 },
      { x: 1, y: 1 },
    ],
  }
  assert.equal(hitTest([stroke], { x: 190, y: 1 }, 3), undefined)
  assert.equal(hitTest([stroke], { x: 100, y: 50 }, 3)?.id, 'stroke')
})

test('one drag is one undo transaction, cancellation preserves history, and new edits invalidate redo', () => {
  const original = document([shape('a')]),
    store = new BoardStore(original)
  for (let i = 1; i <= 60; i++) store.preview([{ ...original.elements[0], x: i }])
  assert.equal(store.getDocument(), original, 'previews must not be autosaved')
  store.commit()
  assert.equal(store.getDocument().elements[0].x, 60)
  store.undo()
  assert.equal(store.getDocument(), original)
  store.redo()
  assert.equal(store.getDocument().elements[0].x, 60)
  store.preview([{ ...shape('a'), x: 100 }])
  store.cancel()
  assert.equal(store.getDocument().elements[0].x, 60)
  store.undo()
  store.commit(document([shape('b')]))
  store.redo()
  assert.equal(store.getDocument().elements[0].id, 'b')
})

test('deletion removes attached edges; undo restores the connected scene', () => {
  const a = shape('a'),
    b = shape('b', 400)
  const edge = {
    id: 'edge',
    type: 'edge',
    from: { nodeId: 'a', x: 1, y: 0.5 },
    to: { nodeId: 'b', x: 0, y: 0.5 },
    style: DEFAULT_STYLE,
  }
  const store = new BoardStore(document([a, b, edge]))
  store.select(new Set(['a']))
  store.removeSelected()
  assert.deepEqual(
    store.getDocument().elements.map(item => item.id),
    ['b'],
  )
  store.undo()
  assert.equal(store.getDocument().elements.length, 3)
})

test('copy remaps internal connections and detaches connections to uncopied nodes', () => {
  const a = shape('a'),
    b = shape('b', 400)
  const edge = {
    id: 'edge',
    type: 'edge',
    from: { nodeId: 'a', x: 1, y: 0.5 },
    to: { nodeId: 'b', x: 0, y: 0.5 },
    style: DEFAULT_STYLE,
  }
  const copies = duplicateElements([a, b, edge], new Set(['a', 'edge']))
  assert.equal(copies[1].from.nodeId, copies[0].id)
  assert.equal(copies[1].to.nodeId, undefined)
  assert.deepEqual(copies[1].to, { x: 424, y: 74 })
  assert.doesNotThrow(() => parseDocument(JSON.stringify(document(copies))))
})

test('import validates the entire scene before replacing the current document', () => {
  const valid = document([shape('a')]),
    store = new BoardStore(valid)
  assert.deepEqual(parseDocument(JSON.stringify(valid)), valid)
  for (const invalid of [
    { ...valid, schemaVersion: 2 },
    { ...valid, elements: [shape('a'), shape('a')] },
    { ...valid, elements: [{ ...shape('a'), width: -1 }] },
    {
      ...valid,
      elements: [
        { ...shape('a'), type: 'markdown', source: { kind: 'file', filepath: '../private.md' } },
      ],
    },
    {
      ...valid,
      elements: [
        {
          id: 'edge',
          type: 'edge',
          from: { nodeId: 'missing', x: 0, y: 0 },
          to: { x: 1, y: 1 },
          style: DEFAULT_STYLE,
        },
      ],
    },
    { ...valid, elements: [{ ...shape('a'), type: 'image', url: 'javascript:alert(1)' }] },
  ]) {
    assert.throws(() => store.replace(parseDocument(JSON.stringify(invalid))))
    assert.equal(store.getDocument(), valid)
  }
})

test('conditional saves reject stale and simultaneous revisions without discarding external content', async t => {
  const directory = await mkdtemp(path.join(tmpdir(), 'yoz-whiteboard-save-'))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const filepath = path.join(directory, 'notes.md')
  await writeFile(filepath, '# Original')
  await chmod(filepath, 0o664)
  const original = await readVersionedText(filepath)
  await writeFile(filepath, '# External change')
  await assert.rejects(
    saveVersionedText(filepath, '# Stale draft', original.revision),
    TextConflictError,
  )
  assert.equal(await readFile(filepath, 'utf8'), '# External change')
  const current = await readVersionedText(filepath)
  const results = await Promise.allSettled([
    saveVersionedText(filepath, '# First', current.revision),
    saveVersionedText(filepath, '# Second', current.revision),
  ])
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1)
  assert.equal(
    results.filter(
      result => result.status === 'rejected' && result.reason instanceof TextConflictError,
    ).length,
    1,
  )
  assert.equal(await readFile(filepath, 'utf8'), '# First')
  assert.equal((await stat(filepath)).mode & 0o777, 0o664, 'Saving preserves file permissions')
})

test('shared Markdown references discard an outdated response after a file-change notification', async t => {
  const requests = []
  const loadReferencedText = (filepath, revision, signal) =>
    new Promise(resolve => requests.push({ filepath, revision, signal, resolve }))
  const source = readFileSync(
    new URL('../src/view/whiteboard/resources.ts', import.meta.url),
    'utf8',
  ).replaceAll('import.meta.hot', 'undefined')
  const output = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText
  const module = { exports: {} }
  const require = id => {
    assert.equal(id, '@/shared/api/whiteboard')
    return { loadReferencedText }
  }
  new Function('require', 'module', 'exports', 'window', output)(
    require,
    module,
    module.exports,
    new EventTarget(),
  )
  const resources = new module.exports.MarkdownResources()
  t.after(resources.start())
  let notifications = 0
  t.after(
    resources.subscribe('/notes.md', () => {
      notifications += 1
    }),
  )
  t.after(
    resources.subscribe('/notes.md', () => {
      notifications += 1
    }),
  )
  assert.equal(requests.length, 1, 'Two visible nodes share one in-flight request')
  resources.refresh('/notes.md')
  assert.equal(requests[0].signal.aborted, true)
  requests[0].resolve({ filepath: '/notes.md', content: 'old', revision: 'old' })
  await new Promise(setImmediate)
  assert.equal(
    resources.get('/notes.md').data,
    undefined,
    'The old response must never reach the preview',
  )
  assert.equal(requests.length, 2)
  requests[1].resolve({ filepath: '/notes.md', content: 'new', revision: 'new' })
  await new Promise(setImmediate)
  assert.equal(resources.get('/notes.md').data.content, 'new')
  assert.equal(notifications, 2, 'Each subscriber receives the current version once')
})
