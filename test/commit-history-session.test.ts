import assert from 'node:assert/strict'
import test from 'node:test'
import type { ICommitPage, IGitCommit } from '../src/git/commit'
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

class RecordingHistorySource implements ICommitHistorySource {
  public abortCount = 0
  public failure: Error | null = null
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
      return Promise.resolve({ commits: [COMMIT], hasMore: false })
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
