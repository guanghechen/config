import { randomUUID } from 'node:crypto'
import WebSocket from 'ws'
import { readState } from './state.mjs'

export async function request(capability, { target, payload = {}, timeoutMs = 5_000 } = {}) {
  const state = await readState()
  const socket = new WebSocket(`ws://127.0.0.1:${state.port}`, { maxPayload: 1024 * 1024 })
  const requestId = randomUUID()
  const request = {
    version: 1,
    requestId,
    target,
    capability,
    payload,
    timeoutMs,
  }

  return new Promise((resolve, reject) => {
    let completed = false
    const timeout = setTimeout(() => {
      completed = true
      socket.close()
      reject(new Error('Agent request timed out.'))
    }, timeoutMs + 2_000)

    socket.on('open', () => {
      socket.send(JSON.stringify({ type: 'auth', role: 'agent', clientToken: state.clientToken }))
    })
    socket.on('message', raw => {
      const message = parseMessage(raw)
      if (message?.type === 'auth.ok') {
        socket.send(JSON.stringify({ type: 'agent.request', request }))
        return
      }
      if (message?.type !== 'broker.response' || message.response?.requestId !== requestId) return
      completed = true
      clearTimeout(timeout)
      socket.close()
      resolve(message.response)
    })
    socket.on('error', error => {
      if (completed) return
      completed = true
      clearTimeout(timeout)
      socket.close()
      reject(error)
    })
    socket.on('close', (_code, reason) => {
      if (completed) return
      completed = true
      clearTimeout(timeout)
      reject(new Error(reason.toString() || 'Agent broker connection closed.'))
    })
  })
}

function parseMessage(raw) {
  try {
    return JSON.parse(raw.toString())
  } catch {
    return null
  }
}
