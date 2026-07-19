import assert from 'node:assert/strict'
import test from 'node:test'
import { updateAgentSessionGrant } from '../src/agent/background/session.ts'

const EMPTY_SESSION = { grants: [], memoryGrants: [], actionGrants: [] }

test('dependent grants require read access and are revoked with it', () => {
  const origin = 'https://example.com'
  let session = updateAgentSessionGrant(EMPTY_SESSION, origin, 'read', true)
  session = updateAgentSessionGrant(session, origin, 'memory', true)
  session = updateAgentSessionGrant(session, origin, 'actions', true)
  assert.deepEqual(session, {
    grants: [origin],
    memoryGrants: [origin],
    actionGrants: [origin],
  })

  session = updateAgentSessionGrant(session, origin, 'read', false)
  assert.deepEqual(session, EMPTY_SESSION)
})

test('memory and action grants cannot be enabled without read access', () => {
  assert.throws(
    () => updateAgentSessionGrant(EMPTY_SESSION, 'https://example.com', 'memory', true),
    /Read access must be enabled first/,
  )
  assert.throws(
    () => updateAgentSessionGrant(EMPTY_SESSION, 'https://example.com', 'actions', true),
    /Read access must be enabled first/,
  )
})
