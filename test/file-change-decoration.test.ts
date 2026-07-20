import assert from 'node:assert/strict'
import test from 'node:test'
import {
  createFileChangeQuery,
  parseFileChangeQuery,
  resolveFileChangeDecoration,
} from '../src/view/file-change-decoration'

test('round-trips file change kinds through resource queries', () => {
  for (const kind of ['added', 'modified', 'deleted', 'renamed', 'unmerged'] as const) {
    assert.equal(parseFileChangeQuery(createFileChangeQuery(kind)), kind)
  }
  assert.equal(parseFileChangeQuery('other=value'), null)
  assert.equal(parseFileChangeQuery('vsgitChange=invalid'), null)
})

test('uses standard Git theme colors and concise status badges', () => {
  assert.deepEqual(resolveFileChangeDecoration('added'), {
    badge: 'A',
    colorId: 'gitDecoration.addedResourceForeground',
    label: 'Added',
  })
  assert.deepEqual(resolveFileChangeDecoration('modified'), {
    badge: 'M',
    colorId: 'gitDecoration.modifiedResourceForeground',
    label: 'Modified',
  })
  assert.deepEqual(resolveFileChangeDecoration('unmerged'), {
    badge: 'U',
    colorId: 'gitDecoration.conflictingResourceForeground',
    label: 'Conflict',
  })
})
