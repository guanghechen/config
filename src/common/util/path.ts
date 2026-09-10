const regexes = {
  extname: /(\.[^.]+)$/,
}

export const calcExtname = (filepath: string | null): string => {
  const extname: string = filepath ? regexes.extname.exec(filepath)?.[1] || '' : ''
  return extname
}

export const isAbsoluteFilepath = (filepath: string): boolean => {
  return filepath.startsWith('/') || /^[A-Za-z]:[/\\]/.test(filepath) || /^[/\\]{2}/.test(filepath)
}

export const normalizeAbsoluteFilepath = (filepath: string): string | null => {
  const normalized =
    /^[A-Za-z]:[/\\]/.test(filepath) || /^\\\\/.test(filepath)
      ? filepath.replace(/\\/g, '/')
      : filepath
  if (!isAbsoluteFilepath(normalized)) return null
  if (normalized === '/' || /^[A-Za-z]:\/$/.test(normalized)) return normalized
  return normalized.replace(/\/+$/, '')
}

export const resolveWorkspaceFilepath = (root: string, filepath: string): string => {
  const normalizedFilepath = normalizeAbsoluteFilepath(filepath)
  if (normalizedFilepath) return normalizedFilepath

  const normalizedRoot = normalizeAbsoluteFilepath(root)
  if (!normalizedRoot) return filepath
  const separator = normalizedRoot.endsWith('/') ? '' : '/'
  return `${normalizedRoot}${separator}${filepath.replace(/^[/\\]+/, '')}`
}

export const isFilepathWithinRoot = (filepath: string, root: string): boolean => {
  const normalizedFilepath = normalizeAbsoluteFilepath(filepath)
  const normalizedRoot = normalizeAbsoluteFilepath(root)
  if (!normalizedFilepath || !normalizedRoot) return false
  if (normalizedRoot === '/') return normalizedFilepath.startsWith('/')
  if (normalizedRoot.endsWith('/')) return normalizedFilepath.startsWith(normalizedRoot)
  return (
    normalizedFilepath === normalizedRoot || normalizedFilepath.startsWith(`${normalizedRoot}/`)
  )
}

export const relativeWorkspaceFilepath = (filepath: string, root: string): string => {
  if (!isFilepathWithinRoot(filepath, root)) return filepath
  const normalizedFilepath = normalizeAbsoluteFilepath(filepath)!
  const normalizedRoot = normalizeAbsoluteFilepath(root)!
  if (normalizedFilepath === normalizedRoot) return '.'
  return normalizedFilepath.slice(normalizedRoot.length).replace(/^\/+/, '')
}

export const selectWorkspaceRoot = (filepath: string, roots: readonly string[]): string | null => {
  let selectedRoot: string | null = null
  for (const root of roots) {
    if (
      isFilepathWithinRoot(filepath, root) &&
      (!selectedRoot || root.length > selectedRoot.length)
    ) {
      selectedRoot = root
    }
  }
  return selectedRoot
}

export const readAbsoluteSearchParam = (value: string | null): string | null => {
  if (!value) return null
  const normalized = normalizeAbsoluteFilepath(value)
  if (normalized) return normalized

  try {
    return normalizeAbsoluteFilepath(decodeURIComponent(value))
  } catch {
    return null
  }
}
