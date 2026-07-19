import type { AgentMemoryCapability, IAgentPageRecord } from '@/agent/contract'

const STORAGE_KEY = 'tsuki-agent-memory-v1'
const MAX_MEMORY_ENTRIES = 64
const MAX_MEMORY_ENTRIES_PER_ORIGIN = 32
const MAX_MEMORY_ENTRIES_PER_SCOPE = 16
const MAX_MEMORY_KEY_LENGTH = 64
const MAX_MEMORY_SCOPE_ID_LENGTH = 2_048
const MAX_MEMORY_VALUE_LENGTH = 2_048
const MEMORY_KEY_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]*$/

export type AgentMemoryScope = 'origin' | 'page'

export interface IAgentMemoryNote {
  readonly key: string
  readonly value: string
  readonly updatedAt: number
}

interface IStoredMemoryNote extends IAgentMemoryNote {
  readonly origin: string
  readonly scope: AgentMemoryScope
  readonly scopeId: string
}

export interface IAgentMemoryStorage {
  readonly read: () => Promise<unknown>
  readonly write: (notes: ReadonlyArray<IStoredMemoryNote>) => Promise<void>
}

export class AgentMemoryStore {
  private mutationQueue: Promise<unknown> = Promise.resolve()
  private notesPromise: Promise<ReadonlyArray<IStoredMemoryNote>> | null = null
  private readonly storage: IAgentMemoryStorage

  public constructor(storage: IAgentMemoryStorage = chromeMemoryStorage) {
    this.storage = storage
  }

  public async execute(
    capability: AgentMemoryCapability,
    page: IAgentPageRecord,
    pageScopeId: string,
    payload: unknown,
    isAuthorized: () => boolean = () => true,
  ): Promise<unknown> {
    assertMemoryAuthorized(isAuthorized)
    const request = readRecord(payload)
    const scope = readScope(request.scope)
    const scopeId = scope === 'origin' ? page.origin : pageScopeId
    if (!scopeId || scopeId.length > MAX_MEMORY_SCOPE_ID_LENGTH) {
      throw createMemoryError('PAYLOAD_TOO_LARGE', 'Memory scope identifier is too large.')
    }

    switch (capability) {
      case 'memory.list': {
        const notes = await this.list(page.origin, scope, scopeId)
        assertMemoryAuthorized(isAuthorized)
        return { scope, notes }
      }
      case 'memory.get': {
        const note = await this.get(page.origin, scope, scopeId, readKey(request.key))
        assertMemoryAuthorized(isAuthorized)
        return { scope, note }
      }
      case 'memory.set': {
        const note = await this.set(
          page.origin,
          scope,
          scopeId,
          readKey(request.key),
          readValue(request.value),
          isAuthorized,
        )
        assertMemoryAuthorized(isAuthorized)
        return { scope, note }
      }
      case 'memory.delete': {
        const deleted = await this.delete(
          page.origin,
          scope,
          scopeId,
          readKey(request.key),
          isAuthorized,
        )
        assertMemoryAuthorized(isAuthorized)
        return { scope, deleted }
      }
      default:
        throw createMemoryError('CAPABILITY_UNAVAILABLE', 'Agent memory capability is unavailable.')
    }
  }

  private async list(
    origin: string,
    scope: AgentMemoryScope,
    scopeId: string,
  ): Promise<ReadonlyArray<IAgentMemoryNote>> {
    const notes = await this.readNotes()
    return notes
      .filter(note => note.origin === origin && note.scope === scope && note.scopeId === scopeId)
      .map(toPublicNote)
      .sort((left, right) => left.key.localeCompare(right.key))
  }

  private async get(
    origin: string,
    scope: AgentMemoryScope,
    scopeId: string,
    key: string,
  ): Promise<IAgentMemoryNote | null> {
    const notes = await this.readNotes()
    const note = notes.find(
      candidate =>
        candidate.origin === origin &&
        candidate.scope === scope &&
        candidate.scopeId === scopeId &&
        candidate.key === key,
    )
    return note ? toPublicNote(note) : null
  }

  private set(
    origin: string,
    scope: AgentMemoryScope,
    scopeId: string,
    key: string,
    value: string,
    isAuthorized: () => boolean,
  ): Promise<IAgentMemoryNote> {
    return this.mutate(notes => {
      assertMemoryAuthorized(isAuthorized)
      const index = notes.findIndex(
        candidate =>
          candidate.origin === origin &&
          candidate.scope === scope &&
          candidate.scopeId === scopeId &&
          candidate.key === key,
      )
      if (index < 0 && notes.length >= MAX_MEMORY_ENTRIES) {
        throw createMemoryError('PAYLOAD_TOO_LARGE', 'Agent memory entry limit reached.')
      }
      if (
        index < 0 &&
        notes.filter(candidate => candidate.origin === origin).length >=
          MAX_MEMORY_ENTRIES_PER_ORIGIN
      ) {
        throw createMemoryError('PAYLOAD_TOO_LARGE', 'Agent memory origin limit reached.')
      }
      if (
        index < 0 &&
        notes.filter(
          candidate =>
            candidate.origin === origin &&
            candidate.scope === scope &&
            candidate.scopeId === scopeId,
        ).length >= MAX_MEMORY_ENTRIES_PER_SCOPE
      ) {
        throw createMemoryError('PAYLOAD_TOO_LARGE', 'Agent memory scope limit reached.')
      }

      const note: IStoredMemoryNote = { origin, scope, scopeId, key, value, updatedAt: Date.now() }
      const nextNotes = [...notes]
      if (index >= 0) nextNotes[index] = note
      else nextNotes.push(note)
      return { notes: nextNotes, result: toPublicNote(note) }
    })
  }

  private delete(
    origin: string,
    scope: AgentMemoryScope,
    scopeId: string,
    key: string,
    isAuthorized: () => boolean,
  ): Promise<boolean> {
    return this.mutate(notes => {
      assertMemoryAuthorized(isAuthorized)
      const nextNotes = notes.filter(
        candidate =>
          candidate.origin !== origin ||
          candidate.scope !== scope ||
          candidate.scopeId !== scopeId ||
          candidate.key !== key,
      )
      return { notes: nextNotes, result: nextNotes.length !== notes.length }
    })
  }

  private async readNotes(): Promise<ReadonlyArray<IStoredMemoryNote>> {
    await this.mutationQueue
    return this.loadNotes()
  }

  private loadNotes(): Promise<ReadonlyArray<IStoredMemoryNote>> {
    this.notesPromise ??= this.storage
      .read()
      .then(normalizeNotes)
      .catch(cause => {
        this.notesPromise = null
        throw cause
      })
    return this.notesPromise
  }

  private mutate<T>(
    update: (notes: ReadonlyArray<IStoredMemoryNote>) => {
      readonly notes: ReadonlyArray<IStoredMemoryNote>
      readonly result: T
    },
  ): Promise<T> {
    const operation = this.mutationQueue.then(async () => {
      const currentNotes = await this.loadNotes()
      const { notes, result } = update(currentNotes)
      await this.storage.write(notes)
      this.notesPromise = Promise.resolve(notes)
      return result
    })
    this.mutationQueue = operation.then(
      () => undefined,
      () => undefined,
    )
    return operation
  }
}

const chromeMemoryStorage: IAgentMemoryStorage = {
  async read() {
    return (await chrome.storage.session.get(STORAGE_KEY))[STORAGE_KEY]
  },
  async write(notes) {
    await chrome.storage.session.set({ [STORAGE_KEY]: notes })
  },
}

function normalizeNotes(value: unknown): ReadonlyArray<IStoredMemoryNote> {
  if (!Array.isArray(value)) return []
  const notes = new Map<string, IStoredMemoryNote>()
  for (const candidate of value.slice(0, MAX_MEMORY_ENTRIES)) {
    if (!candidate || typeof candidate !== 'object' || Array.isArray(candidate)) continue
    const note = candidate as Record<string, unknown>
    if (
      (note.scope !== 'origin' && note.scope !== 'page') ||
      !isOrigin(note.origin) ||
      typeof note.scopeId !== 'string' ||
      !note.scopeId ||
      note.scopeId.length > MAX_MEMORY_SCOPE_ID_LENGTH ||
      !isMemoryKey(note.key) ||
      typeof note.value !== 'string' ||
      note.value.length > MAX_MEMORY_VALUE_LENGTH ||
      typeof note.updatedAt !== 'number' ||
      !Number.isFinite(note.updatedAt)
    ) {
      continue
    }
    const normalized: IStoredMemoryNote = {
      origin: note.origin,
      scope: note.scope,
      scopeId: note.scopeId,
      key: note.key,
      value: note.value,
      updatedAt: note.updatedAt,
    }
    notes.set(
      `${normalized.origin}\0${normalized.scope}\0${normalized.scopeId}\0${normalized.key}`,
      normalized,
    )
  }
  return [...notes.values()]
}

function toPublicNote(note: IStoredMemoryNote): IAgentMemoryNote {
  return { key: note.key, value: note.value, updatedAt: note.updatedAt }
}

function readRecord(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>
  }
  throw createMemoryError('INVALID_REQUEST', 'Memory payload must be an object.')
}

function readScope(value: unknown): AgentMemoryScope {
  if (value === 'origin' || value === 'page') return value
  throw createMemoryError('INVALID_REQUEST', 'Memory scope must be origin or page.')
}

function readKey(value: unknown): string {
  if (isMemoryKey(value)) return value
  throw createMemoryError('INVALID_REQUEST', 'Memory key is invalid.')
}

function isMemoryKey(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    value.length > 0 &&
    value.length <= MAX_MEMORY_KEY_LENGTH &&
    MEMORY_KEY_PATTERN.test(value)
  )
}

function isOrigin(value: unknown): value is string {
  if (typeof value !== 'string') return false
  try {
    const url = new URL(value)
    return (url.protocol === 'http:' || url.protocol === 'https:') && url.origin === value
  } catch {
    return false
  }
}

function readValue(value: unknown): string {
  if (typeof value !== 'string') {
    throw createMemoryError('INVALID_REQUEST', 'Memory value must be a string.')
  }
  if (value.length > MAX_MEMORY_VALUE_LENGTH) {
    throw createMemoryError('PAYLOAD_TOO_LARGE', 'Memory value is too large.')
  }
  return value
}

function createMemoryError(code: string, message: string): Error {
  return Object.assign(new Error(message), { code })
}

function assertMemoryAuthorized(isAuthorized: () => boolean): void {
  if (!isAuthorized()) {
    throw createMemoryError('PERMISSION_DENIED', 'Agent memory was revoked.')
  }
}
