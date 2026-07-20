import assert from 'node:assert/strict'
import test from 'node:test'
import type { IGitCommit } from '../src/git/commit'
import { buildCommitGraphRows } from '../src/history/commit-graph'

test('tracks graph lanes through a merge topology', () => {
  const base = createCommit('d')
  const left = createCommit('b', [base.hash])
  const right = createCommit('c', [base.hash])
  const merge = createCommit('a', [left.hash, right.hash])

  assert.deepEqual(buildCommitGraphRows([merge, left, right, base]), [
    { commitHash: merge.hash, lane: 0, laneCount: 1, parentCount: 2 },
    { commitHash: left.hash, lane: 0, laneCount: 2, parentCount: 1 },
    { commitHash: right.hash, lane: 1, laneCount: 2, parentCount: 1 },
    { commitHash: base.hash, lane: 0, laneCount: 1, parentCount: 0 },
  ])
})

test('keeps linear history in one lane', () => {
  const root = createCommit('c')
  const middle = createCommit('b', [root.hash])
  const head = createCommit('a', [middle.hash])

  assert.deepEqual(
    buildCommitGraphRows([head, middle, root]).map(row => [row.lane, row.laneCount]),
    [
      [0, 1],
      [0, 1],
      [0, 1],
    ],
  )
})

function createCommit(seed: string, parents: ReadonlyArray<string> = []): IGitCommit {
  const hash = seed.repeat(40)
  return {
    hash,
    shortHash: hash.slice(0, 9),
    parents,
    authorName: 'VSGit Test',
    authoredAt: '2026-07-20T10:30:00Z',
    references: [],
    subject: seed,
  }
}
