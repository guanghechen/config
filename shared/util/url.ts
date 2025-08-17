export function normalizeUrlPath(pathname: string): string {
  const p: string = pathname.trim().replace(/[/\\]+/g, '/')
  return p.length > 0 ? p.replace(/\/+$/, '') : p
}

export function toSearch(params: Record<string, string | null | undefined>): string {
  const usp = new URLSearchParams()
  for (const key in params) {
    const val = params[key]
    if (typeof val === 'string') {
      usp.set(key, encodeURIComponent(val))
    }
  }

  const query: string = usp.toString()
  return query.length > 0 ? `?${query}` : query
}
