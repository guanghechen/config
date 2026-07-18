import { randomBytes } from 'node:crypto'
import { WebSocket, WebSocketServer } from 'ws'
import { AGENT_PROTOCOL_MISMATCH_CLOSE_CODE, AGENT_PROTOCOL_VERSION } from './protocol.mjs'
import { removeState, writeState } from './state.mjs'

const AUTH_TIMEOUT_MS = 5_000
const MAX_PENDING_REQUESTS = 128
const RECOVERY_PAIRING_DELAY_MS = 5_000
const REQUEST_TIMEOUT_MS = 12_000

export async function serve({
  port = 7072,
  pairingCode,
  recoveryPairingDelayMs = RECOVERY_PAIRING_DELAY_MS,
  statePath,
} = {}) {
  if (!Number.isInteger(port) || port < 0 || port > 65_535) {
    throw new Error('Broker port must be an integer between 0 and 65535.')
  }
  if (
    !Number.isInteger(recoveryPairingDelayMs) ||
    recoveryPairingDelayMs < 1 ||
    recoveryPairingDelayMs > 60_000
  ) {
    throw new Error('Recovery pairing delay must be an integer between 1 and 60000.')
  }
  const host = '127.0.0.1'
  let activePairingCode = pairingCode || randomBytes(12).toString('base64url')
  const clientToken = randomBytes(32).toString('base64url')
  let extensionSessionToken = null
  let extensionSocket = null
  let recoveryPairingTimer = null
  let shuttingDown = false
  const agentSockets = new Set()
  const pending = new Map()
  const pages = new Map()

  const server = new WebSocketServer({
    host,
    port,
    maxPayload: 1024 * 1024,
    verifyClient: ({ origin }) => isAllowedOrigin(origin),
  })
  await new Promise((resolve, reject) => {
    const handleError = error => {
      server.off('listening', handleListening)
      reject(error)
    }
    const handleListening = () => {
      server.off('error', handleError)
      resolve()
    }
    server.once('listening', handleListening)
    server.once('error', handleError)
  })

  const listeningPort = readListeningPort(server)
  try {
    await writeState({ port: listeningPort, clientToken, pid: process.pid }, statePath)
  } catch (cause) {
    await new Promise(resolve => server.close(resolve))
    throw cause
  }
  server.on('error', error => {
    process.stderr.write(`Tsuki agent broker error: ${error.message}\n`)
  })
  process.stdout.write(`Tsuki agent broker listening on ws://${host}:${listeningPort}\n`)
  printPairingCode(activePairingCode)

  server.on('connection', socket => {
    let role = null
    socket.on('error', () => undefined)
    const authTimeout = setTimeout(
      () => socket.close(4001, 'Authentication timeout'),
      AUTH_TIMEOUT_MS,
    )

    socket.on('message', raw => {
      const message = parseMessage(raw)
      if (!message) return

      if (!role) {
        if (message?.type === 'auth' && message.protocolVersion !== AGENT_PROTOCOL_VERSION) {
          send(socket, {
            type: 'auth.error',
            code: 'PROTOCOL_MISMATCH',
            message: `Agent protocol v${AGENT_PROTOCOL_VERSION} is required.`,
            protocolVersion: AGENT_PROTOCOL_VERSION,
          })
          socket.close(AGENT_PROTOCOL_MISMATCH_CLOSE_CODE, 'Agent protocol version mismatch')
          return
        }
        const auth = authenticate(message)
        if (!auth) {
          socket.close(4003, 'Authentication failed')
          return
        }
        clearTimeout(authTimeout)
        role = auth.role
        if (role === 'extension') {
          cancelRecoveryPairing()
          if (auth.resumed) activePairingCode = null
          extensionSocket?.close(4000, 'Replaced')
          extensionSocket = socket
          extensionSessionToken = auth.sessionToken
          pages.clear()
          send(socket, {
            type: 'auth.ok',
            protocolVersion: AGENT_PROTOCOL_VERSION,
            sessionToken: extensionSessionToken,
          })
        } else {
          agentSockets.add(socket)
          send(socket, { type: 'auth.ok', protocolVersion: AGENT_PROTOCOL_VERSION })
        }
        return
      }

      if (role === 'extension') handleExtensionMessage(socket, message)
      else handleAgentMessage(socket, message)
    })

    socket.on('close', () => {
      clearTimeout(authTimeout)
      if (socket === extensionSocket) {
        extensionSocket = null
        pages.clear()
        failPendingRequests('PAGE_NOT_FOUND', 'Extension disconnected.')
        broadcastRegistryReset()
        scheduleRecoveryPairing()
      }
      agentSockets.delete(socket)
      for (const [requestId, item] of pending) {
        if (item.agentSocket !== socket) continue
        clearTimeout(item.timeoutId)
        pending.delete(requestId)
      }
    })
  })

  const authenticate = message => {
    if (message?.type !== 'auth') return null
    if (message.role === 'agent' && message.clientToken === clientToken) return { role: 'agent' }
    if (message.role !== 'extension') return null

    if (extensionSessionToken && message.sessionToken === extensionSessionToken) {
      return { role: 'extension', sessionToken: extensionSessionToken, resumed: true }
    }
    if (activePairingCode && message.pairingCode === activePairingCode) {
      activePairingCode = null
      return { role: 'extension', sessionToken: randomBytes(32).toString('base64url') }
    }
    return null
  }

  const handleAgentMessage = (socket, message) => {
    if (message?.type !== 'agent.request' || !message.request?.requestId) return
    if (!extensionSocket || extensionSocket.readyState !== WebSocket.OPEN) {
      send(
        socket,
        errorEnvelope(message.request.requestId, 'PAGE_NOT_FOUND', 'Extension is not connected.'),
      )
      return
    }

    const requestId = message.request.requestId
    if (pending.has(requestId)) {
      send(socket, errorEnvelope(requestId, 'INVALID_REQUEST', 'Duplicate request ID.'))
      return
    }
    if (pending.size >= MAX_PENDING_REQUESTS) {
      send(socket, errorEnvelope(requestId, 'INVALID_REQUEST', 'Broker request limit reached.'))
      return
    }
    const timeoutId = setTimeout(() => {
      pending.delete(requestId)
      send(socket, errorEnvelope(requestId, 'TIMEOUT', 'Broker request timed out.'))
    }, REQUEST_TIMEOUT_MS)
    pending.set(requestId, { agentSocket: socket, timeoutId })
    send(extensionSocket, { type: 'broker.request', request: message.request })
  }

  const handleExtensionMessage = (socket, message) => {
    if (socket !== extensionSocket) return
    if (message?.type === 'auth.revoke' && message.sessionToken === extensionSessionToken) {
      extensionSessionToken = null
      extensionSocket = null
      pages.clear()
      failPendingRequests('PAGE_NOT_FOUND', 'Extension session was revoked.')
      send(socket, { type: 'auth.revoked' })
      broadcastRegistryReset()
      issuePairingCode()
      socket.close(4004, 'Session revoked')
      return
    }
    if (message?.type === 'ping') {
      send(socket, { type: 'pong' })
      return
    }
    if (message?.type === 'broker.response' && message.response?.requestId) {
      const item = pending.get(message.response.requestId)
      if (!item) return
      clearTimeout(item.timeoutId)
      pending.delete(message.response.requestId)
      send(item.agentSocket, message)
      return
    }
    if (message?.type === 'broker.event') {
      updatePageMirror(message.event)
      for (const agentSocket of agentSockets) send(agentSocket, message)
    }
  }

  const updatePageMirror = event => {
    if (!event || typeof event !== 'object') return
    if (event.type === 'registry.reset' && Array.isArray(event.pages)) {
      pages.clear()
      for (const page of event.pages) if (page?.pageId) pages.set(page.pageId, page)
    } else if (
      (event.type === 'page.added' || event.type === 'page.updated') &&
      event.page?.pageId
    ) {
      pages.set(event.page.pageId, event.page)
    } else if (event.type === 'page.removed' && event.page?.pageId) {
      pages.delete(event.page.pageId)
    }
  }

  const broadcastRegistryReset = () => {
    for (const agentSocket of agentSockets) {
      send(agentSocket, {
        type: 'broker.event',
        sequence: 0,
        event: { type: 'registry.reset', pages: [] },
      })
    }
  }

  const failPendingRequests = (code, message) => {
    for (const [requestId, item] of pending) {
      clearTimeout(item.timeoutId)
      send(item.agentSocket, errorEnvelope(requestId, code, message))
    }
    pending.clear()
  }

  const issuePairingCode = () => {
    activePairingCode = randomBytes(12).toString('base64url')
    printPairingCode(activePairingCode)
  }

  const cancelRecoveryPairing = () => {
    if (!recoveryPairingTimer) return
    clearTimeout(recoveryPairingTimer)
    recoveryPairingTimer = null
  }

  const scheduleRecoveryPairing = () => {
    if (shuttingDown || activePairingCode || recoveryPairingTimer) return
    recoveryPairingTimer = setTimeout(() => {
      recoveryPairingTimer = null
      issuePairingCode()
    }, recoveryPairingDelayMs)
  }

  let shutdownPromise = null
  const shutdown = () => {
    shutdownPromise ??= (async () => {
      shuttingDown = true
      process.off('SIGINT', handleSigint)
      process.off('SIGTERM', handleSigterm)
      cancelRecoveryPairing()
      failPendingRequests('PAGE_NOT_FOUND', 'Agent broker stopped.')
      for (const socket of server.clients) socket.terminate()
      await new Promise(resolve => server.close(resolve))
      await removeState(statePath, clientToken)
    })()
    return shutdownPromise
  }
  const handleSigint = () => void shutdown().finally(() => process.exit(0))
  const handleSigterm = () => void shutdown().finally(() => process.exit(0))

  process.once('SIGINT', handleSigint)
  process.once('SIGTERM', handleSigterm)
  return {
    server,
    pairingCode: activePairingCode,
    clientToken,
    getPairingCode: () => activePairingCode,
    port: listeningPort,
    shutdown,
  }
}

function parseMessage(raw) {
  try {
    return JSON.parse(raw.toString())
  } catch {
    return null
  }
}

function send(socket, message) {
  if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message))
}

function errorEnvelope(requestId, code, message) {
  return {
    type: 'broker.response',
    response: { version: 1, requestId, ok: false, error: { code, message } },
  }
}

function isAllowedOrigin(origin) {
  return !origin || origin.startsWith('chrome-extension://')
}

function readListeningPort(server) {
  const address = server.address()
  if (!address || typeof address === 'string') throw new Error('Broker address is unavailable.')
  return address.port
}

function printPairingCode(pairingCode) {
  if (pairingCode) process.stdout.write(`Pairing code: ${pairingCode}\n`)
}
