import {
  AGENT_PROTOCOL_VERSION,
  isAgentCapability,
  type IAgentBrokerRequest,
  type IAgentBrokerResponse,
  type IAgentControlStatus,
  type IAgentError,
} from '@/agent/contract'
import { PageRegistry, type PageRegistryEvent } from './page-registry'
import {
  clearAgentSession,
  readAgentSession,
  writeAgentSession,
  type IAgentSessionState,
} from './session'

const BROKER_URL = `ws://127.0.0.1:${__AGENT_BRIDGE_PORT__}`
const MAX_REQUEST_BYTES = 64 * 1024
const MIN_TIMEOUT_MS = 100
const MAX_TIMEOUT_MS = 10_000
const HEARTBEAT_INTERVAL_MS = 20_000
const PAIR_TIMEOUT_MS = 6_000
const RECONNECT_MAX_MS = 5_000
const REVOKE_TIMEOUT_MS = 1_000

interface IPairingAttempt {
  authenticated: boolean
  readonly resolve: () => void
  readonly reject: (cause: Error) => void
  readonly timeoutId: ReturnType<typeof setTimeout>
}

interface IRevocationAttempt {
  readonly resolve: () => void
  readonly timeoutId: ReturnType<typeof setTimeout>
}

export class AgentBridge {
  private connected = false
  private disposed = false
  private heartbeatTimer: ReturnType<typeof setInterval> | null = null
  private pairingAttempt: IPairingAttempt | null = null
  private pairingCode: string | null = null
  private reconnectDelayMs = 250
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null
  private revocationAttempt: IRevocationAttempt | null = null
  private sequence = 0
  private session: IAgentSessionState = { grants: [] }
  private socket: WebSocket | null = null
  private unsubscribeRegistry: (() => void) | null = null

  public constructor(private readonly registry: PageRegistry) {}

  public async start(): Promise<() => void> {
    this.session = await readAgentSession()
    this.unsubscribeRegistry = this.registry.subscribe(event => this.handleRegistryEvent(event))
    if (this.session.sessionToken) this.connect()

    return () => {
      this.disposed = true
      this.unsubscribeRegistry?.()
      this.stopHeartbeat()
      if (this.reconnectTimer) clearTimeout(this.reconnectTimer)
      this.failPairing(new Error('Agent bridge stopped.'))
      this.completeRevocation()
      this.socket?.close()
      this.socket = null
      this.connected = false
    }
  }

  public getStatus(): IAgentControlStatus {
    return {
      paired: Boolean(this.session.sessionToken),
      connected: this.connected,
      grants: this.session.grants,
    }
  }

  public async pair(pairingCode: string): Promise<IAgentControlStatus> {
    const code = pairingCode.trim()
    if (code.length < 8 || code.length > 128) throw new Error('Pairing code is invalid.')
    if (this.session.sessionToken) throw new Error('Agent bridge is already paired.')
    if (this.pairingAttempt) throw new Error('Agent bridge pairing is already in progress.')

    this.pairingCode = code
    this.reconnectDelayMs = 250
    await new Promise<void>((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        this.failPairing(new Error('Pairing timed out.'))
        this.socket?.close()
      }, PAIR_TIMEOUT_MS)
      this.pairingAttempt = { authenticated: false, resolve, reject, timeoutId }
      this.connect(true)
    })
    return this.getStatus()
  }

  public async unpair(): Promise<IAgentControlStatus> {
    const sessionToken = this.session.sessionToken
    const previousSession = this.session

    this.failPairing(new Error('Pairing was cancelled.'))
    this.stopHeartbeat()
    this.connected = false
    this.session = { grants: [] }
    this.registry.revokeOrigins(new Set(previousSession.grants))
    try {
      await clearAgentSession()
    } catch (cause) {
      this.session = previousSession
      this.connected = this.socket?.readyState === WebSocket.OPEN
      if (this.connected) {
        this.startHeartbeat()
        this.sendRegistryReset()
      }
      throw cause
    }

    if (sessionToken) await this.revokeSession(sessionToken)
    this.socket?.close()
    this.socket = null
    return this.getStatus()
  }

  public async setGrant(origin: string, allowed: boolean): Promise<IAgentControlStatus> {
    if (!this.session.sessionToken) throw new Error('Agent bridge is not paired.')
    const normalizedOrigin = normalizeOrigin(origin)
    if (!normalizedOrigin || !this.registry.hasOrigin(normalizedOrigin)) {
      throw new Error('Origin is not managed by Tsuki.')
    }

    const grants = new Set(this.session.grants)
    if (allowed) grants.add(normalizedOrigin)
    else grants.delete(normalizedOrigin)
    const previousSession = this.session
    const nextSession = { ...this.session, grants: [...grants].sort() }
    if (allowed) {
      await writeAgentSession(nextSession)
      this.session = nextSession
    } else {
      this.session = nextSession
      this.registry.revokeOrigins(new Set([normalizedOrigin]))
      try {
        await writeAgentSession(nextSession)
      } catch (cause) {
        this.session = previousSession
        throw cause
      }
    }
    this.sendRegistryReset()
    return this.getStatus()
  }

  private connect(force = false): void {
    if (
      this.disposed ||
      (!force && this.socket) ||
      (!this.pairingCode && !this.session.sessionToken)
    ) {
      return
    }

    this.stopHeartbeat()
    this.socket?.close()
    let socket: WebSocket
    try {
      socket = new WebSocket(BROKER_URL)
    } catch (cause) {
      this.failPairing(
        cause instanceof Error ? cause : new Error('Could not connect to the agent broker.'),
      )
      this.scheduleReconnect()
      return
    }
    this.socket = socket

    socket.addEventListener('open', () => {
      if (this.socket !== socket) return
      socket.send(
        JSON.stringify({
          type: 'auth',
          role: 'extension',
          pairingCode: this.pairingCode ?? undefined,
          sessionToken: this.session.sessionToken,
        }),
      )
    })
    socket.addEventListener('message', event => {
      if (this.socket !== socket || typeof event.data !== 'string') return
      void this.handleBrokerMessage(event.data).catch(cause => {
        this.failPairing(
          cause instanceof Error ? cause : new Error('Agent broker message handling failed.'),
        )
        socket.close()
      })
    })
    socket.addEventListener('close', event => {
      if (this.socket !== socket) return
      this.stopHeartbeat()
      this.socket = null
      this.connected = false
      if (this.pairingAttempt && !this.pairingAttempt.authenticated) {
        const message =
          event.code === 4003
            ? 'Pairing code was rejected.'
            : 'Could not connect to the agent broker.'
        this.failPairing(new Error(message))
      } else if (this.pairingAttempt?.authenticated) {
        return
      } else if (event.code === 4003 && this.session.sessionToken) {
        void this.expireSession()
        return
      }
      this.completeRevocation()
      this.scheduleReconnect()
    })
    socket.addEventListener('error', () => socket.close())
  }

  private scheduleReconnect(): void {
    if (this.disposed || this.reconnectTimer || !this.session.sessionToken) {
      return
    }
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null
      this.connect()
    }, this.reconnectDelayMs)
    this.reconnectDelayMs = Math.min(this.reconnectDelayMs * 2, RECONNECT_MAX_MS)
  }

  private async handleBrokerMessage(raw: string): Promise<void> {
    let message: unknown
    try {
      message = JSON.parse(raw)
    } catch {
      return
    }
    if (!message || typeof message !== 'object') return
    const value = message as Record<string, unknown>

    if (value.type === 'auth.ok' && typeof value.sessionToken === 'string') {
      const sessionToken = value.sessionToken
      if (!sessionToken) throw new Error('Agent broker returned an invalid session token.')

      const isNewSession = sessionToken !== this.session.sessionToken
      if (isNewSession && !this.pairingAttempt) {
        this.send({ type: 'auth.revoke', sessionToken })
        throw new Error('Agent broker unexpectedly replaced the session token.')
      }
      if (this.pairingAttempt) {
        this.pairingAttempt.authenticated = true
        clearTimeout(this.pairingAttempt.timeoutId)
      }

      const nextSession = { sessionToken, grants: this.session.grants }
      if (isNewSession) {
        try {
          await writeAgentSession(nextSession)
        } catch {
          this.send({ type: 'auth.revoke', sessionToken })
          throw new Error('Could not persist the agent session.')
        }
      }
      this.session = nextSession
      this.pairingCode = null
      this.connected = this.socket?.readyState === WebSocket.OPEN
      this.reconnectDelayMs = 250
      this.completePairing()
      if (this.connected) {
        this.startHeartbeat()
        this.sendRegistryReset()
      } else {
        this.scheduleReconnect()
      }
      return
    }
    if (value.type === 'auth.revoked') {
      this.completeRevocation()
      return
    }
    if (value.type === 'broker.request') {
      let response: IAgentBrokerResponse
      try {
        response = await this.executeRequest(value.request)
      } catch (cause) {
        response = brokerError(
          readRequestId(value.request),
          'INTERNAL_ERROR',
          cause instanceof Error ? cause.message : 'Broker request failed.',
        )
      }
      this.send({ type: 'broker.response', response })
      return
    }
    if (value.type === 'ping') this.send({ type: 'pong' })
  }

  private async executeRequest(value: unknown): Promise<IAgentBrokerResponse> {
    if (!isBrokerRequest(value) || encodedSize(value) > MAX_REQUEST_BYTES) {
      return brokerError(readRequestId(value), 'INVALID_REQUEST', 'Broker request is invalid.')
    }

    const request = value
    const timeoutMs = Math.min(Math.max(request.timeoutMs, MIN_TIMEOUT_MS), MAX_TIMEOUT_MS)
    const grants = new Set(this.session.grants)

    if (request.capability === 'pages.list') {
      return brokerSuccess(request.requestId, { pages: this.registry.list(grants) })
    }
    if (request.capability === 'pages.resolveActive') {
      return brokerSuccess(request.requestId, { page: await this.registry.resolveActive(grants) })
    }
    if (!request.target) {
      return brokerError(request.requestId, 'INVALID_REQUEST', 'A page target is required.')
    }

    const page = this.registry.get(request.target.pageId, grants)
    if (!page) {
      if (this.registry.isStale(request.target.pageId) || request.target.expectedDocumentId) {
        return brokerError(request.requestId, 'PAGE_STALE', 'Page document has changed.')
      }
      return this.registry.hasPage(request.target.pageId)
        ? brokerError(request.requestId, 'PERMISSION_DENIED', 'Page is not granted.')
        : brokerError(request.requestId, 'PAGE_NOT_FOUND', 'Page is not registered.')
    }

    if (request.capability === 'page.describe') {
      return brokerSuccess(request.requestId, { page })
    }
    if (!isAgentCapability(request.capability)) {
      return brokerError(request.requestId, 'CAPABILITY_UNAVAILABLE', 'Capability is unavailable.')
    }

    const response = await this.registry.execute(
      page.pageId,
      request.target.expectedDocumentId,
      request.capability,
      request.payload ?? {},
      timeoutMs,
    )
    return response.ok
      ? brokerSuccess(request.requestId, {
          pageId: page.pageId,
          documentId: page.documentId,
          pageRevision: page.revision,
          result: response.data,
        })
      : brokerError(
          request.requestId,
          response.error?.code ?? 'INTERNAL_ERROR',
          response.error?.message ?? 'Page request failed.',
        )
  }

  private completePairing(): void {
    const attempt = this.pairingAttempt
    if (!attempt) return
    clearTimeout(attempt.timeoutId)
    this.pairingAttempt = null
    this.pairingCode = null
    attempt.resolve()
  }

  private failPairing(cause: Error): void {
    const attempt = this.pairingAttempt
    this.pairingCode = null
    if (!attempt) return
    clearTimeout(attempt.timeoutId)
    this.pairingAttempt = null
    attempt.reject(cause)
  }

  private async revokeSession(sessionToken: string): Promise<void> {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) return

    await new Promise<void>(resolve => {
      this.completeRevocation()
      const timeoutId = setTimeout(() => {
        this.revocationAttempt = null
        resolve()
      }, REVOKE_TIMEOUT_MS)
      this.revocationAttempt = { resolve, timeoutId }
      this.send({ type: 'auth.revoke', sessionToken })
    })
  }

  private async expireSession(): Promise<void> {
    const grants = new Set(this.session.grants)
    this.stopHeartbeat()
    this.connected = false
    this.session = { grants: [] }
    this.registry.revokeOrigins(grants)
    try {
      await clearAgentSession()
    } catch {
      // The rejected token is intentionally not retried in this worker lifetime.
    }
  }

  private completeRevocation(): void {
    const attempt = this.revocationAttempt
    if (!attempt) return
    clearTimeout(attempt.timeoutId)
    this.revocationAttempt = null
    attempt.resolve()
  }

  private startHeartbeat(): void {
    this.stopHeartbeat()
    this.heartbeatTimer = setInterval(() => this.send({ type: 'ping' }), HEARTBEAT_INTERVAL_MS)
  }

  private stopHeartbeat(): void {
    if (!this.heartbeatTimer) return
    clearInterval(this.heartbeatTimer)
    this.heartbeatTimer = null
  }

  private handleRegistryEvent(event: PageRegistryEvent): void {
    if (!this.connected || !this.session.grants.includes(event.page.origin)) return
    this.send({ type: 'broker.event', sequence: ++this.sequence, event })
  }

  private sendRegistryReset(): void {
    if (!this.connected) return
    const grants = new Set(this.session.grants)
    this.send({
      type: 'broker.event',
      sequence: ++this.sequence,
      event: { type: 'registry.reset', pages: this.registry.list(grants) },
    })
  }

  private send(message: unknown): void {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) return
    this.socket.send(JSON.stringify(message))
  }
}

function isBrokerRequest(value: unknown): value is IAgentBrokerRequest {
  if (!value || typeof value !== 'object') return false
  const request = value as Partial<IAgentBrokerRequest>
  return (
    request.version === AGENT_PROTOCOL_VERSION &&
    isBoundedString(request.requestId, 128) &&
    isBoundedString(request.capability, 128) &&
    typeof request.timeoutMs === 'number' &&
    Number.isFinite(request.timeoutMs) &&
    isPageTarget(request.target)
  )
}

function isPageTarget(value: IAgentBrokerRequest['target'] | undefined): boolean {
  if (value === undefined) return true
  if (!value || typeof value !== 'object') return false
  return (
    isBoundedString(value.pageId, 128) &&
    (value.expectedDocumentId === undefined || isBoundedString(value.expectedDocumentId, 256))
  )
}

function isBoundedString(value: unknown, maxLength: number): value is string {
  return typeof value === 'string' && value.length > 0 && value.length <= maxLength
}

function brokerSuccess(requestId: string, data: unknown): IAgentBrokerResponse {
  return { version: 1, requestId, ok: true, data }
}

function brokerError(
  requestId: string,
  code: IAgentError['code'],
  message: string,
): IAgentBrokerResponse {
  return { version: 1, requestId, ok: false, error: { code, message } }
}

function readRequestId(value: unknown): string {
  if (!value || typeof value !== 'object') return ''
  const requestId = (value as Record<string, unknown>).requestId
  return typeof requestId === 'string' ? requestId : ''
}

function normalizeOrigin(value: string): string | null {
  try {
    const url = new URL(value)
    return (url.protocol === 'http:' || url.protocol === 'https:') && url.origin === value
      ? value
      : null
  } catch {
    return null
  }
}

function encodedSize(value: unknown): number {
  try {
    return new TextEncoder().encode(JSON.stringify(value)).byteLength
  } catch {
    return Number.POSITIVE_INFINITY
  }
}
