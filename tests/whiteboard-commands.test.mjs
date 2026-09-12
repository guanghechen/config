import assert from 'node:assert/strict'
import { test } from 'node:test'
import { mkdtemp, readFile, rm, symlink, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { spawnSync } from 'node:child_process'
import { applyCommands } from '../shared/whiteboard/commands.ts'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { resolveEndpoint } from '../shared/whiteboard/geometry.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'

const node = (id, x = 0) => ({
  id,
  type: 'shape',
  shape: 'rectangle',
  x,
  y: 0,
  width: 100,
  height: 80,
  style: DEFAULT_STYLE,
})
const batch = (document, commands) => ({
  kind: 'yoz.whiteboard.commands',
  schemaVersion: 1,
  documentId: document.id,
  commands,
})

test('agent batches resolve forward references, merge style patches and commit an entire edit once', () => {
  const original = { ...createDocument(), elements: [node('a')] }
  const store = new BoardStore(original)
  store.applyCommands(
    batch(original, [
      {
        op: 'add',
        elements: [
          {
            id: 'edge',
            type: 'edge',
            from: { nodeId: 'a', x: 1, y: 0.5 },
            to: { nodeId: 'b', x: 0, y: 0.5 },
            style: DEFAULT_STYLE,
          },
        ],
      },
      { op: 'add', elements: [node('b', 200)] },
      { op: 'update', id: 'a', patch: { label: '入口', style: { stroke: 'theme:red' } } },
      { op: 'group', ids: ['a', 'b', 'edge'], groupId: 'flow' },
      { op: 'move', ids: ['a'], delta: { x: 30, y: 40 } },
      { op: 'set-title', title: 'Agent diagram' },
    ]),
  )
  const result = store.getDocument()
  assert.equal(result.title, 'Agent diagram')
  assert.equal(result.elements[0].label, '入口')
  assert.deepEqual(result.elements[0].style, { ...DEFAULT_STYLE, stroke: 'theme:red' })
  const map = new Map(result.elements.map(element => [element.id, element]))
  assert.deepEqual(resolveEndpoint(map.get('edge').to, map), { x: 230, y: 80 })
  assert.ok(result.elements.every(element => element.groupId === 'flow'))
  store.undo()
  assert.equal(store.getDocument(), original)
  store.redo()
  assert.equal(store.getDocument(), result)
})

test('invalid batches leave the scene and history unchanged, including failures after valid commands', () => {
  const original = { ...createDocument(), elements: [node('a')] }
  const store = new BoardStore(original)
  const invalid = [
    { op: 'update', id: 'a', patch: { id: 'replacement' } },
    { op: 'update', id: 'a', patch: { type: 'text' } },
    { op: 'update', id: 'a', patch: { style: { stroke: 'bad-color' } } },
    { op: 'add', elements: [node('a')] },
    { op: 'remove', ids: ['missing'] },
    { op: 'move', ids: ['a'], delta: { x: Infinity, y: 0 } },
    { op: 'move', ids: ['a'], delta: { x: 0, y: 0 }, typo: true },
    { op: 'arrange', ids: ['a'], axis: 'z', mode: 'center' },
    { op: 'constructor', ids: ['a'] },
  ]
  for (const command of invalid) {
    assert.throws(() =>
      store.applyCommands(batch(original, [{ op: 'set-title', title: 'Not committed' }, command])),
    )
    assert.equal(store.getDocument(), original)
    store.undo()
    assert.equal(store.getDocument(), original)
  }
  assert.throws(
    () => applyCommands(original, { ...batch(original, []), documentId: 'wrong' }),
    /targeting this document ID/,
  )
  assert.throws(
    () =>
      applyCommands(original, {
        ...batch(original, []),
        commands: Array(1001).fill({ op: 'set-title', title: 'x' }),
      }),
    /1000 commands/,
  )
})

test('explicit removal drops attached edges; grouping cannot capture unrelated elements by reusing an ID', () => {
  const original = {
    ...createDocument(),
    elements: [
      node('a'),
      { ...node('b', 200), groupId: 'existing' },
      {
        id: 'edge',
        type: 'edge',
        style: DEFAULT_STYLE,
        from: { nodeId: 'a', x: 1, y: 0.5 },
        to: { nodeId: 'b', x: 0, y: 0.5 },
      },
    ],
  }
  assert.throws(
    () =>
      applyCommands(original, batch(original, [{ op: 'group', ids: ['a'], groupId: 'existing' }])),
    /already used/,
  )
  const result = applyCommands(original, batch(original, [{ op: 'remove', ids: ['a'] }]))
  assert.deepEqual(result.elements, [original.elements[1]])
})

test('command enums reject array coercion without changing the scene or losing redo', () => {
  const original = { ...createDocument(), elements: [node('a'), node('b', 300), node('c', 600)] }
  const store = new BoardStore(original)
  store.applyCommands(batch(original, [{ op: 'set-title', title: 'Redo target' }]))
  const redo = store.getDocument()
  store.undo()
  const commands = [
    ...['x', 'y'].map(axis => ({ op: 'arrange', ids: ['a', 'b'], axis: [axis], mode: 'center' })),
    ...['start', 'center', 'end', 'distribute'].map(mode => ({
      op: 'arrange',
      ids: ['a', 'b', 'c'],
      axis: 'x',
      mode: [mode],
    })),
    ...['back', 'backward', 'forward', 'front'].map(order => ({
      op: 'reorder',
      ids: ['b'],
      order: [order],
    })),
  ]
  for (const command of commands) {
    assert.throws(
      () =>
        store.applyCommands(
          batch(original, [{ op: 'set-title', title: 'Not committed' }, command]),
        ),
      /Command 2: (arrange requires|Unknown stacking order)/,
    )
    assert.equal(store.getDocument(), original)
    store.redo()
    assert.equal(store.getDocument(), redo)
    store.undo()
    assert.equal(store.getDocument(), original)
  }
})

test('move deltas respect schema limits even when the resulting coordinates are valid', () => {
  for (const axis of ['x', 'y']) {
    for (const sign of [-1, 1]) {
      const original = {
        ...createDocument(),
        elements: [{ ...node('a'), [axis]: -sign * 1e7 }],
      }
      const commands = delta => batch(original, [{ op: 'move', ids: ['a'], delta }])
      assert.throws(
        () => applyCommands(original, commands({ x: 0, y: 0, [axis]: sign * 2e7 })),
        /Command 1: delta/,
      )
      const moved = applyCommands(original, commands({ x: 0, y: 0, [axis]: sign * 1e7 }))
      assert.equal(moved.elements[0][axis], 0)
    }
  }
})

test('agent no-ops keep redo and layout/reorder commands retain valid selection semantics', () => {
  const original = { ...createDocument(), elements: [node('a'), node('b', 300), node('c', 600)] }
  const store = new BoardStore(original)
  store.applyCommands(
    batch(original, [
      { op: 'arrange', ids: ['a', 'b', 'c'], axis: 'x', mode: 'center' },
      { op: 'reorder', ids: ['a'], order: 'front' },
    ]),
  )
  const result = store.getDocument()
  assert.deepEqual(
    result.elements.map(element => element.id),
    ['b', 'c', 'a'],
  )
  assert.ok(result.elements.every(element => element.x === 300))
  store.undo()
  store.applyCommands(batch(original, [{ op: 'set-title', title: original.title }]))
  store.redo()
  assert.equal(store.getDocument(), result)
})

test('CLI validates, previews and atomically applies revision-checked batches; failures never overwrite files', async t => {
  const directory = await mkdtemp(path.join(tmpdir(), 'yoz-agent-'))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const cli = path.resolve(import.meta.dirname, '../scripts/whiteboard.mjs')
  const filepath = path.join(directory, 'agent.whiteboard')
  const run = (...args) => {
    const result = spawnSync(process.execPath, [cli, ...args], { encoding: 'utf8' })
    assert.equal(result.error, undefined)
    return {
      status: result.status,
      data: JSON.parse(result.status === 0 ? result.stdout : result.stderr),
    }
  }
  const created = run('create', filepath, '--title', 'Agent board')
  assert.equal(created.status, 0)
  assert.equal(run('create', filepath).status, 1)
  const initial = await readFile(filepath, 'utf8')
  const inspected = run('inspect', filepath)
  const commands = path.join(directory, 'batch.json')
  await writeFile(
    commands,
    JSON.stringify(batch(inspected.data.document, [{ op: 'add', elements: [node('agent-node')] }])),
  )
  const preview = run('apply', filepath, '--commands', commands, '--dry-run')
  assert.equal(preview.status, 0)
  assert.equal(preview.data.document.elements.length, 1)
  assert.equal(await readFile(filepath, 'utf8'), initial)
  assert.equal(run('apply', filepath, '--commands', commands).status, 1)
  const applied = run(
    'apply',
    filepath,
    '--commands',
    commands,
    '--revision',
    created.data.revision,
  )
  assert.equal(applied.status, 0)
  assert.equal(
    run('apply', filepath, '--commands', commands, '--revision', created.data.revision).status,
    1,
  )
  const validated = run('validate', filepath)
  assert.equal(validated.data.revision, applied.data.revision)
  const saved = await readFile(filepath, 'utf8')
  for (const command of [
    { op: 'arrange', ids: ['agent-node'], axis: ['x'], mode: 'start' },
    { op: 'arrange', ids: ['agent-node'], axis: 'x', mode: ['start'] },
    { op: 'reorder', ids: ['agent-node'], order: ['front'] },
    { op: 'update', id: 'agent-node', patch: { shape: ['rectangle'] } },
    {
      op: 'add',
      elements: [
        {
          id: 'invalid-edge',
          type: 'edge',
          style: DEFAULT_STYLE,
          from: { nodeId: '', x: 0, y: 0 },
          to: { x: 100, y: 100 },
        },
      ],
    },
  ]) {
    await writeFile(
      commands,
      JSON.stringify(
        batch(inspected.data.document, [
          { op: 'set-title', title: 'Must not be written' },
          command,
        ]),
      ),
    )
    for (const options of [['--dry-run'], ['--revision', validated.data.revision]]) {
      const rejected = run('apply', filepath, '--commands', commands, ...options)
      assert.equal(rejected.status, 1)
      assert.equal(rejected.data.ok, false)
      assert.equal(typeof rejected.data.error, 'string')
      assert.equal(await readFile(filepath, 'utf8'), saved)
    }
  }
  const alias = path.join(directory, 'alias.whiteboard')
  await symlink(filepath, alias)
  assert.equal(run('inspect', alias).data.filepath, validated.data.filepath)
  const absent = path.join(directory, 'absent.whiteboard')
  assert.equal(run('create', absent, '--dry-run').status, 1)
  await assert.rejects(readFile(absent), { code: 'ENOENT' })
})
