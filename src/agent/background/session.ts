export interface IAgentSessionState {
  readonly sessionToken?: string
  readonly grants: ReadonlyArray<string>
}

const STORAGE_KEY = 'tsuki-agent-session'
const EMPTY_STATE: IAgentSessionState = { grants: [] }

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

function normalizeSession(value: unknown): IAgentSessionState {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return EMPTY_STATE
  const state = value as Record<string, unknown>
  return {
    sessionToken: typeof state.sessionToken === 'string' ? state.sessionToken : undefined,
    grants: Array.isArray(state.grants)
      ? [...new Set(state.grants.filter((entry): entry is string => isOrigin(entry)))].sort()
      : [],
  }
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
