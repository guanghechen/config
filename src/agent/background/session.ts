import type { AgentGrantKind } from '@/agent/contract'

export interface IAgentSessionState {
  readonly sessionToken?: string
  readonly grants: ReadonlyArray<string>
  readonly memoryGrants: ReadonlyArray<string>
  readonly actionGrants: ReadonlyArray<string>
}

const STORAGE_KEY = 'tsuki-agent-session'
const EMPTY_STATE: IAgentSessionState = { grants: [], memoryGrants: [], actionGrants: [] }

export async function readAgentSession(): Promise<IAgentSessionState> {
  const value = (await chrome.storage.session.get(STORAGE_KEY))[STORAGE_KEY]
  return normalizeSession(value)
}

export async function writeAgentSession(state: IAgentSessionState): Promise<void> {
  await chrome.storage.session.set({ [STORAGE_KEY]: normalizeSession(state) })
}

export async function clearAgentSession(): Promise<void> {
  await chrome.storage.session.remove(STORAGE_KEY)
}

export function updateAgentSessionGrant(
  state: IAgentSessionState,
  origin: string,
  grant: AgentGrantKind,
  allowed: boolean,
): IAgentSessionState {
  const grants = new Set(state.grants)
  const memoryGrants = new Set(state.memoryGrants)
  const actionGrants = new Set(state.actionGrants)
  if (grant !== 'read' && allowed && !grants.has(origin)) {
    throw new Error('Read access must be enabled first.')
  }

  const selectedGrants =
    grant === 'read' ? grants : grant === 'memory' ? memoryGrants : actionGrants
  if (allowed) selectedGrants.add(origin)
  else selectedGrants.delete(origin)
  if (grant === 'read' && !allowed) {
    memoryGrants.delete(origin)
    actionGrants.delete(origin)
  }

  return {
    ...state,
    grants: [...grants].sort(),
    memoryGrants: [...memoryGrants].sort(),
    actionGrants: [...actionGrants].sort(),
  }
}

function normalizeSession(value: unknown): IAgentSessionState {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return EMPTY_STATE
  const state = value as Record<string, unknown>
  const grants = normalizeGrants(state.grants)
  const grantedOrigins = new Set(grants)
  return {
    sessionToken: typeof state.sessionToken === 'string' ? state.sessionToken : undefined,
    grants,
    memoryGrants: normalizeGrants(state.memoryGrants).filter(origin => grantedOrigins.has(origin)),
    actionGrants: normalizeGrants(state.actionGrants).filter(origin => grantedOrigins.has(origin)),
  }
}

function normalizeGrants(value: unknown): ReadonlyArray<string> {
  return Array.isArray(value)
    ? [...new Set(value.filter((entry): entry is string => isOrigin(entry)))].sort()
    : []
}

function isOrigin(value: unknown): boolean {
  if (typeof value !== 'string') return false
  try {
    const url = new URL(value)
    return (url.protocol === 'http:' || url.protocol === 'https:') && url.origin === value
  } catch {
    return false
  }
}
