import { isFilepathWithinRoot, normalizeAbsoluteFilepath } from '@/common/util/path'

export const resolveWorkspaceLink = (url: string, workspaceRoot: string | null): string => {
  if (!workspaceRoot || !url.startsWith('/file?')) return url

  const parsed = new URL(url, 'http://workspace.local')
  if (parsed.pathname !== '/file') return url

  const filepath = parsed.searchParams.get('filepath')
  const canonicalRoot = normalizeAbsoluteFilepath(workspaceRoot)
  const normalizedRoot = canonicalRoot ? normalizePathSegments(canonicalRoot) : null
  const normalizedFilepath = filepath ? normalizePathSegments(filepath) : null
  if (
    !canonicalRoot ||
    !normalizedRoot ||
    !normalizedFilepath ||
    !isFilepathWithinRoot(normalizedFilepath, normalizedRoot)
  ) {
    return url
  }

  const params = new URLSearchParams()
  params.set('root', canonicalRoot)
  params.set('filepath', normalizedFilepath)
  for (const [key, value] of parsed.searchParams) {
    if (key !== 'root' && key !== 'filepath') params.append(key, value)
  }
  return `/ws?${params}${parsed.hash}`
}

const normalizePathSegments = (filepath: string): string | null => {
  const normalized = normalizeAbsoluteFilepath(filepath)
  if (!normalized) return null

  const drive = /^[A-Za-z]:\//.exec(normalized)?.[0] ?? ''
  const prefix = drive || (normalized.startsWith('//') ? '//' : '/')
  const pieces = normalized.slice(prefix.length).split('/')
  const stack: string[] = []
  for (const piece of pieces) {
    if (!piece || piece === '.') continue
    if (piece === '..') {
      stack.pop()
    } else {
      stack.push(piece)
    }
  }
  return `${prefix}${stack.join('/')}`
}
