export function isWebsiteOriginAllowed(website: string, origin: string): boolean {
  let hostname: string
  try {
    const url = new URL(origin)
    if ((url.protocol !== 'http:' && url.protocol !== 'https:') || url.origin !== origin) {
      return false
    }
    hostname = url.hostname
  } catch {
    return false
  }

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
