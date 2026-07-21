import assert from 'node:assert/strict'
import { setImmediate } from 'node:timers/promises'
import test from 'node:test'
import type { WebviewView } from 'vscode'
import type { ICommitPage, IGitCommit } from '../src/git/commit'
import { createCommitSearchQuery } from '../src/git/commit-search'
import {
  CommitHistorySession,
  type ICommitHistorySource,
} from '../src/history/commit-history-session'
import type { ICommitHistorySnapshot } from '../src/history/model'
import type { CommitSearchViewOperationResult } from '../src/view/history/search-view-contract'
import {
  CommitSearchViewProvider,
  type ICommitSearchViewOperations,
} from '../src/view/history/search-view-provider'

const COMMIT = createCommit('a')
const QUERY = createCommitSearchQuery({ message: 'fix' })

test('distinguishes cancelled and unavailable sidebar searches', async () => {
  let result: CommitSearchViewOperationResult = { kind: 'cancelled' }
  const operations = createOperations(() => Promise.resolve(result))
  const { provider, view, webview } = createProvider(operations)

  view.receive({ type: 'search', query: QUERY })
  await waitFor(() => countMessages(webview, 'busy') === 2)
  assert.deepEqual(webview.messages, [
    { type: 'busy', value: true },
    { type: 'busy', value: false },
  ])

  webview.messages.length = 0
  result = { kind: 'unavailable' }
  view.receive({ type: 'search', query: QUERY })
  await waitFor(() => countMessages(webview, 'busy') === 2)
  assert.deepEqual(webview.messages, [
    { type: 'busy', value: true },
    { type: 'error', message: 'Open or select a Git repository first.' },
    { type: 'busy', value: false },
  ])

  provider.dispose()
})

test('publishes only the latest sidebar request and balances its busy state', async () => {
  const requests: IPendingRequest[] = []
  const operations = createOperations((_query, signal) => {
    return new Promise(resolve => requests.push({ resolve, signal }))
  })
  const { provider, view, webview } = createProvider(operations)

  view.receive({ type: 'search', query: QUERY })
  await waitFor(() => requests.length === 1)
  view.receive({ type: 'search', query: QUERY })
  await waitFor(() => requests.length === 2)
  assert.equal(requests[0]?.signal.aborted, true)

  requests[0]?.resolve({ kind: 'cancelled' })
  await setImmediate()
  assert.equal(
    webview.messages.some(message => isMessage(message, 'busy', false)),
    false,
  )

  requests[1]?.resolve({ kind: 'applied', snapshot: createSnapshot() })
  await waitFor(() => webview.messages.some(message => isMessage(message, 'busy', false)))
  assert.equal(countMessages(webview, 'state'), 1)
  assert.ok(
    webview.messages.some(
      message => isRecord(message) && message.type === 'state' && message.synchronize === true,
    ),
  )

  provider.dispose()
})

test('aborts the active sidebar request when cancelled or disposed', async () => {
  const requests: IPendingRequest[] = []
  const operations = createOperations((_query, signal) => {
    return new Promise(resolve => requests.push({ resolve, signal }))
  })
  const { provider, view, webview } = createProvider(operations)

  view.receive({ type: 'search', query: QUERY })
  await waitFor(() => requests.length === 1)
  view.receive({ type: 'cancel' })
  assert.equal(requests[0]?.signal.aborted, true)
  requests[0]?.resolve({ kind: 'cancelled' })
  await waitFor(() => webview.messages.some(message => isMessage(message, 'busy', false)))

  view.receive({ type: 'search', query: QUERY })
  await waitFor(() => requests.length === 2)
  view.dispose()
  assert.equal(requests[1]?.signal.aborted, true)
  requests[1]?.resolve({ kind: 'cancelled' })
  provider.dispose()
})

interface IPendingRequest {
  readonly signal: AbortSignal
  readonly resolve: (result: CommitSearchViewOperationResult) => void
}

function createOperations(
  runSearch: ICommitSearchViewOperations['runSearch'],
): ICommitSearchViewOperations {
  return {
    runSearch,
    clearSearch: async () => ({ kind: 'applied', snapshot: null }),
  }
}

function createProvider(operations: ICommitSearchViewOperations): {
  readonly provider: CommitSearchViewProvider
  readonly view: TestWebviewView
  readonly webview: TestWebview
} {
  const historySession = new CommitHistorySession(new StaticHistorySource())
  const provider = new CommitSearchViewProvider({ historySession, operations })
  const view = new TestWebviewView()
  provider.resolveWebviewView(view as unknown as WebviewView)
  return { provider, view, webview: view.webview }
}

class TestWebviewView {
  public readonly webview = new TestWebview()
  private readonly disposeListeners = new Set<() => void>()

  public onDidDispose(listener: () => void): { dispose(): void } {
    this.disposeListeners.add(listener)
    return { dispose: () => this.disposeListeners.delete(listener) }
  }

  public receive(message: unknown): void {
    this.webview.receive(message)
  }

  public dispose(): void {
    for (const listener of [...this.disposeListeners]) listener()
  }
}

class TestWebview {
  public readonly cspSource = 'vscode-webview://vsgit-test'
  public readonly messages: unknown[] = []
  public html = ''
  public options: unknown = {}
  private readonly messageListeners = new Set<(message: unknown) => void>()

  public onDidReceiveMessage(listener: (message: unknown) => void): { dispose(): void } {
    this.messageListeners.add(listener)
    return { dispose: () => this.messageListeners.delete(listener) }
  }

  public postMessage(message: unknown): Promise<boolean> {
    this.messages.push(message)
    return Promise.resolve(true)
  }

  public receive(message: unknown): void {
    for (const listener of [...this.messageListeners]) listener(message)
  }
}

class StaticHistorySource implements ICommitHistorySource {
  public listCommits(): Promise<ICommitPage> {
    return Promise.resolve({ headCommit: COMMIT.hash, commits: [COMMIT], hasMore: false })
  }

  public searchCommits(): Promise<ICommitPage> {
    return this.listCommits()
  }
}

function createSnapshot(): ICommitHistorySnapshot {
  return {
    revision: 1,
    repositoryPath: '/repo',
    headCommit: COMMIT.hash,
    searchQuery: QUERY,
    commits: [COMMIT],
    hasMore: false,
    canLoadMore: false,
    limit: 50,
  }
}

function createCommit(seed: string): IGitCommit {
  const hash = seed.repeat(40)
  return {
    hash,
    shortHash: hash.slice(0, 9),
    parents: [],
    authorName: 'VSGit Test',
    authoredAt: '2026-07-20T10:30:00Z',
    references: [],
    subject: seed,
  }
}

function countMessages(webview: TestWebview, type: string): number {
  return webview.messages.filter(message => isRecord(message) && message.type === type).length
}

function isMessage(value: unknown, type: string, flag: boolean): boolean {
  return isRecord(value) && value.type === type && value.value === flag
}

function isRecord(value: unknown): value is Readonly<Record<string, unknown>> {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value)
}

async function waitFor(predicate: () => boolean): Promise<void> {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    if (predicate()) return
    await setImmediate()
  }
  assert.fail('Timed out waiting for the sidebar operation.')
}
