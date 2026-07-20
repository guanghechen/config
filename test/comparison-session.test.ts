import assert from 'node:assert/strict'
import test from 'node:test'
import type { IRevisionComparison } from '../src/comparison/model'
import { ComparisonSession, type IComparisonSource } from '../src/comparison/session'
import type { IFileChange } from '../src/git/file-change'

const BASE_COMMIT = 'a'.repeat(40)
const TARGET_COMMIT = 'b'.repeat(40)
const NEXT_COMMIT = 'c'.repeat(40)

test('compares resolved commits without resolving references again', async () => {
  const source = new RecordingComparisonSource()
  const session = new ComparisonSession(source)
  const comparison = createComparison(TARGET_COMMIT)

  const snapshot = await session.compareResolved(comparison)

  assert.equal(source.resolveCount, 0)
  assert.equal(source.listCount, 1)
  assert.equal(snapshot?.baseCommit, BASE_COMMIT)
  assert.equal(snapshot?.targetCommit, TARGET_COMMIT)
})

test('aborts a superseded comparison and publishes only the newest snapshot', async () => {
  const source = new RecordingComparisonSource(TARGET_COMMIT)
  const session = new ComparisonSession(source)

  const superseded = session.compareResolved(createComparison(TARGET_COMMIT))
  await source.blockingRequestStarted
  const current = session.compareResolved(createComparison(NEXT_COMMIT))

  assert.equal(await superseded, null)
  assert.equal((await current)?.targetCommit, NEXT_COMMIT)
  assert.equal(source.abortCount, 1)
  assert.equal(session.snapshot?.targetCommit, NEXT_COMMIT)
})

test('preserves the last successful comparison when a current request fails', async () => {
  const source = new RecordingComparisonSource()
  const session = new ComparisonSession(source)
  const successful = await session.compareResolved(createComparison(TARGET_COMMIT))

  source.failure = new Error('diff failed')
  await assert.rejects(session.compareResolved(createComparison(NEXT_COMMIT)), /diff failed/)
  assert.equal(session.snapshot, successful)
})

class RecordingComparisonSource implements IComparisonSource {
  public abortCount = 0
  public failure: Error | null = null
  public listCount = 0
  public resolveCount = 0
  public readonly blockingRequestStarted: Promise<void>

  private startBlockingRequest: (() => void) | null = null

  public constructor(private readonly blockedTarget: string | null = null) {
    this.blockingRequestStarted = new Promise(resolve => {
      this.startBlockingRequest = resolve
    })
  }

  public resolveCommit(
    _repositoryPath: string,
    reference: string,
    _signal: AbortSignal,
  ): Promise<string> {
    this.resolveCount += 1
    return Promise.resolve(reference === 'base' ? BASE_COMMIT : TARGET_COMMIT)
  }

  public listChanges(
    _repositoryPath: string,
    _baseCommit: string,
    targetCommit: string,
    signal: AbortSignal,
  ): Promise<ReadonlyArray<IFileChange>> {
    this.listCount += 1
    if (this.failure) return Promise.reject(this.failure)
    if (targetCommit !== this.blockedTarget) return Promise.resolve([])

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

function createComparison(targetCommit: string): IRevisionComparison {
  return {
    repositoryPath: '/repo',
    baseRef: BASE_COMMIT,
    targetRef: targetCommit,
    baseCommit: BASE_COMMIT,
    targetCommit,
  }
}
