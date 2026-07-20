import assert from 'node:assert/strict'
import test from 'node:test'
import { parseCommitLog } from '../src/git/commit-log'

const HASH = 'a'.repeat(40)
const PARENT_HASH = 'b'.repeat(40)
const ROOT_HASH = 'c'.repeat(40)

test('parses NUL-delimited commit records including a root commit', () => {
  const output = Buffer.concat([
    createRecord([
      HASH,
      HASH.slice(0, 9),
      PARENT_HASH,
      'Ada Lovelace',
      '2026-07-20T10:30:00+08:00',
      'HEAD -> refs/heads/main, refs/remotes/origin/main, tag: refs/tags/v1.0.0',
      'Add commit browser',
    ]),
    createRecord([ROOT_HASH, ROOT_HASH.slice(0, 9), '', '', '2026-07-19T09:00:00Z', '', '']),
  ])

  const commits = parseCommitLog(output)
  assert.deepEqual(commits, [
    {
      hash: HASH,
      shortHash: HASH.slice(0, 9),
      parents: [PARENT_HASH],
      authorName: 'Ada Lovelace',
      authoredAt: '2026-07-20T10:30:00+08:00',
      references: [
        { kind: 'head', name: 'main' },
        { kind: 'remoteBranch', name: 'origin/main' },
        { kind: 'tag', name: 'v1.0.0' },
      ],
      subject: 'Add commit browser',
    },
    {
      hash: ROOT_HASH,
      shortHash: ROOT_HASH.slice(0, 9),
      parents: [],
      authorName: '',
      authoredAt: '2026-07-19T09:00:00Z',
      references: [],
      subject: '',
    },
  ])
  assert.ok(Object.isFrozen(commits))
  assert.ok(Object.isFrozen(commits[0]?.parents))
})

test('rejects malformed commit records', () => {
  assert.throws(
    () =>
      parseCommitLog(
        createRecord([
          'not-a-hash',
          'abc1234',
          '',
          'Author',
          '2026-07-20T10:30:00Z',
          '',
          'Subject',
        ]),
      ),
    /invalid commit hash/,
  )
  assert.throws(
    () =>
      parseCommitLog(
        createRecord([HASH, HASH.slice(0, 9), '', 'Author', 'not-a-date', '', 'Subject']),
      ),
    /invalid author date/,
  )
  assert.throws(
    () => parseCommitLog(Buffer.from([HASH, HASH.slice(0, 9)].join('\0'))),
    /incomplete commit record/,
  )
})

function createRecord(fields: ReadonlyArray<string>): Buffer {
  return Buffer.from(`${fields.join('\0')}\0\0`)
}
