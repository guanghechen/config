import assert from 'node:assert/strict'
import test from 'node:test'
import { formatReferenceLabel } from '../src/compare/reference-label'

test('formats resolved commits and long symbolic references', () => {
  assert.equal(formatReferenceLabel('a'.repeat(40)), 'a'.repeat(9))
  assert.equal(formatReferenceLabel('feature/short'), 'feature/short')
  assert.equal(
    formatReferenceLabel('feature/a-reference-name-that-is-too-long'),
    'feature/a-reference-n…',
  )
})
