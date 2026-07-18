import assert from 'node:assert/strict'
import test from 'node:test'
import { sanitizePageTitle, sanitizePageUrl } from '../src/agent/background/page-url.ts'
import { isSafeDomSelector } from '../src/agent/content/selector.ts'

test('DOM selector policy rejects attribute and state oracles', () => {
  const unsafeSelectors = [
    '*',
    'input[value^="secret"]',
    'a[href*="token"]',
    'input:checked',
    'label:has(input)',
    String.raw`input\[value\]`,
  ]

  for (const selector of unsafeSelectors) assert.equal(isSafeDomSelector(selector), false, selector)
  assert.equal(isSafeDomSelector('main article > a.problem, #sidebar .title'), true)
})

test('page metadata URLs omit query parameters and fragments', () => {
  assert.equal(
    sanitizePageUrl('https://example.com/problem/1?token=secret#private'),
    'https://example.com/problem/1',
  )
  assert.equal(
    sanitizePageTitle(
      'localhost/problem/1?token=secret#private',
      'https://localhost/problem/1?token=secret#private',
    ),
    'localhost/problem/1',
  )
  assert.equal(sanitizePageUrl('not a URL'), '')
})
