import assert from 'node:assert/strict'
import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import WebSocket from 'ws'
import { request } from '../src/client.mjs'
import { AGENT_PROTOCOL_MISMATCH_CLOSE_CODE, AGENT_PROTOCOL_VERSION } from '../src/protocol.mjs'
import { serve } from '../src/server.mjs'

test('pairing codes are one-time and sessions can be revoked', async t => {
  const directory = await mkdtemp(join(tmpdir(), 'tsuki-agent-test-'))
  const statePath = join(directory, 'broker.json')
  const broker = await serve({
    port: 0,
    pairingCode: 'pairing-code-123',
    recoveryPairingDelayMs: 10,
    statePath,
  })
  const url = `ws://127.0.0.1:${broker.port}`

  t.after(async () => {
    await broker.shutdown()
    await rm(directory, { recursive: true, force: true })
  })

  await assert.rejects(connect(url, { origin: 'https://example.com' }))

  const incompatible = await connect(url)
  const incompatibleClose = readClose(incompatible)
  incompatible.send(JSON.stringify({ type: 'auth', protocolVersion: 999, role: 'extension' }))
  assert.deepEqual(await readMessage(incompatible), {
    type: 'auth.error',
    code: 'PROTOCOL_MISMATCH',
    message: `Agent protocol v${AGENT_PROTOCOL_VERSION} is required.`,
    protocolVersion: AGENT_PROTOCOL_VERSION,
  })
  assert.equal((await incompatibleClose).code, AGENT_PROTOCOL_MISMATCH_CLOSE_CODE)

  const first = await authenticate(url, {
    type: 'auth',
    protocolVersion: AGENT_PROTOCOL_VERSION,
    role: 'extension',
    pairingCode: 'pairing-code-123',
  })
  assert.equal(first.response.type, 'auth.ok')
  assert.equal(typeof first.response.sessionToken, 'string')
  assert.equal(broker.getPairingCode(), null)

  await assert.rejects(
    authenticate(url, {
      type: 'auth',
      protocolVersion: AGENT_PROTOCOL_VERSION,
      role: 'extension',
      pairingCode: 'pairing-code-123',
    }),
    /Authentication failed/,
  )

  first.socket.close()
  await wait(20)
  assert.equal(typeof broker.getPairingCode(), 'string')

  const resumed = await authenticate(url, {
    type: 'auth',
    protocolVersion: AGENT_PROTOCOL_VERSION,
    role: 'extension',
    sessionToken: first.response.sessionToken,
  })
  assert.equal(broker.getPairingCode(), null)
  resumed.socket.send(JSON.stringify({ type: 'ping' }))
  assert.deepEqual(await readMessage(resumed.socket), { type: 'pong' })

  const agentRequest = request('pages.list', { statePath, timeoutMs: 1_000 })
  const forwarded = await readMessage(resumed.socket)
  assert.equal(forwarded.type, 'broker.request')
  assert.equal(forwarded.request.version, AGENT_PROTOCOL_VERSION)
  assert.equal(forwarded.request.capability, 'pages.list')
  resumed.socket.send(
    JSON.stringify({
      type: 'broker.response',
      response: {
        version: AGENT_PROTOCOL_VERSION,
        requestId: forwarded.request.requestId,
        ok: true,
        data: { pages: [] },
      },
    }),
  )
  assert.deepEqual(await agentRequest, {
    version: AGENT_PROTOCOL_VERSION,
    requestId: forwarded.request.requestId,
    ok: true,
    data: { pages: [] },
  })

  resumed.socket.send(
    JSON.stringify({ type: 'auth.revoke', sessionToken: first.response.sessionToken }),
  )
  assert.deepEqual(await readMessage(resumed.socket), { type: 'auth.revoked' })
  const nextPairingCode = broker.getPairingCode()
  assert.equal(typeof nextPairingCode, 'string')
  assert.notEqual(nextPairingCode, 'pairing-code-123')

  await assert.rejects(
    authenticate(url, {
      type: 'auth',
      protocolVersion: AGENT_PROTOCOL_VERSION,
      role: 'extension',
      sessionToken: first.response.sessionToken,
    }),
    /Authentication failed/,
  )

  const repaired = await authenticate(url, {
    type: 'auth',
    protocolVersion: AGENT_PROTOCOL_VERSION,
    role: 'extension',
    pairingCode: nextPairingCode,
  })
  assert.equal(repaired.response.type, 'auth.ok')
  repaired.socket.close()
})

async function authenticate(url, message) {
  const socket = await connect(url)
  socket.send(JSON.stringify(message))
  try {
    return { socket, response: await readMessage(socket) }
  } catch (cause) {
    socket.close()
    throw cause
  }
}

function connect(url, options) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(url, options)
    socket.once('open', () => resolve(socket))
    socket.once('error', reject)
  })
}

function readMessage(socket) {
  return new Promise((resolve, reject) => {
    const handleMessage = raw => {
      cleanup()
      try {
        resolve(JSON.parse(raw.toString()))
      } catch (cause) {
        reject(cause)
      }
    }
    const handleClose = (_code, reason) => {
      cleanup()
      reject(new Error(reason.toString() || 'Connection closed.'))
    }
    const handleError = error => {
      cleanup()
      reject(error)
    }
    const cleanup = () => {
      socket.off('message', handleMessage)
      socket.off('close', handleClose)
      socket.off('error', handleError)
    }

    socket.once('message', handleMessage)
    socket.once('close', handleClose)
    socket.once('error', handleError)
  })
}

function readClose(socket) {
  return new Promise((resolve, reject) => {
    socket.once('close', (code, reason) => resolve({ code, reason: reason.toString() }))
    socket.once('error', reject)
  })
}

function wait(timeoutMs) {
  return new Promise(resolve => setTimeout(resolve, timeoutMs))
}
