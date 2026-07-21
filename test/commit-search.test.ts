import assert from 'node:assert/strict'
import test from 'node:test'
import {
  createCommitSearchArguments,
  createCommitSearchQuery,
  isDefaultCommitSearchQuery,
} from '../src/git/commit-search'
import { formatCommitSearchQuery } from '../src/view/history/search-presentation'

const HEAD_COMMIT = 'a'.repeat(40)

test('normalizes structured commit search filters and maps them to safe Git arguments', () => {
  const query = createCommitSearchQuery({
    scope: { kind: 'revision', revision: ' main..feature ' },
    path: 'src/auth',
    author: 'Alice',
    since: ' 2026-01-01 ',
    until: ' 2026-07-01 ',
    message: 'fix.*auth',
    content: { mode: 'regex', value: 'throw\\s+new' },
  })

  assert.deepEqual(query, {
    scope: { kind: 'revision', revision: 'main..feature' },
    path: 'src/auth',
    author: 'Alice',
    since: '2026-01-01',
    until: '2026-07-01',
    message: 'fix.*auth',
    content: { mode: 'regex', value: 'throw\\s+new' },
  })
  assert.deepEqual(createCommitSearchArguments(query, HEAD_COMMIT), {
    options: [
      '--find-renames',
      '--author=Alice',
      '--since=2026-01-01',
      '--until=2026-07-01',
      '--grep=fix.*auth',
      '-Gthrow\\s+new',
    ],
    revisions: ['--end-of-options', 'main..feature'],
    pathspecs: ['src/auth'],
  })
  assert.equal(
    formatCommitSearchQuery(query),
    'main..feature · path src/auth · author Alice · since 2026-01-01 · until 2026-07-01 · message fix.*auth · regex throw\\s+new',
  )
})

test('preserves significant whitespace in pathspecs and regex filters', () => {
  const query = createCommitSearchQuery({
    path: ' leading and trailing ',
    author: ' Alice ',
    message: ' fix ',
  })

  assert.equal(query.path, ' leading and trailing ')
  assert.equal(query.author, ' Alice ')
  assert.equal(query.message, ' fix ')
  const searchArguments = createCommitSearchArguments(query, HEAD_COMMIT)
  assert.deepEqual(searchArguments.options, ['--find-renames', '--author= Alice ', '--grep= fix '])
  assert.deepEqual(searchArguments.pathspecs, [' leading and trailing '])
})

test('supports HEAD and all-ref text searches without accepting option-like revisions', () => {
  const headQuery = createCommitSearchQuery({ content: { mode: 'text', value: '--token' } })
  assert.deepEqual(createCommitSearchArguments(headQuery, HEAD_COMMIT), {
    options: ['--find-renames', '-S--token'],
    revisions: [HEAD_COMMIT],
    pathspecs: [],
  })

  const allQuery = createCommitSearchQuery({ scope: { kind: 'all' }, path: '--all' })
  assert.deepEqual(createCommitSearchArguments(allQuery, HEAD_COMMIT), {
    options: ['--find-renames'],
    revisions: ['--all'],
    pathspecs: ['--all'],
  })
  assert.throws(
    () => createCommitSearchQuery({ scope: { kind: 'revision', revision: '--all' } }),
    /must not start/,
  )
  assert.throws(() => createCommitSearchQuery({ author: 'bad\0author' }), /Author is invalid/)
})

test('distinguishes the default HEAD view from an applied search', () => {
  assert.equal(isDefaultCommitSearchQuery(createCommitSearchQuery()), true)
  assert.equal(isDefaultCommitSearchQuery(createCommitSearchQuery({ message: 'fix' })), false)
  assert.equal(
    isDefaultCommitSearchQuery(createCommitSearchQuery({ scope: { kind: 'all' } })),
    false,
  )
})
