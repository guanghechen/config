import assert from 'node:assert/strict'
import test from 'node:test'
import type { IGitCommit } from '../src/git/commit'
import type { IFileChange } from '../src/git/file-change'
import type { ICommitHistorySnapshot } from '../src/history/model'
import { buildCommitChangeTree, createCommitRootNodes } from '../src/view/commit-tree'

const COMMIT: IGitCommit = {
  hash: 'a'.repeat(40),
  shortHash: 'a'.repeat(9),
  parents: ['b'.repeat(40)],
  authorName: 'VSGit Test',
  authoredAt: '2026-07-20T10:30:00Z',
  subject: 'Add history view',
}

test('creates commit roots with a load-more sentinel', () => {
  const snapshot: ICommitHistorySnapshot = {
    revision: 3,
    repositoryPath: '/repo',
    commits: [COMMIT],
    hasMore: true,
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
    },
    { kind: 'load-more-commits', historyRevision: 3 },
  ])
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
