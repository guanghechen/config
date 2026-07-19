interface IPageMemoryTabSnapshot {
  readonly status?: string
  readonly url?: string
}

export async function createPageMemoryScopeId(sessionId: string, fullUrl: string): Promise<string> {
  if (!sessionId || !fullUrl) throw new Error('Page memory scope input is invalid.')
  const encoder = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(sessionId),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(fullUrl))
  const hash = [...new Uint8Array(signature)]
    .map(value => value.toString(16).padStart(2, '0'))
    .join('')
  return `scope_${hash}`
}

export function resolvePageMemorySourceUrl(
  tab: IPageMemoryTabSnapshot,
  registeredUrl: string,
  registeredOrigin: string,
): string | null {
  if (tab.status !== 'complete' || !tab.url || tab.url !== registeredUrl) return null
  try {
    return new URL(tab.url).origin === registeredOrigin ? tab.url : null
  } catch {
    return null
  }
}
