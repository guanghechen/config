import {
  AGENT_PROTOCOL_VERSION,
  isAgentActionCapability,
  isAgentCapability,
  isAgentErrorCode,
  isAgentMemoryCapability,
  type IAgentBrokerRequest,
  type IAgentBrokerResponse,
  type IAgentError,
} from '@/agent/contract'
import { AgentMemoryStore } from './memory'
import { PageRegistry } from './page-registry'
import type { IAgentSessionState } from './session'

const MAX_REQUEST_BYTES = 64 * 1024
const MIN_TIMEOUT_MS = 100
const MAX_TIMEOUT_MS = 10_000

export class AgentRequestExecutor {
  private readonly memoryGrantRevisions = new Map<string, number>()

  public constructor(
    private readonly registry: PageRegistry,
    private readonly readSession: () => IAgentSessionState,
    private readonly memoryStore = new AgentMemoryStore(),
  ) {}

  public invalidateMemoryAccess(origins: Iterable<string>): void {
    for (const origin of origins) {
      this.memoryGrantRevisions.set(origin, this.readMemoryGrantRevision(origin) + 1)
    }
  }

  public async execute(value: unknown): Promise<IAgentBrokerResponse> {
    if (!isBrokerRequest(value) || encodedSize(value) > MAX_REQUEST_BYTES) {
      return brokerError(readRequestId(value), 'INVALID_REQUEST', 'Broker request is invalid.')
    }

    try {
      return await this.executeWithDeadline(value)
    } catch (cause) {
      return brokerError(
        value.requestId,
        readErrorCode(cause),
        cause instanceof Error ? cause.message : 'Broker request failed.',
      )
    }
  }

  private async executeWithDeadline(request: IAgentBrokerRequest): Promise<IAgentBrokerResponse> {
    const timeoutMs = Math.min(Math.max(request.timeoutMs, MIN_TIMEOUT_MS), MAX_TIMEOUT_MS)
    let active = true
    let timeoutId: ReturnType<typeof setTimeout> | null = null
    const operation = this.executeValidatedRequest(request, timeoutMs, () => active)
    const timeout = new Promise<IAgentBrokerResponse>(resolve => {
      timeoutId = setTimeout(() => {
        active = false
        resolve(brokerError(request.requestId, 'TIMEOUT', 'Broker request timed out.'))
      }, timeoutMs)
    })
    return Promise.race([operation, timeout]).finally(() => {
      active = false
      if (timeoutId !== null) clearTimeout(timeoutId)
    })
  }

  private async executeValidatedRequest(
    request: IAgentBrokerRequest,
    timeoutMs: number,
    isActive: () => boolean,
  ): Promise<IAgentBrokerResponse> {
    const grants = new Set(this.readSession().grants)

    if (request.capability === 'pages.list') {
      return brokerSuccess(request.requestId, { pages: this.registry.list(grants) })
    }
    if (request.capability === 'pages.resolveActive') {
      const page = await this.registry.resolveActive(grants)
      return brokerSuccess(request.requestId, {
        page: page && this.readSession().grants.includes(page.origin) ? page : null,
      })
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
    if (
      request.target.expectedDocumentId &&
      request.target.expectedDocumentId !== page.documentId
    ) {
      return brokerError(request.requestId, 'PAGE_STALE', 'Page document has changed.')
    }

    if (isAgentMemoryCapability(request.capability)) {
      if (!this.readSession().memoryGrants.includes(page.origin)) {
        return brokerError(request.requestId, 'PERMISSION_DENIED', 'Agent memory is not granted.')
      }
      const grantRevision = this.readMemoryGrantRevision(page.origin)
      const hasMemoryAccess = () => isActive() && this.hasMemoryAccess(page.origin, grantRevision)
      const pageScopeId = await this.registry.resolvePageMemoryScopeId(page.pageId)
      if (!pageScopeId) {
        return brokerError(request.requestId, 'PAGE_STALE', 'Page document has changed.')
      }
      if (!hasMemoryAccess()) {
        return brokerError(request.requestId, 'PERMISSION_DENIED', 'Agent memory was revoked.')
      }
      const result = await this.memoryStore.execute(
        request.capability,
        page,
        pageScopeId,
        request.payload ?? {},
        hasMemoryAccess,
      )
      if (!hasMemoryAccess()) {
        return brokerError(request.requestId, 'PERMISSION_DENIED', 'Agent memory was revoked.')
      }
      return brokerSuccess(request.requestId, {
        pageId: page.pageId,
        documentId: page.documentId,
        pageRevision: page.revision,
        result,
      })
    }

    if (request.capability === 'page.describe') {
      const session = this.readSession()
      return brokerSuccess(request.requestId, {
        page,
        permissions: {
          memory: session.memoryGrants.includes(page.origin),
          actions: session.actionGrants.includes(page.origin),
        },
      })
    }
    if (!isAgentCapability(request.capability)) {
      return brokerError(request.requestId, 'CAPABILITY_UNAVAILABLE', 'Capability is unavailable.')
    }
    if (
      isAgentActionCapability(request.capability) &&
      !this.readSession().actionGrants.includes(page.origin)
    ) {
      return brokerError(request.requestId, 'PERMISSION_DENIED', 'Page actions are not granted.')
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

  private hasMemoryAccess(origin: string, revision: number): boolean {
    const session = this.readSession()
    return (
      this.readMemoryGrantRevision(origin) === revision &&
      session.grants.includes(origin) &&
      session.memoryGrants.includes(origin)
    )
  }

  private readMemoryGrantRevision(origin: string): number {
    return this.memoryGrantRevisions.get(origin) ?? 0
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

function readErrorCode(value: unknown): IAgentError['code'] {
  if (!value || typeof value !== 'object') return 'INTERNAL_ERROR'
  const code = (value as { code?: unknown }).code
  return isAgentErrorCode(code) ? code : 'INTERNAL_ERROR'
}

function encodedSize(value: unknown): number {
  try {
    return new TextEncoder().encode(JSON.stringify(value)).byteLength
  } catch {
    return Number.POSITIVE_INFINITY
  }
}
