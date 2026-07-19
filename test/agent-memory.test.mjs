import assert from 'node:assert/strict'
import { createHmac } from 'node:crypto'
import test from 'node:test'
import { AgentMemoryStore } from '../src/agent/background/memory.ts'
import { createPageMemoryScopeId } from '../src/agent/background/page-scope.ts'

test('agent memory isolates origin and page scopes while serializing writes', async () => {
  let storedNotes = []
  const store = new AgentMemoryStore({
    async read() {
      return structuredClone(storedNotes)
    },
    async write(notes) {
      await new Promise(resolve => setTimeout(resolve, 1))
      storedNotes = structuredClone(notes)
    },
  })
  const firstPage = createPage('page-1', 'https://example.com/first')
  const secondPage = createPage('page-2', 'https://example.com/second')

  await Promise.all([
    store.execute('memory.set', firstPage, 'scope-first', {
      scope: 'origin',
      key: 'language',
      value: 'zh-CN',
    }),
    store.execute('memory.set', firstPage, 'scope-first', {
      scope: 'page',
      key: 'summary',
      value: 'First page',
    }),
  ])

  const shared = await store.execute('memory.get', secondPage, 'scope-second', {
    scope: 'origin',
    key: 'language',
  })
  assert.equal(shared.note.value, 'zh-CN')

  const isolated = await store.execute('memory.get', secondPage, 'scope-second', {
    scope: 'page',
    key: 'summary',
  })
  assert.equal(isolated.note, null)

  const firstPageNotes = await store.execute('memory.list', firstPage, 'scope-first', {
    scope: 'page',
  })
  assert.deepEqual(
    firstPageNotes.notes.map(note => [note.key, note.value]),
    [['summary', 'First page']],
  )

  assert.deepEqual(
    await store.execute('memory.delete', firstPage, 'scope-first', {
      scope: 'page',
      key: 'summary',
    }),
    { scope: 'page', deleted: true },
  )
})

test('agent memory validates keys, scopes, and values at the boundary', async () => {
  const store = new AgentMemoryStore({
    async read() {
      return []
    },
    async write() {},
  })
  const page = createPage('page-1', 'https://example.com/first')

  await assert.rejects(
    store.execute('memory.set', page, 'scope-first', {
      scope: 'page',
      key: '../unsafe',
      value: 'x',
    }),
    /Memory key is invalid/,
  )
  await assert.rejects(
    store.execute('memory.set', page, 'scope-first', { scope: 'unknown', key: 'safe', value: 'x' }),
    /Memory scope must be origin or page/,
  )
  await assert.rejects(
    store.execute('memory.set', page, 'scope-first', {
      scope: 'page',
      key: 'safe',
      value: 'x'.repeat(2_049),
    }),
    /Memory value is too large/,
  )
})

test('queued memory mutations fail closed after authorization is revoked', async () => {
  let releaseFirstWrite
  let firstWriteStarted
  const firstWriteGate = new Promise(resolve => {
    releaseFirstWrite = resolve
  })
  const firstWriteSignal = new Promise(resolve => {
    firstWriteStarted = resolve
  })
  let storedNotes = []
  let writeCount = 0
  const store = new AgentMemoryStore({
    async read() {
      return structuredClone(storedNotes)
    },
    async write(notes) {
      writeCount += 1
      if (writeCount === 1) {
        firstWriteStarted()
        await firstWriteGate
      }
      storedNotes = structuredClone(notes)
    },
  })
  const page = createPage('page-1', 'https://example.com/first')
  const firstWrite = store.execute('memory.set', page, 'scope-first', {
    scope: 'page',
    key: 'first',
    value: 'allowed',
  })
  await firstWriteSignal

  let authorized = true
  const revokedWrite = store.execute(
    'memory.set',
    page,
    'scope-first',
    { scope: 'page', key: 'second', value: 'revoked' },
    () => authorized,
  )
  authorized = false
  releaseFirstWrite()

  await firstWrite
  await assert.rejects(revokedWrite, error => error.code === 'PERMISSION_DENIED')
  assert.deepEqual(
    storedNotes.map(note => note.key),
    ['first'],
  )
})

test('page memory scope IDs distinguish sensitive URL components without exposing them', async () => {
  const sensitiveUrl = 'https://example.com/editor?id=first#section-a'
  const first = await createPageMemoryScopeId('browser-session-a', sensitiveUrl)
  const second = await createPageMemoryScopeId(
    'browser-session-a',
    'https://example.com/editor?id=second#section-b',
  )
  const repeated = await createPageMemoryScopeId(
    'browser-session-a',
    'https://example.com/editor?id=first#section-a',
  )
  const otherSession = await createPageMemoryScopeId(
    'browser-session-b',
    'https://example.com/editor?id=first#section-a',
  )

  assert.notEqual(first, second)
  assert.equal(first, repeated)
  assert.notEqual(first, otherSession)
  assert.doesNotMatch(first, /first|section/)
  assert.equal(
    first,
    `scope_${createHmac('sha256', 'browser-session-a').update(sensitiveUrl).digest('hex')}`,
  )
})

test('memory quotas prevent one origin or scope from starving other origins', async () => {
  let storedNotes = []
  const store = new AgentMemoryStore({
    async read() {
      return structuredClone(storedNotes)
    },
    async write(notes) {
      storedNotes = structuredClone(notes)
    },
  })
  const firstOriginPage = createPage('page-a1', 'https://first.example/a')
  const secondPageOnFirstOrigin = createPage('page-a2', 'https://first.example/b')
  const otherOriginPage = createPage('page-b1', 'https://second.example/a')

  for (let index = 0; index < 16; index += 1) {
    await store.execute('memory.set', firstOriginPage, 'scope-a1', {
      scope: 'page',
      key: `a${index}`,
      value: 'x',
    })
  }
  await assert.rejects(
    store.execute('memory.set', firstOriginPage, 'scope-a1', {
      scope: 'page',
      key: 'scope-overflow',
      value: 'x',
    }),
    /scope limit reached/,
  )

  for (let index = 0; index < 16; index += 1) {
    await store.execute('memory.set', secondPageOnFirstOrigin, 'scope-a2', {
      scope: 'page',
      key: `b${index}`,
      value: 'x',
    })
  }
  await assert.rejects(
    store.execute('memory.set', secondPageOnFirstOrigin, 'scope-a3', {
      scope: 'page',
      key: 'origin-overflow',
      value: 'x',
    }),
    /origin limit reached/,
  )

  const otherOriginResult = await store.execute('memory.set', otherOriginPage, 'scope-b1', {
    scope: 'page',
    key: 'available',
    value: 'x',
  })
  assert.equal(otherOriginResult.note.key, 'available')
})

function createPage(pageId, url) {
  return {
    pageId,
    tabId: 1,
    windowId: 1,
    frameId: 0,
    documentId: `${pageId}-document`,
    url,
    origin: new URL(url).origin,
    title: '',
    active: true,
    website: 'test',
    capabilities: [],
    revision: 1,
  }
}
