import assert from 'node:assert/strict'
import test from 'node:test'
import {
  AGENT_PROTOCOL_MISMATCH_CLOSE_CODE as brokerMismatchCloseCode,
  AGENT_PROTOCOL_VERSION as brokerProtocolVersion,
} from '../packages/agent-bridge/src/protocol.mjs'
import { resolvePageMemorySourceUrl } from '../src/agent/background/page-scope.ts'
import { sanitizePageTitle, sanitizePageUrl } from '../src/agent/background/page-url.ts'
import { isWebsiteOriginAllowed } from '../src/agent/background/website-policy.ts'
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

test('page memory URL resolution fails closed during tab and event races', () => {
  const registeredUrl = 'https://codeforces.com/contest/1?view=first#problem-a'
  const registeredOrigin = 'https://codeforces.com'
  assert.equal(
    resolvePageMemorySourceUrl(
      { status: 'complete', url: registeredUrl },
      registeredUrl,
      registeredOrigin,
    ),
    registeredUrl,
  )
  assert.equal(
    resolvePageMemorySourceUrl(
      { status: 'complete', url: `${registeredOrigin}/contest/2` },
      registeredUrl,
      registeredOrigin,
    ),
    null,
  )
  assert.equal(
    resolvePageMemorySourceUrl(
      { status: 'loading', url: registeredUrl },
      registeredUrl,
      registeredOrigin,
    ),
    null,
  )
})

test('website origin policy rejects opaque and unsupported origins', () => {
  const allowedOrigins = [
    ['codeforces', 'https://codeforces.com'],
    ['codeforces', 'https://gym.codeforces.com'],
    ['reddit', 'https://www.reddit.com'],
    ['reddit', 'https://old.reddit.com'],
    ['usaco', 'https://usaco.training'],
    ['yoz', 'http://localhost:7071'],
    ['yoz', 'https://127.0.0.1:7071'],
  ]
  for (const [website, origin] of allowedOrigins) {
    assert.equal(isWebsiteOriginAllowed(website, origin), true, `${website}: ${origin}`)
  }

  assert.equal(isWebsiteOriginAllowed('codeforces', 'https://codeforces.com.evil.example'), false)
  assert.equal(isWebsiteOriginAllowed('reddit', 'https://reddit.com'), false)
  assert.equal(isWebsiteOriginAllowed('codeforces', 'null'), false)
  assert.equal(isWebsiteOriginAllowed('codeforces', 'chrome://settings'), false)
})
