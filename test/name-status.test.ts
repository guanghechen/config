import assert from 'node:assert/strict'
import test from 'node:test'
import { parseNameStatus } from '../src/git/name-status'

test('parses NUL-delimited add, modify, delete, copy, and rename entries', () => {
  const output = Buffer.from(
    [
      'A',
      'added file.ts',
      'M',
      'src/modified.ts',
      'D',
      'deleted\nfile.ts',
      'R097',
      'old/path.ts',
      'new/path.ts',
      'C100',
      'source.ts',
      'copy.ts',
      '',
    ].join('\0'),
  )

  assert.deepEqual(parseNameStatus(output), [
    {
      kind: 'added',
      status: 'A',
      previousPath: null,
      currentPath: 'added file.ts',
    },
    {
      kind: 'modified',
      status: 'M',
      previousPath: 'src/modified.ts',
      currentPath: 'src/modified.ts',
    },
    {
      kind: 'deleted',
      status: 'D',
      previousPath: 'deleted\nfile.ts',
      currentPath: null,
    },
    {
      kind: 'renamed',
      status: 'R097',
      previousPath: 'old/path.ts',
      currentPath: 'new/path.ts',
    },
    {
      kind: 'copied',
      status: 'C100',
      previousPath: 'source.ts',
      currentPath: 'copy.ts',
    },
  ])
})

test('rejects malformed name-status output', () => {
  assert.throws(
    () => parseNameStatus(Buffer.from(['R100', 'only-old-path', ''].join('\0'))),
    /missing current path/,
  )
})
