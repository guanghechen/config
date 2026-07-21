import assert from 'node:assert/strict'
import test from 'node:test'
import type { IGitCommit } from '../src/git/commit'
import { createCommitSearchQuery } from '../src/git/commit-search'
import type { IFileChange } from '../src/git/file-change'
import type { ICommitHistorySnapshot } from '../src/history/model'
import { buildCommitChangeTree, createCommitRootNodes } from '../src/view/history/tree'

const COMMIT: IGitCommit = {
  hash: 'a'.repeat(40),
  shortHash: 'a'.repeat(9),
  parents: ['b'.repeat(40)],
  authorName: 'VSGit Test',
  authoredAt: '2026-07-20T10:30:00Z',
  references: [],
  subject: 'Add history view',
}

test('creates commit roots with a load-more sentinel', () => {
  const snapshot: ICommitHistorySnapshot = {
    revision: 3,
    repositoryPath: '/repo',
    headCommit: COMMIT.hash,
    searchQuery: null,
    commits: [COMMIT],
    hasMore: true,
    canLoadMore: true,
    limit: 50,
  }

  assert.deepEqual(createCommitRootNodes(snapshot), [
    {
      kind: 'commit',
      context: {
        historyRevision: 3,
        repositoryPath: '/repo',
        commit: COMMIT,
        parentCommit: COMMIT.parents[0],
      },
      graph: {
        commitHash: COMMIT.hash,
        lane: 0,
        laneCount: 1,
        parentCount: 1,
      },
    },
    { kind: 'load-more-commits', historyRevision: 3 },
  ])
})

test('does not offer load more after reaching the history cap', () => {
  const snapshot: ICommitHistorySnapshot = {
    revision: 3,
    repositoryPath: '/repo',
    headCommit: COMMIT.hash,
    searchQuery: null,
    commits: [COMMIT],
    hasMore: true,
    canLoadMore: false,
    limit: 500,
  }

  assert.equal(
    createCommitRootNodes(snapshot).some(node => node.kind === 'load-more-commits'),
    false,
  )
})

test('attaches immutable commit context to directory-first change nodes', () => {
  const change: IFileChange = {
    kind: 'modified',
    status: 'M',
    previousPath: 'src/index.ts',
    currentPath: 'src/index.ts',
  }
  const context = {
    historyRevision: 3,
    repositoryPath: '/repo',
    commit: COMMIT,
    parentCommit: COMMIT.parents[0] ?? null,
  }

  assert.deepEqual(buildCommitChangeTree(context, [change]), [
    {
      kind: 'commit-directory',
      name: 'src',
      path: 'src',
      context,
      children: [
        {
          kind: 'commit-file',
          name: 'index.ts',
          path: 'src/index.ts',
          context,
          change,
        },
      ],
    },
  ])
})

test('does not render filtered search results as a continuous commit graph', () => {
  const unrelatedCommit: IGitCommit = {
    ...COMMIT,
    hash: 'c'.repeat(40),
    shortHash: 'c'.repeat(9),
    parents: ['d'.repeat(40)],
  }
  const snapshot: ICommitHistorySnapshot = {
    revision: 4,
    repositoryPath: '/repo',
    headCommit: COMMIT.hash,
    searchQuery: createCommitSearchQuery({ message: 'history' }),
    commits: [COMMIT, unrelatedCommit],
    hasMore: false,
    canLoadMore: false,
    limit: 50,
  }

  assert.deepEqual(
    createCommitRootNodes(snapshot).map(node =>
      node.kind === 'commit' ? [node.graph.lane, node.graph.laneCount] : null,
    ),
    [
      [0, 1],
      [0, 1],
    ],
  )
})

test('compacts empty single-child directory chains', () => {
  const changes: IFileChange[] = [
    {
      kind: 'modified',
      status: 'M',
      previousPath: 'src/features/account/index.ts',
      currentPath: 'src/features/account/index.ts',
    },
    {
      kind: 'added',
      status: 'A',
      previousPath: null,
      currentPath: 'src/features/search/index.ts',
    },
  ]
  const context = {
    historyRevision: 3,
    repositoryPath: '/repo',
    commit: COMMIT,
    parentCommit: COMMIT.parents[0] ?? null,
  }

  assert.deepEqual(buildCommitChangeTree(context, changes), [
    {
      kind: 'commit-directory',
      name: 'src/features',
      path: 'src/features',
      context,
      children: [
        {
          kind: 'commit-directory',
          name: 'account',
          path: 'src/features/account',
          context,
          children: [
            {
              kind: 'commit-file',
              name: 'index.ts',
              path: 'src/features/account/index.ts',
              context,
              change: changes[0],
            },
          ],
        },
        {
          kind: 'commit-directory',
          name: 'search',
          path: 'src/features/search',
          context,
          children: [
            {
              kind: 'commit-file',
              name: 'index.ts',
              path: 'src/features/search/index.ts',
              context,
              change: changes[1],
            },
          ],
        },
      ],
    },
  ])
})
