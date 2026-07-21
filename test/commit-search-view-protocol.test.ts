import assert from 'node:assert/strict'
import test from 'node:test'
import { parseCommitSearchViewMessage } from '../src/view/history/search-view-protocol'

test('parses and normalizes sidebar commit search messages', () => {
  assert.deepEqual(
    parseCommitSearchViewMessage({
      type: 'search',
      query: {
        scope: { kind: 'revision', revision: ' main..feature ' },
        path: 'src/auth',
        author: 'Alice',
        since: ' 2 weeks ago ',
        until: '',
        message: 'fix.*auth',
        content: { mode: 'regex', value: 'throw\\s+new' },
      },
    }),
    {
      type: 'search',
      query: {
        scope: { kind: 'revision', revision: 'main..feature' },
        path: 'src/auth',
        author: 'Alice',
        since: '2 weeks ago',
        until: null,
        message: 'fix.*auth',
        content: { mode: 'regex', value: 'throw\\s+new' },
      },
    },
  )
  assert.deepEqual(parseCommitSearchViewMessage({ type: 'ready' }), { type: 'ready' })
  assert.deepEqual(parseCommitSearchViewMessage({ type: 'cancel' }), { type: 'cancel' })
  assert.deepEqual(parseCommitSearchViewMessage({ type: 'clear' }), { type: 'clear' })
})

test('rejects malformed sidebar commit search messages at the extension boundary', () => {
  assert.throws(() => parseCommitSearchViewMessage(null), /Search message is invalid/)
  assert.throws(() => parseCommitSearchViewMessage({ type: 'unknown' }), /type is invalid/)
  assert.throws(
    () =>
      parseCommitSearchViewMessage({
        type: 'search',
        query: { scope: { kind: 'revision', revision: '--all' } },
      }),
    /must not start/,
  )
  assert.throws(
    () =>
      parseCommitSearchViewMessage({
        type: 'search',
        query: { scope: { kind: 'head' }, content: { mode: 'glob', value: '*' } },
      }),
    /mode is invalid/,
  )
})
