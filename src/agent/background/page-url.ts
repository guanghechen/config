export function sanitizePageUrl(value: string): string {
  try {
    const url = new URL(value)
    return `${url.origin}${url.pathname}`
  } catch {
    return ''
  }
}

export function sanitizePageTitle(value: string, pageUrl: string): string {
  try {
    const url = new URL(pageUrl)
    let title = value
    if (url.search) title = title.split(url.search).join('')
    if (url.hash) title = title.split(url.hash).join('')
    return title.trim().slice(0, 512)
  } catch {
    return value.trim().slice(0, 512)
  }
}
