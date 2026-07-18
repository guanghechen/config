import {
  AGENT_PAGE_PORT_NAME,
  AGENT_PROTOCOL_VERSION,
  GENERIC_AGENT_CAPABILITIES,
  isAgentCapability,
  type AgentCapability,
  type IAgentError,
  type IAgentPageRecord,
  type IAgentPageRegistered,
  type IAgentPageRegistration,
  type IAgentPageRequest,
  type IAgentPageResponse,
} from '@/agent/contract'
import { sanitizePageTitle, sanitizePageUrl } from './page-url'

const BROWSER_SESSION_KEY = 'tsuki-agent-browser-session-id'
const MAX_QUEUED_REQUESTS_PER_PAGE = 16
const MAX_RESPONSE_BYTES = 512 * 1024

interface IPageEntry {
  accessRevision: number
  record: IAgentPageRecord
  port: chrome.runtime.Port
  pending: Map<string, IPendingRequest>
  queue: Promise<unknown>
  queueDepth: number
}

interface IPendingRequest {
  readonly resolve: (response: IAgentPageResponse) => void
  readonly timeoutId: ReturnType<typeof setTimeout>
}

export type PageRegistryEvent =
  | { readonly type: 'page.added'; readonly page: IAgentPageRecord }
  | { readonly type: 'page.updated'; readonly page: IAgentPageRecord }
  | { readonly type: 'page.removed'; readonly page: IAgentPageRecord }

export class PageRegistry {
  private readonly pages = new Map<string, IPageEntry>()
  private readonly listeners = new Set<(event: PageRegistryEvent) => void>()
  private readonly stalePageIds = new Set<string>()
  private readonly stalePageOrder: string[] = []
  private browserSessionIdPromise: Promise<string> | null = null

  public start(): () => void {
    const handleConnect = (port: chrome.runtime.Port) => {
      if (port.name !== AGENT_PAGE_PORT_NAME) return
      this.handlePort(port)
    }
    const handleActivated = (activeInfo: { readonly tabId: number; readonly windowId: number }) => {
      for (const entry of this.pages.values()) {
        if (entry.record.windowId !== activeInfo.windowId) continue
        const active = entry.record.tabId === activeInfo.tabId
        if (entry.record.active === active) continue
        entry.record = { ...entry.record, active, revision: entry.record.revision + 1 }
        this.emit({ type: 'page.updated', page: entry.record })
      }
    }
    const handleUpdated = (
      tabId: number,
      changeInfo: { readonly title?: string; readonly url?: string },
      tab: chrome.tabs.Tab,
    ) => {
      if (changeInfo.url === undefined && changeInfo.title === undefined) return

      for (const [pageId, entry] of this.pages) {
        if (entry.record.tabId !== tabId) continue

        const nextOrigin = changeInfo.url ? resolveOrigin(changeInfo.url) : entry.record.origin
        if (!isWebsiteOriginAllowed(entry.record.website, nextOrigin)) {
          this.removePage(pageId, entry)
          continue
        }

        const nextUrl = changeInfo.url ? sanitizePageUrl(changeInfo.url) : entry.record.url
        const nextTitle =
          changeInfo.title !== undefined
            ? sanitizePageTitle(
                tab.title ?? changeInfo.title,
                tab.url ?? changeInfo.url ?? entry.record.url,
              )
            : entry.record.title
        if (nextUrl === entry.record.url && nextTitle === entry.record.title) continue

        entry.record = {
          ...entry.record,
          url: nextUrl,
          origin: nextOrigin,
          title: nextTitle,
          revision: entry.record.revision + 1,
        }
        this.emit({ type: 'page.updated', page: entry.record })
      }
    }

    chrome.runtime.onConnect.addListener(handleConnect)
    chrome.tabs.onActivated.addListener(handleActivated)
    chrome.tabs.onUpdated.addListener(handleUpdated)

    return () => {
      chrome.runtime.onConnect.removeListener(handleConnect)
      chrome.tabs.onActivated.removeListener(handleActivated)
      chrome.tabs.onUpdated.removeListener(handleUpdated)
      for (const entry of this.pages.values()) entry.port.disconnect()
      this.pages.clear()
    }
  }

  public subscribe(listener: (event: PageRegistryEvent) => void): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  public isStale(pageId: string): boolean {
    return this.stalePageIds.has(pageId)
  }

  public hasOrigin(origin: string): boolean {
    return [...this.pages.values()].some(entry => entry.record.origin === origin)
  }

  public hasPage(pageId: string): boolean {
    return this.pages.has(pageId)
  }

  public get(pageId: string, grants: ReadonlySet<string>): IAgentPageRecord | null {
    const page = this.pages.get(pageId)?.record ?? null
    return page && grants.has(page.origin) ? page : null
  }

  public list(grants: ReadonlySet<string>): ReadonlyArray<IAgentPageRecord> {
    return [...this.pages.values()]
      .map(entry => entry.record)
      .filter(page => grants.has(page.origin))
      .sort((left, right) => Number(right.active) - Number(left.active) || left.tabId - right.tabId)
  }

  public revokeOrigins(origins: ReadonlySet<string>): void {
    for (const entry of this.pages.values()) {
      if (!origins.has(entry.record.origin)) continue
      entry.accessRevision += 1
      for (const pending of entry.pending.values()) {
        clearTimeout(pending.timeoutId)
        pending.resolve(errorResponse('', 'PERMISSION_DENIED', 'Page access was revoked.'))
      }
      entry.pending.clear()
    }
  }

  public async resolveActive(grants: ReadonlySet<string>): Promise<IAgentPageRecord | null> {
    const focusedWindow = await chrome.windows.getLastFocused()
    return (
      this.list(grants).find(
        page =>
          page.active && (focusedWindow.id === undefined || page.windowId === focusedWindow.id),
      ) ?? null
    )
  }

  public execute(
    pageId: string,
    expectedDocumentId: string | undefined,
    capability: AgentCapability,
    payload: unknown,
    timeoutMs: number,
  ): Promise<IAgentPageResponse> {
    const entry = this.pages.get(pageId)
    if (!entry)
      return Promise.resolve(errorResponse('', 'PAGE_NOT_FOUND', 'Page is not registered.'))
    if (expectedDocumentId && entry.record.documentId !== expectedDocumentId) {
      return Promise.resolve(errorResponse('', 'PAGE_STALE', 'Page document has changed.'))
    }
    if (!entry.record.capabilities.includes(capability)) {
      return Promise.resolve(
        errorResponse('', 'CAPABILITY_UNAVAILABLE', 'Capability is unavailable for this page.'),
      )
    }
    if (entry.queueDepth >= MAX_QUEUED_REQUESTS_PER_PAGE) {
      return Promise.resolve(errorResponse('', 'TIMEOUT', 'Page request queue is full.'))
    }

    const requestId = crypto.randomUUID()
    const expiresAt = Date.now() + timeoutMs
    const accessRevision = entry.accessRevision
    const task = () => {
      if (entry.accessRevision !== accessRevision) {
        return Promise.resolve(
          errorResponse(requestId, 'PERMISSION_DENIED', 'Page access was revoked.'),
        )
      }
      const remainingTimeoutMs = expiresAt - Date.now()
      if (remainingTimeoutMs <= 0) {
        return Promise.resolve(errorResponse(requestId, 'TIMEOUT', 'Page request timed out.'))
      }
      const request: IAgentPageRequest = {
        type: 'page.request',
        requestId,
        capability,
        payload,
        timeoutMs: remainingTimeoutMs,
      }
      return this.send(entry, request)
    }
    entry.queueDepth += 1
    const result = entry.queue.then(task, task)
    entry.queue = result.then(
      () => {
        entry.queueDepth -= 1
      },
      () => {
        entry.queueDepth -= 1
      },
    )
    return result
  }

  private handlePort(port: chrome.runtime.Port): void {
    let disconnected = false
    let pageId: string | null = null

    const handleMessage = (message: unknown) => {
      if (isRegistration(message) && pageId === null) {
        void this.register(port, message)
          .then(id => {
            if (disconnected) {
              const entry = this.pages.get(id)
              if (entry?.port === port) this.removePage(id, entry)
            } else {
              pageId = id
              const response: IAgentPageRegistered = { type: 'page.registered', pageId: id }
              port.postMessage(response)
            }
          })
          .catch(() => port.disconnect())
        return
      }
      if (isPageResponse(message) && pageId) this.resolvePending(pageId, message)
    }
    const handleDisconnect = () => {
      disconnected = true
      if (!pageId) return
      const entry = this.pages.get(pageId)
      if (!entry || entry.port !== port) return
      this.removePage(pageId, entry)
    }

    port.onMessage.addListener(handleMessage)
    port.onDisconnect.addListener(handleDisconnect)
  }

  private async register(
    port: chrome.runtime.Port,
    registration: IAgentPageRegistration,
  ): Promise<string> {
    const sender = port.sender
    const tab = sender?.tab
    if (!sender || tab?.id === undefined || sender.frameId !== 0 || !sender.url) {
      port.disconnect()
      throw new Error('Agent page registration rejected.')
    }

    const senderUrl = sender.url
    const origin = resolveOrigin(senderUrl)
    if (!isWebsiteOriginAllowed(registration.website, origin)) {
      port.disconnect()
      throw new Error('Agent website registration rejected.')
    }

    const frameId = sender.frameId
    const documentId = sender.documentId ?? registration.documentNonce
    const pageId = await this.createPageId(tab.id, frameId, documentId)
    const allowedCapabilities = new Set<AgentCapability>([
      ...GENERIC_AGENT_CAPABILITIES,
      ...(registration.website === 'codeforces'
        ? ([
            'codeforces.listProblems',
            'codeforces.readProblem',
            'codeforces.getContest',
          ] satisfies AgentCapability[])
        : []),
    ])
    const capabilities = registration.capabilities.filter(
      capability => isAgentCapability(capability) && allowedCapabilities.has(capability),
    )
    const record: IAgentPageRecord = {
      pageId,
      tabId: tab.id,
      windowId: tab.windowId,
      frameId,
      documentId,
      url: sanitizePageUrl(senderUrl),
      origin,
      title: sanitizePageTitle(tab.title ?? '', senderUrl),
      active: tab.active,
      website: registration.website.slice(0, 64),
      capabilities: [...new Set(capabilities)],
      revision: 1,
    }

    const existing = this.pages.get(pageId)
    existing?.port.disconnect()
    this.pages.set(pageId, {
      accessRevision: 0,
      record,
      port,
      pending: new Map(),
      queue: Promise.resolve(),
      queueDepth: 0,
    })
    this.emit({ type: 'page.added', page: record })
    return pageId
  }

  private removePage(pageId: string, entry: IPageEntry): void {
    for (const pending of entry.pending.values()) {
      clearTimeout(pending.timeoutId)
      pending.resolve(errorResponse('', 'PAGE_STALE', 'Page connection closed.'))
    }
    entry.pending.clear()
    this.pages.delete(pageId)
    this.rememberStalePage(pageId)
    this.emit({ type: 'page.removed', page: entry.record })
  }

  private rememberStalePage(pageId: string): void {
    if (this.stalePageIds.has(pageId)) return
    this.stalePageIds.add(pageId)
    this.stalePageOrder.push(pageId)
    while (this.stalePageOrder.length > 128) {
      const expiredPageId = this.stalePageOrder.shift()
      if (expiredPageId) this.stalePageIds.delete(expiredPageId)
    }
  }

  private send(entry: IPageEntry, request: IAgentPageRequest): Promise<IAgentPageResponse> {
    return new Promise(resolve => {
      const timeoutId = setTimeout(() => {
        entry.pending.delete(request.requestId)
        resolve(errorResponse(request.requestId, 'TIMEOUT', 'Page request timed out.'))
      }, request.timeoutMs)
      entry.pending.set(request.requestId, { resolve, timeoutId })

      try {
        entry.port.postMessage(request)
      } catch {
        clearTimeout(timeoutId)
        entry.pending.delete(request.requestId)
        resolve(errorResponse(request.requestId, 'PAGE_STALE', 'Page connection is unavailable.'))
      }
    })
  }

  private resolvePending(pageId: string, response: IAgentPageResponse): void {
    const entry = this.pages.get(pageId)
    const pending = entry?.pending.get(response.requestId)
    if (!entry || !pending) return
    entry.pending.delete(response.requestId)
    clearTimeout(pending.timeoutId)

    if (responseSize(response) > MAX_RESPONSE_BYTES) {
      pending.resolve(
        errorResponse(response.requestId, 'PAYLOAD_TOO_LARGE', 'Page response is too large.'),
      )
      return
    }
    pending.resolve(response)
  }

  private async createPageId(tabId: number, frameId: number, documentId: string): Promise<string> {
    const sessionId = await this.getBrowserSessionId()
    const bytes = new TextEncoder().encode(`${sessionId}:${tabId}:${frameId}:${documentId}`)
    const digest = await crypto.subtle.digest('SHA-256', bytes)
    const hash = [...new Uint8Array(digest)]
      .slice(0, 16)
      .map(value => value.toString(16).padStart(2, '0'))
      .join('')
    return `page_${hash}`
  }

  private getBrowserSessionId(): Promise<string> {
    this.browserSessionIdPromise ??= resolveBrowserSessionId()
    return this.browserSessionIdPromise
  }

  private emit(event: PageRegistryEvent): void {
    for (const listener of this.listeners) listener(event)
  }
}

function isRegistration(value: unknown): value is IAgentPageRegistration {
  if (!value || typeof value !== 'object') return false
  const registration = value as Partial<IAgentPageRegistration>
  return (
    registration.type === 'page.register' &&
    registration.protocolVersion === AGENT_PROTOCOL_VERSION &&
    typeof registration.website === 'string' &&
    typeof registration.documentNonce === 'string' &&
    Array.isArray(registration.capabilities)
  )
}

function isPageResponse(value: unknown): value is IAgentPageResponse {
  if (!value || typeof value !== 'object') return false
  const response = value as Partial<IAgentPageResponse>
  return (
    response.type === 'page.response' &&
    typeof response.requestId === 'string' &&
    typeof response.ok === 'boolean'
  )
}

function resolveOrigin(url: string): string {
  try {
    return new URL(url).origin
  } catch {
    return ''
  }
}

function responseSize(response: IAgentPageResponse): number {
  try {
    return new TextEncoder().encode(JSON.stringify(response)).byteLength
  } catch {
    return Number.POSITIVE_INFINITY
  }
}

function errorResponse(
  requestId: string,
  code: IAgentError['code'],
  message: string,
): IAgentPageResponse {
  return { type: 'page.response', requestId, ok: false, error: { code, message } }
}

function isWebsiteOriginAllowed(website: string, origin: string): boolean {
  if (!origin) return false
  const hostname = new URL(origin).hostname
  switch (website) {
    case 'codeforces':
      return hostname === 'codeforces.com' || hostname.endsWith('.codeforces.com')
    case 'reddit':
      return hostname === 'www.reddit.com' || hostname === 'old.reddit.com'
    case 'usaco':
      return hostname === 'usaco.training'
    case 'yoz':
      return hostname === 'localhost' || hostname === '127.0.0.1'
    default:
      return false
  }
}

async function resolveBrowserSessionId(): Promise<string> {
  const stored = (await chrome.storage.session.get(BROWSER_SESSION_KEY))[BROWSER_SESSION_KEY]
  if (typeof stored === 'string') return stored
  const sessionId = crypto.randomUUID()
  await chrome.storage.session.set({ [BROWSER_SESSION_KEY]: sessionId })
  return sessionId
}
