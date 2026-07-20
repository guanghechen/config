import assert from 'node:assert/strict'
import test from 'node:test'
import { formatCommitSubject } from '../src/view/history/subject'

test('formats known gitmoji aliases for display', () => {
  assert.equal(formatCommitSubject(':sparkles: add commit browser'), '✨ add commit browser')
  assert.equal(
    formatCommitSubject(':building_construction: refactor extension'),
    '🏗️ refactor extension',
  )
})

test('formats multiple aliases and preserves unknown aliases', () => {
  assert.equal(formatCommitSubject(':memo: docs :white_check_mark:'), '📝 docs ✅')
  assert.equal(formatCommitSubject(':custom: keep me'), ':custom: keep me')
})

test('preserves ordinary and empty subjects', () => {
  assert.equal(formatCommitSubject('fix file icons'), 'fix file icons')
  assert.equal(formatCommitSubject(''), '')
})
