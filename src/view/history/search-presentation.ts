import type { ICommitSearchQuery } from '../../git/commit-search'

const MAX_VALUE_LENGTH = 28

export function formatCommitSearchQuery(query: ICommitSearchQuery): string {
  const parts = [formatScope(query)]
  if (query.path) parts.push(`path ${formatValue(query.path)}`)
  if (query.author) parts.push(`author ${formatValue(query.author)}`)
  if (query.since) parts.push(`since ${formatValue(query.since)}`)
  if (query.until) parts.push(`until ${formatValue(query.until)}`)
  if (query.message) parts.push(`message ${formatValue(query.message)}`)
  if (query.content?.mode === 'text') parts.push(`text ${formatValue(query.content.value)}`)
  if (query.content?.mode === 'regex') parts.push(`regex ${formatValue(query.content.value)}`)
  return parts.join(' · ')
}

function formatScope(query: ICommitSearchQuery): string {
  switch (query.scope.kind) {
    case 'head':
      return 'HEAD'
    case 'all':
      return 'all refs'
    case 'revision':
      return formatValue(query.scope.revision)
  }
}

function formatValue(value: string): string {
  return value.length <= MAX_VALUE_LENGTH ? value : `${value.slice(0, MAX_VALUE_LENGTH - 1)}…`
}
