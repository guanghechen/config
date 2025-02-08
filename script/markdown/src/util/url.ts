export function isLocalUrl(url: string | null | undefined): url is string {
  return !!url && (url[0] === '.' || url[0] === '/' || url[0] === '\\')
}

export function resolveLocalResourceSrc(filepath: string, base: string | undefined): string {
  const query: Record<string, string> = { filepath }
  if (base) query.base = base
  const params = new URLSearchParams(query) // Add your query parameters here
  return `/api/file?${params}`
}

export function resolveLocalMarkdownLink(filepath: string, base: string | undefined): string {
  let resolvedPath: string = filepath
  if (base) resolvedPath = base.replace(/[/\\][^/\\]*$/, '') + '/' + resolvedPath

  const pieces = resolvedPath.split(/[/\\]+/g)
  let k = -1
  for (let i = 0; i < pieces.length; ++i) {
    const piece: string = pieces[i]
    if (piece === '..') k = k - 1
    else if (piece !== '.') {
      k = k < 0 ? 0 : k + 1
      pieces[k] = piece
    }
  }
  resolvedPath = pieces.slice(0, k + 1).join('/')

  const query: Record<string, string> = { filepath: resolvedPath }
  const params = new URLSearchParams(query) // Add your query parameters here
  return `/?${params}`
}
