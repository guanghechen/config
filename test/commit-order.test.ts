import assert from 'node:assert/strict'
import test from 'node:test'
import type { IGitCommit } from '../src/git/commit'
import { orderCommitsForComparison } from '../src/history/commit-order'

const NEWEST = createCommit('a', 'Newest')
const MIDDLE = createCommit('b', 'Middle')
const OLDEST = createCommit('c', 'Oldest')
const HISTORY = [NEWEST, MIDDLE, OLDEST]

test('orders selected commits from older base to newer target', () => {
  assert.deepEqual(orderCommitsForComparison(HISTORY, [NEWEST, OLDEST]), {
    base: OLDEST,
    target: NEWEST,
  })
  assert.deepEqual(orderCommitsForComparison(HISTORY, [OLDEST, MIDDLE]), {
    base: OLDEST,
    target: MIDDLE,
  })
})

test('rejects incomplete, duplicate, and stale selections', () => {
  assert.equal(orderCommitsForComparison(HISTORY, [NEWEST]), null)
  assert.equal(orderCommitsForComparison(HISTORY, [NEWEST, NEWEST]), null)
  assert.equal(orderCommitsForComparison(HISTORY, [NEWEST, createCommit('d', 'Stale')]), null)
})

function createCommit(seed: string, subject: string): IGitCommit {
  const hash = seed.repeat(40)
  return {
    hash,
    shortHash: hash.slice(0, 9),
    parents: [],
    authorName: 'VSGit Test',
    authoredAt: '2026-07-20T10:30:00Z',
    subject,
  }
}
