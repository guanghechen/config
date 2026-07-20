import assert from 'node:assert/strict'
import test from 'node:test'
import type { IFileChange } from '../src/contract'
import { buildChangeTree } from '../src/tree/change-tree'

test('builds a directory-first file tree from display paths', () => {
  const changes: IFileChange[] = [
    createChange('modified', 'M', 'README.md', 'README.md'),
    createChange('added', 'A', null, 'src/zeta.ts'),
    createChange('renamed', 'R100', 'legacy/alpha.ts', 'src/alpha.ts'),
    createChange('deleted', 'D', 'src/old.ts', null),
  ]

  assert.deepEqual(buildChangeTree(changes), [
    {
      kind: 'directory',
      name: 'src',
      path: 'src',
      children: [
        {
          kind: 'file',
          name: 'alpha.ts',
          path: 'src/alpha.ts',
          change: changes[2],
        },
        {
          kind: 'file',
          name: 'old.ts',
          path: 'src/old.ts',
          change: changes[3],
        },
        {
          kind: 'file',
          name: 'zeta.ts',
          path: 'src/zeta.ts',
          change: changes[1],
        },
      ],
    },
    { kind: 'file', name: 'README.md', path: 'README.md', change: changes[0] },
  ])
})

test('retains file-to-directory replacements with the same name', () => {
  const deleted = createChange('deleted', 'D', 'config', null)
  const added = createChange('added', 'A', null, 'config/index.ts')
  const tree = buildChangeTree([deleted, added])

  assert.equal(tree.length, 2)
  assert.equal(tree[0]?.kind, 'directory')
  assert.equal(tree[1]?.kind, 'file')
})

function createChange(
  kind: IFileChange['kind'],
  status: string,
  previousPath: string | null,
  currentPath: string | null,
): IFileChange {
  return { kind, status, previousPath, currentPath }
}
