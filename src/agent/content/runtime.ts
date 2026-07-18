import {
  AGENT_PAGE_PORT_NAME,
  AGENT_PROTOCOL_VERSION,
  GENERIC_AGENT_CAPABILITIES,
  type IAgentError,
  type IAgentPageAdapter,
  type IAgentPageRegistered,
  type IAgentPageRequest,
  type IAgentPageResponse,
} from '@/agent/contract'
import { DomCapabilityRuntime } from './dom'

const MAX_TIMEOUT_MS = 10_000
const RECONNECT_MAX_MS = 5_000

export function startAgentPage(adapter: IAgentPageAdapter): () => void {
  if (window.top !== window) return () => undefined

  const capabilities = [...new Set([...GENERIC_AGENT_CAPABILITIES, ...adapter.capabilities])]
  const documentNonce = crypto.randomUUID()
  const domRuntime = new DomCapabilityRuntime()
  let disposed = false
  let port: chrome.runtime.Port | null = null
  let reconnectDelayMs = 250
  let reconnectTimer: number | null = null

  const connect = () => {
    if (disposed) return

    try {
      port = chrome.runtime.connect({ name: AGENT_PAGE_PORT_NAME })
      port.postMessage({
        type: 'page.register',
        protocolVersion: AGENT_PROTOCOL_VERSION,
        website: adapter.website,
        capabilities,
        documentNonce,
      })
      port.onMessage.addListener(handleMessage)
      port.onDisconnect.addListener(handleDisconnect)
    } catch {
      scheduleReconnect()
    }
  }

  const scheduleReconnect = () => {
    if (disposed || reconnectTimer !== null) return
    reconnectTimer = window.setTimeout(() => {
      reconnectTimer = null
      connect()
    }, reconnectDelayMs)
    reconnectDelayMs = Math.min(reconnectDelayMs * 2, RECONNECT_MAX_MS)
  }

  const handleDisconnect = () => {
    port = null
    scheduleReconnect()
  }

  const handleMessage = (message: unknown) => {
    if (isPageRegistered(message)) {
      reconnectDelayMs = 250
      return
    }
    if (!isPageRequest(message)) return
    void executeRequest(message).then(response => port?.postMessage(response))
  }

  const executeRequest = async (request: IAgentPageRequest): Promise<IAgentPageResponse> => {
    const controller = new AbortController()
    const timeoutMs = Math.min(Math.max(request.timeoutMs, 1), MAX_TIMEOUT_MS)
    const timeoutId = window.setTimeout(() => controller.abort(), timeoutMs)

    try {
      if (!capabilities.includes(request.capability)) {
        throw Object.assign(new Error('Capability is unavailable.'), {
          code: 'CAPABILITY_UNAVAILABLE',
        })
      }

      const data = request.capability.startsWith('dom.')
        ? await domRuntime.execute(request.capability, request.payload, controller.signal)
        : await adapter.execute?.(request.capability, request.payload, controller.signal)
      return { type: 'page.response', requestId: request.requestId, ok: true, data }
    } catch (cause) {
      return {
        type: 'page.response',
        requestId: request.requestId,
        ok: false,
        error: normalizeError(cause, controller.signal.aborted),
      }
    } finally {
      window.clearTimeout(timeoutId)
    }
  }

  connect()

  return () => {
    if (disposed) return
    disposed = true
    if (reconnectTimer !== null) window.clearTimeout(reconnectTimer)
    port?.disconnect()
    port = null
  }
}

function isPageRegistered(value: unknown): value is IAgentPageRegistered {
  if (!value || typeof value !== 'object') return false
  const message = value as { pageId?: unknown; type?: unknown }
  return message.type === 'page.registered' && typeof message.pageId === 'string'
}

function isPageRequest(value: unknown): value is IAgentPageRequest {
  if (!value || typeof value !== 'object') return false
  const request = value as Partial<IAgentPageRequest>
  return (
    request.type === 'page.request' &&
    typeof request.requestId === 'string' &&
    request.requestId.length > 0 &&
    request.requestId.length <= 128 &&
    typeof request.capability === 'string' &&
    typeof request.timeoutMs === 'number' &&
    Number.isFinite(request.timeoutMs)
  )
}

function normalizeError(cause: unknown, timedOut: boolean): IAgentError {
  if (timedOut) return { code: 'TIMEOUT', message: 'Page request timed out.' }
  const error = cause as { code?: unknown; message?: unknown }
  const code = typeof error?.code === 'string' ? error.code : 'INTERNAL_ERROR'
  return {
    code: code as IAgentError['code'],
    message: typeof error?.message === 'string' ? error.message : 'Page request failed.',
  }
}
