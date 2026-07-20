import assert from 'node:assert/strict'
import test from 'node:test'
import { formatRevisionLabel } from '../src/comparison/reference-label'

test('formats resolved commits and long symbolic references', () => {
  assert.equal(formatRevisionLabel('a'.repeat(40)), 'a'.repeat(9))
  assert.equal(formatRevisionLabel('feature/short'), 'feature/short')
  assert.equal(
    formatRevisionLabel('feature/a-reference-name-that-is-too-long'),
    'feature/a-reference-n…',
  )
})
