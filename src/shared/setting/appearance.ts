import type { ThemeId } from '@/shared/theme/contract'
import { isThemeIdForKind } from '@/shared/theme/registry'

export const APPEARANCE_MODES = ['system', 'light', 'dark'] as const
export type AppearanceMode = (typeof APPEARANCE_MODES)[number]

export interface IAppearanceSettings {
  readonly mode: AppearanceMode
  readonly lightTheme: ThemeId
  readonly darkTheme: ThemeId
}

export const DEFAULT_APPEARANCE_SETTINGS: IAppearanceSettings = {
  mode: 'system',
  lightTheme: 'original',
  darkTheme: 'vscode-dark-modern',
}

const STORAGE_KEY = 'appearance-settings'
const LEGACY_MODE_STORAGE_KEY = 'theme-preference'

export async function readAppearanceSettings(): Promise<IAppearanceSettings> {
  try {
    const storage = resolveChromeStorage()
    if (storage) {
      const values = await storage.get([STORAGE_KEY, LEGACY_MODE_STORAGE_KEY])
      return normalizeAppearanceSettings(values[STORAGE_KEY], values[LEGACY_MODE_STORAGE_KEY])
    }

    return normalizeAppearanceSettings(
      window.localStorage.getItem(STORAGE_KEY),
      window.localStorage.getItem(LEGACY_MODE_STORAGE_KEY),
    )
  } catch (cause) {
    throw createStorageError('Failed to read the appearance settings.', cause)
  }
}

export async function writeAppearanceSettings(settings: IAppearanceSettings): Promise<void> {
  if (!isAppearanceSettings(settings)) {
    throw new RangeError('Unsupported appearance settings.')
  }

  try {
    const storage = resolveChromeStorage()
    if (storage) {
      await storage.set({ [STORAGE_KEY]: settings })
    } else {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(settings))
    }
  } catch (cause) {
    throw createStorageError('Failed to save the appearance settings.', cause)
  }
}

export function subscribeAppearanceSettings(
  onChange: (settings: IAppearanceSettings) => void,
): () => void {
  if (typeof chrome === 'undefined' || !chrome.storage?.onChanged) return () => undefined

  const listener = (changes: Record<string, chrome.storage.StorageChange>, areaName: string) => {
    if (areaName !== 'sync' || !changes[STORAGE_KEY]) return
    onChange(normalizeAppearanceSettings(changes[STORAGE_KEY].newValue))
  }

  chrome.storage.onChanged.addListener(listener)
  return () => chrome.storage.onChanged.removeListener(listener)
}

function normalizeAppearanceSettings(
  rawSettings: unknown,
  legacyMode?: unknown,
): IAppearanceSettings {
  const parsedSettings = parseStoredValue(rawSettings)
  const parsedLegacyMode = parseStoredValue(legacyMode)
  const settings = isRecord(parsedSettings) ? parsedSettings : {}

  return {
    mode: isAppearanceMode(settings.mode)
      ? settings.mode
      : isAppearanceMode(parsedLegacyMode)
        ? parsedLegacyMode
        : DEFAULT_APPEARANCE_SETTINGS.mode,
    lightTheme: isThemeIdForKind(settings.lightTheme, 'light')
      ? settings.lightTheme
      : DEFAULT_APPEARANCE_SETTINGS.lightTheme,
    darkTheme: isThemeIdForKind(settings.darkTheme, 'dark')
      ? settings.darkTheme
      : DEFAULT_APPEARANCE_SETTINGS.darkTheme,
  }
}

function parseStoredValue(value: unknown): unknown {
  if (typeof value !== 'string') return value

  try {
    return JSON.parse(value)
  } catch {
    return value
  }
}

function isAppearanceSettings(value: unknown): value is IAppearanceSettings {
  if (!isRecord(value)) return false
  return (
    isAppearanceMode(value.mode) &&
    isThemeIdForKind(value.lightTheme, 'light') &&
    isThemeIdForKind(value.darkTheme, 'dark')
  )
}

function isAppearanceMode(value: unknown): value is AppearanceMode {
  return typeof value === 'string' && APPEARANCE_MODES.includes(value as AppearanceMode)
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function resolveChromeStorage(): chrome.storage.StorageArea | null {
  if (typeof chrome === 'undefined' || !chrome.storage?.sync) return null
  return chrome.storage.sync
}

function createStorageError(message: string, cause: unknown): Error {
  return Object.assign(new Error(message), { cause })
}
