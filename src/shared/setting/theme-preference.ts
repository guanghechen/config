export const THEME_PREFERENCES = ['system', 'light', 'dark'] as const
export type ThemePreference = (typeof THEME_PREFERENCES)[number]

export const DEFAULT_THEME_PREFERENCE: ThemePreference = 'system'

const STORAGE_KEY = 'theme-preference'

export async function readThemePreference(): Promise<ThemePreference> {
  try {
    const storage = resolveChromeStorage()
    const value = storage
      ? (await storage.get(STORAGE_KEY))[STORAGE_KEY]
      : window.localStorage.getItem(STORAGE_KEY)
    return isThemePreference(value) ? value : DEFAULT_THEME_PREFERENCE
  } catch (cause) {
    throw createStorageError('Failed to read the theme preference.', cause)
  }
}

export async function writeThemePreference(value: ThemePreference): Promise<void> {
  if (!isThemePreference(value)) {
    throw new RangeError(`Unsupported theme preference: ${String(value)}`)
  }

  try {
    const storage = resolveChromeStorage()
    if (storage) {
      await storage.set({ [STORAGE_KEY]: value })
    } else {
      window.localStorage.setItem(STORAGE_KEY, value)
    }
  } catch (cause) {
    throw createStorageError('Failed to save the theme preference.', cause)
  }
}

export function subscribeThemePreference(onChange: (value: ThemePreference) => void): () => void {
  if (typeof chrome === 'undefined' || !chrome.storage?.onChanged) return () => undefined

  const listener = (changes: Record<string, chrome.storage.StorageChange>, areaName: string) => {
    if (areaName !== 'sync' || !changes[STORAGE_KEY]) return

    const value = changes[STORAGE_KEY].newValue
    onChange(isThemePreference(value) ? value : DEFAULT_THEME_PREFERENCE)
  }

  chrome.storage.onChanged.addListener(listener)
  return () => chrome.storage.onChanged.removeListener(listener)
}

function isThemePreference(value: unknown): value is ThemePreference {
  return typeof value === 'string' && THEME_PREFERENCES.includes(value as ThemePreference)
}

function resolveChromeStorage(): chrome.storage.StorageArea | null {
  if (typeof chrome === 'undefined' || !chrome.storage?.sync) return null
  return chrome.storage.sync
}

function createStorageError(message: string, cause: unknown): Error {
  return Object.assign(new Error(message), { cause })
}
