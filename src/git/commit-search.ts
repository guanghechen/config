const MAX_REVISION_LENGTH = 1024
const MAX_FILTER_LENGTH = 4096

export type CommitSearchScope =
  | { readonly kind: 'head' }
  | { readonly kind: 'all' }
  | { readonly kind: 'revision'; readonly revision: string }

export type CommitContentSearch =
  | { readonly mode: 'text'; readonly value: string }
  | { readonly mode: 'regex'; readonly value: string }

export interface ICommitSearchQuery {
  readonly scope: CommitSearchScope
  readonly path: string | null
  readonly author: string | null
  readonly since: string | null
  readonly until: string | null
  readonly message: string | null
  readonly content: CommitContentSearch | null
}

export interface ICommitSearchQueryInput {
  readonly scope?: CommitSearchScope
  readonly path?: string | null
  readonly author?: string | null
  readonly since?: string | null
  readonly until?: string | null
  readonly message?: string | null
  readonly content?: CommitContentSearch | null
}

export interface ICommitSearchArguments {
  readonly options: ReadonlyArray<string>
  readonly revisions: ReadonlyArray<string>
  readonly pathspecs: ReadonlyArray<string>
}

export function createCommitSearchQuery(input: ICommitSearchQueryInput = {}): ICommitSearchQuery {
  return Object.freeze({
    scope: normalizeScope(input.scope ?? { kind: 'head' }),
    path: normalizeExactOptionalFilter(input.path, 'Path'),
    author: normalizeExactOptionalFilter(input.author, 'Author'),
    since: normalizeTrimmedOptionalFilter(input.since, 'Since date'),
    until: normalizeTrimmedOptionalFilter(input.until, 'Until date'),
    message: normalizeExactOptionalFilter(input.message, 'Commit message'),
    content: normalizeContentSearch(input.content),
  })
}

export function createCommitSearchArguments(
  queryValue: ICommitSearchQuery,
  headCommit: string | null,
): ICommitSearchArguments {
  const query = createCommitSearchQuery(queryValue)
  const options: string[] = []

  if (query.path || query.content) options.push('--find-renames')
  if (query.author) options.push(`--author=${query.author}`)
  if (query.since) options.push(`--since=${query.since}`)
  if (query.until) options.push(`--until=${query.until}`)
  if (query.message) options.push(`--grep=${query.message}`)
  if (query.content?.mode === 'text') options.push(`-S${query.content.value}`)
  if (query.content?.mode === 'regex') options.push(`-G${query.content.value}`)

  return Object.freeze({
    options: Object.freeze(options),
    revisions: Object.freeze(createRevisionArguments(query.scope, headCommit)),
    pathspecs: Object.freeze(query.path ? [query.path] : []),
  })
}

function normalizeScope(scope: CommitSearchScope): CommitSearchScope {
  switch (scope.kind) {
    case 'head':
      return Object.freeze({ kind: 'head' })
    case 'all':
      return Object.freeze({ kind: 'all' })
    case 'revision': {
      const revision = scope.revision.trim()
      if (!revision) throw new Error('Revision or range is required.')
      if (revision.length > MAX_REVISION_LENGTH || revision.includes('\0')) {
        throw new Error('Revision or range is invalid.')
      }
      if (revision.startsWith('-')) {
        throw new Error('Revision or range must not start with "-".')
      }
      return Object.freeze({ kind: 'revision', revision })
    }
  }
}

function normalizeContentSearch(
  content: CommitContentSearch | null | undefined,
): CommitContentSearch | null {
  if (!content) return null
  assertFilterValue(content.value, 'Content search')
  return Object.freeze({ mode: content.mode, value: content.value })
}

function normalizeExactOptionalFilter(
  value: string | null | undefined,
  label: string,
): string | null {
  if (value === null || value === undefined || value.length === 0) return null
  assertFilterValue(value, label)
  return value
}

function normalizeTrimmedOptionalFilter(
  value: string | null | undefined,
  label: string,
): string | null {
  if (value === null || value === undefined) return null
  const normalized = value.trim()
  if (!normalized) return null
  assertFilterValue(normalized, label)
  return normalized
}

function assertFilterValue(value: string, label: string): void {
  if (!value || value.length > MAX_FILTER_LENGTH || value.includes('\0')) {
    throw new Error(`${label} is invalid.`)
  }
}

function createRevisionArguments(scope: CommitSearchScope, headCommit: string | null): string[] {
  switch (scope.kind) {
    case 'head':
      return headCommit ? [headCommit] : []
    case 'all':
      return ['--all']
    case 'revision':
      return ['--end-of-options', scope.revision]
  }
}
