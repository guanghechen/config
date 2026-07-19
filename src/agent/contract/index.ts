export const AGENT_PAGE_PORT_NAME = 'tsuki-agent-page'
export const AGENT_PROTOCOL_VERSION = 1
export const AGENT_PROTOCOL_MISMATCH_CLOSE_CODE = 4002
export const AGENT_GRANT_KINDS = ['read', 'memory', 'actions'] as const
export const AGENT_ERROR_CODES = [
  'ADAPTER_ERROR',
  'CAPABILITY_UNAVAILABLE',
  'INTERNAL_ERROR',
  'INVALID_REQUEST',
  'PAGE_NOT_FOUND',
  'PAGE_STALE',
  'PAYLOAD_TOO_LARGE',
  'PERMISSION_DENIED',
  'PROTOCOL_MISMATCH',
  'SENSITIVE_ELEMENT',
  'STALE_ELEMENT',
  'STALE_SNAPSHOT',
  'TIMEOUT',
] as const

export const GENERIC_AGENT_READ_CAPABILITIES = [
  'dom.snapshot',
  'dom.query',
  'dom.getText',
  'dom.getAttributes',
  'dom.getBounds',
] as const

export const GENERIC_AGENT_ACTION_CAPABILITIES = ['dom.scrollIntoView', 'dom.highlight'] as const

export const GENERIC_AGENT_CAPABILITIES = [
  ...GENERIC_AGENT_READ_CAPABILITIES,
  ...GENERIC_AGENT_ACTION_CAPABILITIES,
] as const

export const AGENT_MEMORY_CAPABILITIES = [
  'memory.list',
  'memory.get',
  'memory.set',
  'memory.delete',
] as const

export const AGENT_CAPABILITIES = [
  'page.describe',
  ...GENERIC_AGENT_CAPABILITIES,
  'codeforces.listProblems',
  'codeforces.readProblem',
  'codeforces.getContest',
] as const

export type AgentCapability = (typeof AGENT_CAPABILITIES)[number]
export type AgentMemoryCapability = (typeof AGENT_MEMORY_CAPABILITIES)[number]
export type AgentGrantKind = (typeof AGENT_GRANT_KINDS)[number]
export type AgentErrorCode = (typeof AGENT_ERROR_CODES)[number]

export interface IAgentError {
  readonly code: AgentErrorCode
  readonly message: string
}

export interface IAgentPageRegistration {
  readonly type: 'page.register'
  readonly protocolVersion: number
  readonly website: string
  readonly capabilities: ReadonlyArray<AgentCapability>
  readonly documentNonce: string
}

export interface IAgentPageRegistered {
  readonly type: 'page.registered'
  readonly pageId: string
}

export interface IAgentPageRequest {
  readonly type: 'page.request'
  readonly requestId: string
  readonly capability: AgentCapability
  readonly payload: unknown
  readonly timeoutMs: number
}

export interface IAgentPageResponse {
  readonly type: 'page.response'
  readonly requestId: string
  readonly ok: boolean
  readonly data?: unknown
  readonly error?: IAgentError
}

export interface IAgentElementDescriptor {
  readonly ref: string
  readonly role: string
  readonly name: string
  readonly tag: string
}

export interface IAgentSnapshot {
  readonly snapshotId: string
  readonly elements: ReadonlyArray<IAgentElementDescriptor>
  readonly truncated: boolean
}

export interface IAgentPageAdapter {
  readonly website: string
  readonly capabilities: ReadonlyArray<AgentCapability>
  readonly execute?: (
    capability: AgentCapability,
    payload: unknown,
    signal: AbortSignal,
  ) => Promise<unknown> | unknown
}

export interface IAgentBrokerRequest {
  readonly version: 1
  readonly requestId: string
  readonly target?: {
    readonly pageId: string
    readonly expectedDocumentId?: string
  }
  readonly capability:
    AgentCapability | AgentMemoryCapability | 'pages.list' | 'pages.resolveActive'
  readonly payload?: unknown
  readonly timeoutMs: number
}

export interface IAgentBrokerResponse {
  readonly version: 1
  readonly requestId: string
  readonly ok: boolean
  readonly data?: unknown
  readonly error?: IAgentError
}

export function isAgentCapability(value: unknown): value is AgentCapability {
  return typeof value === 'string' && AGENT_CAPABILITIES.includes(value as AgentCapability)
}

export function isAgentMemoryCapability(value: unknown): value is AgentMemoryCapability {
  return (
    typeof value === 'string' && AGENT_MEMORY_CAPABILITIES.includes(value as AgentMemoryCapability)
  )
}

export function isAgentActionCapability(value: unknown): value is AgentCapability {
  return (
    typeof value === 'string' &&
    GENERIC_AGENT_ACTION_CAPABILITIES.includes(
      value as (typeof GENERIC_AGENT_ACTION_CAPABILITIES)[number],
    )
  )
}

export function isAgentGrantKind(value: unknown): value is AgentGrantKind {
  return typeof value === 'string' && AGENT_GRANT_KINDS.includes(value as AgentGrantKind)
}

export function isAgentErrorCode(value: unknown): value is AgentErrorCode {
  return typeof value === 'string' && AGENT_ERROR_CODES.includes(value as AgentErrorCode)
}

export type AgentControlAction = 'status' | 'pair' | 'unpair' | 'setGrant'

export interface IAgentControlRequest {
  readonly type: 'agent.control'
  readonly action: AgentControlAction
  readonly pairingCode?: string
  readonly origin?: string
  readonly allowed?: boolean
  readonly grant?: AgentGrantKind
}

export interface IAgentControlStatus {
  readonly paired: boolean
  readonly connected: boolean
  readonly grants: ReadonlyArray<string>
  readonly memoryGrants: ReadonlyArray<string>
  readonly actionGrants: ReadonlyArray<string>
  readonly error?: IAgentError
}

export interface IAgentControlResponse {
  readonly ok: boolean
  readonly status?: IAgentControlStatus
  readonly error?: IAgentError
}

export interface IAgentPageRecord {
  readonly pageId: string
  readonly tabId: number
  readonly windowId: number
  readonly frameId: number
  readonly documentId: string
  readonly url: string
  readonly origin: string
  readonly title: string
  readonly active: boolean
  readonly website: string
  readonly capabilities: ReadonlyArray<AgentCapability>
  readonly revision: number
}
