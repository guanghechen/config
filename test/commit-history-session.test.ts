import assert from 'node:assert/strict'
import test from 'node:test'
import type { ICommitPage, IGitCommit } from '../src/git/commit'
import { createCommitSearchQuery, type ICommitSearchQuery } from '../src/git/commit-search'
import {
  CommitHistorySession,
  type ICommitHistorySource,
} from '../src/history/commit-history-session'

const COMMIT = createCommit('a')

test('aborts superseded history loads and derives the current HEAD commit', async () => {
  const source = new RecordingHistorySource('/slow')
  const session = new CommitHistorySession(source)

  const superseded = session.load('/slow')
  await source.blockingRequestStarted
  const current = session.load('/current')

  assert.equal(await superseded, null)
  assert.equal((await current)?.headCommit, COMMIT.hash)
  assert.equal(source.abortCount, 1)
  assert.equal(session.snapshot?.repositoryPath, '/current')
})

test('preserves the last successful history snapshot when refresh fails', async () => {
  const source = new RecordingHistorySource()
  const session = new CommitHistorySession(source)
  const successful = await session.load('/repo')

  source.failure = new Error('log failed')
  await assert.rejects(session.refresh(), /log failed/)
  assert.equal(session.snapshot, successful)
})

test('preserves search filters across refresh and clears back to HEAD history', async () => {
  const source = new RecordingHistorySource()
  const session = new CommitHistorySession(source)
  const query = createCommitSearchQuery({
    scope: { kind: 'all' },
    path: 'src',
    content: { mode: 'text', value: 'legacyFlag' },
  })

  assert.deepEqual((await session.search('/repo', query))?.searchQuery, query)
  await session.refresh()
  assert.deepEqual(source.searchQueries, [query, query])
  assert.equal((await session.clearSearch())?.searchQuery, null)
})

test('cancels an active search without replacing the last successful snapshot', async () => {
  const source = new RecordingHistorySource('/slow')
  const session = new CommitHistorySession(source)
  const successful = await session.load('/repo')
  const cancellation = new AbortController()

  const search = session.search(
    '/slow',
    createCommitSearchQuery({ message: 'target' }),
    cancellation.signal,
  )
  await source.blockingRequestStarted
  cancellation.abort()

  assert.equal(await search, null)
  assert.equal(session.snapshot, successful)
  assert.equal(source.abortCount, 1)
})

test('does not start a search for an already cancelled request', async () => {
  const source = new RecordingHistorySource()
  const session = new CommitHistorySession(source)
  const cancellation = new AbortController()
  cancellation.abort()

  assert.equal(
    await session.search(
      '/repo',
      createCommitSearchQuery({ message: 'target' }),
      cancellation.signal,
    ),
    null,
  )
  assert.deepEqual(source.searchQueries, [])
  assert.equal(session.snapshot, null)
})

test('does not let stale cancellation abort a newer history request', async () => {
  const source = new RecordingHistorySource('/slow')
  const session = new CommitHistorySession(source)
  const query = createCommitSearchQuery({ message: 'target' })
  const staleCancellation = new AbortController()

  const stale = session.search('/slow', query, staleCancellation.signal)
  await source.blockingRequestStarted
  const current = session.search('/slow', query)

  assert.equal(await stale, null)
  assert.equal(source.abortCount, 1)
  staleCancellation.abort()
  assert.equal(source.abortCount, 1)

  session.clear()
  assert.equal(await current, null)
  assert.equal(source.abortCount, 2)
})

class RecordingHistorySource implements ICommitHistorySource {
  public abortCount = 0
  public failure: Error | null = null
  public readonly searchQueries: ICommitSearchQuery[] = []
  public readonly blockingRequestStarted: Promise<void>

  private startBlockingRequest: (() => void) | null = null

  public constructor(private readonly blockedRepository: string | null = null) {
    this.blockingRequestStarted = new Promise(resolve => {
      this.startBlockingRequest = resolve
    })
  }

  public listCommits(
    repositoryPath: string,
    _limit: number,
    signal: AbortSignal,
  ): Promise<ICommitPage> {
    if (this.failure) return Promise.reject(this.failure)
    if (repositoryPath !== this.blockedRepository) {
      return Promise.resolve({ headCommit: COMMIT.hash, commits: [COMMIT], hasMore: false })
    }

    this.startBlockingRequest?.()
    return new Promise((_, reject) => {
      signal.addEventListener(
        'abort',
        () => {
          this.abortCount += 1
          const error = new Error('aborted')
          error.name = 'AbortError'
          reject(error)
        },
        { once: true },
      )
    })
  }

  public searchCommits(
    repositoryPath: string,
    query: ICommitSearchQuery,
    limit: number,
    signal: AbortSignal,
  ): Promise<ICommitPage> {
    this.searchQueries.push(query)
    return this.listCommits(repositoryPath, limit, signal)
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
