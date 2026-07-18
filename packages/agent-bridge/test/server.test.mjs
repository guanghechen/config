import assert from 'node:assert/strict'
import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import WebSocket from 'ws'
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

  const first = await authenticate(url, {
    type: 'auth',
    role: 'extension',
    pairingCode: 'pairing-code-123',
  })
  assert.equal(first.response.type, 'auth.ok')
  assert.equal(typeof first.response.sessionToken, 'string')
  assert.equal(broker.getPairingCode(), null)

  await assert.rejects(
    authenticate(url, {
      type: 'auth',
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
    role: 'extension',
    sessionToken: first.response.sessionToken,
  })
  assert.equal(broker.getPairingCode(), null)
  resumed.socket.send(JSON.stringify({ type: 'ping' }))
  assert.deepEqual(await readMessage(resumed.socket), { type: 'pong' })

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
      role: 'extension',
      sessionToken: first.response.sessionToken,
    }),
    /Authentication failed/,
  )

  const repaired = await authenticate(url, {
    type: 'auth',
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

function wait(timeoutMs) {
  return new Promise(resolve => setTimeout(resolve, timeoutMs))
}
