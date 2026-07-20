import assert from 'node:assert/strict'
import test from 'node:test'
import type { IGitCommit } from '../src/git/commit'
import { CommitMarkSession } from '../src/history/commit-mark-session'
import type { ICommitHistorySnapshot } from '../src/history/model'

const FIRST = createCommit('a')
const SECOND = createCommit('b')
const THIRD = createCommit('c')

test('marks at most two current commits and supports unmarking', () => {
  const session = new CommitMarkSession()
  const changes: string[][] = []
  session.onDidChange(marks => changes.push([...marks]))
  session.reconcile(createSnapshot('/repo', [FIRST, SECOND, THIRD]))

  assert.equal(session.mark('/repo', FIRST.hash), 'marked')
  assert.equal(session.mark('/repo', FIRST.hash), 'already-marked')
  assert.equal(session.mark('/repo', SECOND.hash), 'marked')
  assert.equal(session.mark('/repo', THIRD.hash), 'full')
  assert.equal(session.isMarked('/repo', FIRST.hash), true)
  assert.equal(session.unmark('/repo', FIRST.hash), true)
  assert.deepEqual(session.markedHashes, [SECOND.hash])
  assert.deepEqual(changes, [[FIRST.hash], [FIRST.hash, SECOND.hash], [SECOND.hash]])
})

test('reconciles marks with refreshed history and repository changes', () => {
  const session = new CommitMarkSession()
  session.reconcile(createSnapshot('/repo', [FIRST, SECOND]))
  session.mark('/repo', FIRST.hash)
  session.mark('/repo', SECOND.hash)

  session.reconcile(createSnapshot('/repo', [SECOND, THIRD], 2))
  assert.deepEqual(session.markedHashes, [SECOND.hash])
  assert.equal(session.mark('/other', THIRD.hash), 'stale')

  session.reconcile(createSnapshot('/other', [THIRD], 3))
  assert.deepEqual(session.markedHashes, [])
})

function createCommit(seed: string): IGitCommit {
  const hash = seed.repeat(40)
  return {
    hash,
    shortHash: hash.slice(0, 9),
    parents: [],
    authorName: 'VSGit Test',
    authoredAt: '2026-07-20T10:30:00Z',
    subject: seed,
  }
}

function createSnapshot(
  repositoryPath: string,
  commits: ReadonlyArray<IGitCommit>,
  revision = 1,
): ICommitHistorySnapshot {
  return { revision, repositoryPath, commits, hasMore: false, limit: 50 }
}
