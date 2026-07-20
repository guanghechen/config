import assert from 'node:assert/strict'
import test from 'node:test'
import type { IGitReference } from '../src/git/commit'
import {
  formatCommitGraphPrefix,
  formatCommitReferenceSummary,
  formatCommitReferenceTooltip,
  resolveCommitGraphColorId,
} from '../src/view/history/graph-presentation'

test('formats compact native graph prefixes only when topology branches', () => {
  assert.equal(
    formatCommitGraphPrefix({ commitHash: 'a', lane: 0, laneCount: 1, parentCount: 1 }),
    '',
  )
  assert.equal(
    formatCommitGraphPrefix({ commitHash: 'a', lane: 0, laneCount: 1, parentCount: 2 }),
    '●─┬',
  )
  assert.equal(
    formatCommitGraphPrefix({ commitHash: 'b', lane: 0, laneCount: 2, parentCount: 1 }),
    '● │',
  )
  assert.equal(
    formatCommitGraphPrefix({ commitHash: 'c', lane: 1, laneCount: 2, parentCount: 1 }),
    '│ ●',
  )
})

test('formats concise ref summaries and complete tooltips', () => {
  const references: IGitReference[] = [
    { kind: 'head', name: 'main' },
    { kind: 'remoteBranch', name: 'origin/main' },
    { kind: 'tag', name: 'v1.0.0' },
  ]

  assert.equal(formatCommitReferenceSummary(references), 'HEAD → main · ☁ origin/main · +1')
  assert.equal(formatCommitReferenceTooltip(references), 'HEAD → main\n☁ origin/main\ntag: v1.0.0')
  assert.equal(formatCommitReferenceTooltip([]), null)
})

test('assigns stable theme colors by graph lane', () => {
  assert.equal(resolveCommitGraphColorId(0), 'charts.blue')
  assert.equal(resolveCommitGraphColorId(1), 'charts.purple')
  assert.equal(resolveCommitGraphColorId(5), 'charts.blue')
})
