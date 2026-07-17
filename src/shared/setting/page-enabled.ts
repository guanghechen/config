const STORAGE_KEY = 'disabled-page-origins'

export async function readPageEnabled(url: string): Promise<boolean> {
  const pageKey = resolvePageKey(url)

  try {
    const storage = resolveChromeStorage()
    const value = storage
      ? (await storage.get(STORAGE_KEY))[STORAGE_KEY]
      : window.localStorage.getItem(STORAGE_KEY)
    return !normalizeDisabledPageKeys(value).has(pageKey)
  } catch (cause) {
    throw createStorageError('Failed to read the page setting.', cause)
  }
}

export async function writePageEnabled(url: string, enabled: boolean): Promise<void> {
  const pageKey = resolvePageKey(url)

  try {
    const storage = resolveChromeStorage()
    const storedValue = storage
      ? (await storage.get(STORAGE_KEY))[STORAGE_KEY]
      : window.localStorage.getItem(STORAGE_KEY)
    const disabledPageKeys = normalizeDisabledPageKeys(storedValue)

    if (enabled) disabledPageKeys.delete(pageKey)
    else disabledPageKeys.add(pageKey)

    const nextValue = [...disabledPageKeys].sort()
    if (storage) {
      await storage.set({ [STORAGE_KEY]: nextValue })
    } else {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(nextValue))
    }
  } catch (cause) {
    throw createStorageError('Failed to save the page setting.', cause)
  }
}

export function subscribePageEnabled(
  url: string,
  onChange: (enabled: boolean) => void,
): () => void {
  const pageKey = resolvePageKey(url)
  if (typeof chrome === 'undefined' || !chrome.storage?.onChanged) return () => undefined

  const listener = (changes: Record<string, chrome.storage.StorageChange>, areaName: string) => {
    if (areaName !== 'sync' || !changes[STORAGE_KEY]) return
    onChange(!normalizeDisabledPageKeys(changes[STORAGE_KEY].newValue).has(pageKey))
  }

  chrome.storage.onChanged.addListener(listener)
  return () => chrome.storage.onChanged.removeListener(listener)
}

function resolvePageKey(url: string): string {
  try {
    const parsedUrl = new URL(url)
    if (parsedUrl.protocol !== 'http:' && parsedUrl.protocol !== 'https:') throw new Error()
    return parsedUrl.origin
  } catch {
    throw new RangeError(`Unsupported page URL: ${url}`)
  }
}

function normalizeDisabledPageKeys(value: unknown): Set<string> {
  if (typeof value === 'string') {
    try {
      return normalizeDisabledPageKeys(JSON.parse(value))
    } catch {
      return new Set()
    }
  }

  if (!Array.isArray(value)) return new Set()
  return new Set(value.filter((entry): entry is string => typeof entry === 'string'))
}

function resolveChromeStorage(): chrome.storage.StorageArea | null {
  if (typeof chrome === 'undefined' || !chrome.storage?.sync) return null
  return chrome.storage.sync
}

function createStorageError(message: string, cause: unknown): Error {
  return Object.assign(new Error(message), { cause })
}
