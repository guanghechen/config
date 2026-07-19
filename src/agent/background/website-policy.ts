export function isWebsiteOriginAllowed(website: string, origin: string): boolean {
  const hostname = parseHttpOrigin(origin)?.hostname
  if (!hostname) return false

  switch (website) {
    case 'codeforces':
      return hostname === 'codeforces.com' || hostname.endsWith('.codeforces.com')
    case 'reddit':
      return hostname === 'www.reddit.com' || hostname === 'old.reddit.com'
    case 'usaco':
      return hostname === 'usaco.training'
    case 'yoz':
      return hostname === 'localhost' || hostname === '127.0.0.1'
    default:
      return false
  }
}

export function parseHttpOrigin(value: unknown): URL | null {
  if (typeof value !== 'string') return null
  try {
    const url = new URL(value)
    return (url.protocol === 'http:' || url.protocol === 'https:') && url.origin === value
      ? url
      : null
  } catch {
    return null
  }
}
