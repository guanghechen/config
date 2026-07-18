import assert from 'node:assert/strict'
import test from 'node:test'
import {
  AGENT_PROTOCOL_MISMATCH_CLOSE_CODE as brokerMismatchCloseCode,
  AGENT_PROTOCOL_VERSION as brokerProtocolVersion,
} from '../packages/agent-bridge/src/protocol.mjs'
import { sanitizePageTitle, sanitizePageUrl } from '../src/agent/background/page-url.ts'
import { isSafeDomSelector } from '../src/agent/content/selector.ts'
import {
  AGENT_PROTOCOL_MISMATCH_CLOSE_CODE as extensionMismatchCloseCode,
  AGENT_PROTOCOL_VERSION as extensionProtocolVersion,
} from '../src/agent/contract/index.ts'

test('Extension and broker protocol constants remain aligned', () => {
  assert.equal(extensionProtocolVersion, brokerProtocolVersion)
  assert.equal(extensionMismatchCloseCode, brokerMismatchCloseCode)
})

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
