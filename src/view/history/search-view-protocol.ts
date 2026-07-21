import {
  createCommitSearchQuery,
  type CommitContentSearch,
  type CommitSearchScope,
  type ICommitSearchQuery,
} from '../../git/commit-search'

export type CommitSearchViewMessage =
  | { readonly type: 'ready' }
  | { readonly type: 'cancel' }
  | { readonly type: 'clear' }
  | { readonly type: 'search'; readonly query: ICommitSearchQuery }

export function parseCommitSearchViewMessage(value: unknown): CommitSearchViewMessage {
  const message = requireRecord(value, 'Search message')
  switch (message.type) {
    case 'ready':
    case 'cancel':
    case 'clear':
      return Object.freeze({ type: message.type })
    case 'search':
      return Object.freeze({ type: 'search', query: parseQuery(message.query) })
    default:
      throw new Error('Search message type is invalid.')
  }
}

function parseQuery(value: unknown): ICommitSearchQuery {
  const query = requireRecord(value, 'Search query')
  return createCommitSearchQuery({
    scope: parseScope(query.scope),
    path: readOptionalString(query.path, 'Path'),
    author: readOptionalString(query.author, 'Author'),
    since: readOptionalString(query.since, 'Since date'),
    until: readOptionalString(query.until, 'Until date'),
    message: readOptionalString(query.message, 'Commit message'),
    content: parseContent(query.content),
  })
}

function parseScope(value: unknown): CommitSearchScope {
  const scope = requireRecord(value, 'Search scope')
  switch (scope.kind) {
    case 'head':
    case 'all':
      return { kind: scope.kind }
    case 'revision':
      return { kind: 'revision', revision: requireString(scope.revision, 'Revision') }
    default:
      throw new Error('Search scope is invalid.')
  }
}

function parseContent(value: unknown): CommitContentSearch | null {
  if (value === null || value === undefined) return null
  const content = requireRecord(value, 'Content search')
  const contentValue = requireString(content.value, 'Content search')
  switch (content.mode) {
    case 'text':
    case 'regex':
      return { mode: content.mode, value: contentValue }
    default:
      throw new Error('Content search mode is invalid.')
  }
}

function readOptionalString(value: unknown, label: string): string | null {
  if (value === null || value === undefined) return null
  return requireString(value, label)
}

function requireString(value: unknown, label: string): string {
  if (typeof value !== 'string') throw new Error(`${label} must be a string.`)
  return value
}

function requireRecord(value: unknown, label: string): Readonly<Record<string, unknown>> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} is invalid.`)
  }
  return value as Readonly<Record<string, unknown>>
}
