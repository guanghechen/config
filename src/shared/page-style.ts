import { TsukiContentEventNameEnum } from '@/shared/enum/event'
import {
  DEFAULT_APPEARANCE_SETTINGS,
  readAppearanceSettings,
  subscribeAppearanceSettings,
  type IAppearanceSettings,
} from '@/shared/setting/appearance'
import { readPageEnabled, subscribePageEnabled } from '@/shared/setting/page-enabled'
import type { ColorThemeId, IWebsiteTheme, ThemeKind } from '@/shared/theme/contract'
import { getThemeDefinition } from '@/shared/theme/registry'
import type { ITsukiPageStatusResponse } from '@/shared/types/event'

interface IPageStyleOptions {
  readonly layoutCss?: string
  readonly themes: ReadonlyArray<IWebsiteTheme>
}

const LAYOUT_STYLE_ELEMENT_ID = 'tsuki-page-layout'
const THEME_STYLE_ELEMENT_ID = 'tsuki-page-theme'

export function startPageStyle(options: IPageStyleOptions): () => void {
  const systemTheme = window.matchMedia('(prefers-color-scheme: dark)')
  const themes = indexThemes(options.themes)
  const layoutCss = options.layoutCss?.trim() ?? ''

  let appearanceSettings = DEFAULT_APPEARANCE_SETTINGS
  let appearanceStorageRevision = 0
  let disposed = false
  let enabled: boolean | null = null
  let pageStorageRevision = 0

  let markReady: () => void = () => undefined
  const ready = new Promise<void>(resolve => {
    markReady = resolve
  })

  const syncStyle = () => {
    if (disposed) return

    if (enabled !== true) {
      removeStyleElement(LAYOUT_STYLE_ELEMENT_ID)
      removeStyleElement(THEME_STYLE_ELEMENT_ID)
      return
    }

    safelyUpdateStyleElement(LAYOUT_STYLE_ELEMENT_ID, layoutCss)

    const kind = resolveThemeKind(appearanceSettings, systemTheme.matches)
    const themeId = kind === 'light' ? appearanceSettings.lightTheme : appearanceSettings.darkTheme
    const theme = resolveWebsiteTheme(themes, themeId, kind)
    safelyUpdateStyleElement(THEME_STYLE_ELEMENT_ID, theme?.css ?? '', theme?.id)
  }

  const updateEnabled = (nextValue: boolean) => {
    if (disposed || nextValue === enabled) return
    enabled = nextValue
    syncStyle()
  }

  const updateAppearanceSettings = (nextValue: IAppearanceSettings) => {
    if (disposed) return
    appearanceSettings = nextValue
    syncStyle()
  }

  const unsubscribePageEnabled = subscribePageEnabled(window.location.href, nextValue => {
    pageStorageRevision += 1
    updateEnabled(nextValue)
  })
  const unsubscribeAppearanceSettings = subscribeAppearanceSettings(nextValue => {
    appearanceStorageRevision += 1
    updateAppearanceSettings(nextValue)
  })

  const initialPageStorageRevision = pageStorageRevision
  const pageReady = readPageEnabled(window.location.href)
    .then(value => {
      if (pageStorageRevision === initialPageStorageRevision) updateEnabled(value)
    })
    .catch(() => {
      if (pageStorageRevision === initialPageStorageRevision) updateEnabled(true)
    })

  const initialAppearanceStorageRevision = appearanceStorageRevision
  const appearanceReady = readAppearanceSettings()
    .then(value => {
      if (appearanceStorageRevision === initialAppearanceStorageRevision) {
        updateAppearanceSettings(value)
      }
    })
    .catch(() => {
      if (appearanceStorageRevision === initialAppearanceStorageRevision) {
        updateAppearanceSettings(DEFAULT_APPEARANCE_SETTINGS)
      }
    })

  void Promise.allSettled([pageReady, appearanceReady]).then(markReady)

  const handleMessage = (
    message: unknown,
    _sender: chrome.runtime.MessageSender,
    sendResponse: (response: ITsukiPageStatusResponse) => void,
  ): boolean | undefined => {
    if (!isPageStatusRequest(message)) return undefined

    void ready.then(() => {
      sendResponse({ enabled: enabled ?? true, supported: true })
    })
    return true
  }

  const handleSystemThemeChange = () => syncStyle()
  chrome.runtime.onMessage.addListener(handleMessage)
  systemTheme.addEventListener('change', handleSystemThemeChange)

  return () => {
    if (disposed) return
    disposed = true
    unsubscribePageEnabled()
    unsubscribeAppearanceSettings()
    chrome.runtime.onMessage.removeListener(handleMessage)
    systemTheme.removeEventListener('change', handleSystemThemeChange)
    removeStyleElement(LAYOUT_STYLE_ELEMENT_ID)
    removeStyleElement(THEME_STYLE_ELEMENT_ID)
  }
}

function indexThemes(
  themes: ReadonlyArray<IWebsiteTheme>,
): ReadonlyMap<ColorThemeId, IWebsiteTheme> {
  const result = new Map<ColorThemeId, IWebsiteTheme>()

  for (const theme of themes) {
    const definition = getThemeDefinition(theme.id)
    if (!definition || definition.kind !== theme.kind || result.has(theme.id)) continue
    result.set(theme.id, theme)
  }

  return result
}

function resolveThemeKind(settings: IAppearanceSettings, systemDark: boolean): ThemeKind {
  if (settings.mode === 'system') return systemDark ? 'dark' : 'light'
  return settings.mode
}

function resolveWebsiteTheme(
  themes: ReadonlyMap<ColorThemeId, IWebsiteTheme>,
  themeId: IAppearanceSettings['lightTheme'] | IAppearanceSettings['darkTheme'],
  kind: ThemeKind,
): IWebsiteTheme | null {
  if (themeId === 'original') return null

  const definition = getThemeDefinition(themeId)
  if (!definition || definition.kind !== kind) return null

  const theme = themes.get(themeId)
  return theme?.kind === kind ? theme : null
}

function safelyUpdateStyleElement(id: string, css: string, themeId?: ColorThemeId): void {
  try {
    updateStyleElement(id, css, themeId)
  } catch {
    removeStyleElement(id)
  }
}

function updateStyleElement(id: string, css: string, themeId?: ColorThemeId): void {
  const existingStyle = document.getElementById(id) as HTMLStyleElement | null
  if (!css) {
    existingStyle?.remove()
    return
  }

  const styleElement = existingStyle ?? document.createElement('style')
  if (styleElement.textContent !== css) styleElement.textContent = css
  if (themeId) styleElement.dataset.themeId = themeId
  else delete styleElement.dataset.themeId

  if (!existingStyle) {
    styleElement.id = id
    ;(document.head ?? document.documentElement).appendChild(styleElement)
  }
}

function removeStyleElement(id: string): void {
  document.getElementById(id)?.remove()
}

function isPageStatusRequest(message: unknown): boolean {
  if (!message || typeof message !== 'object') return false
  return (message as { event?: unknown }).event === TsukiContentEventNameEnum.PAGE_STATUS
}
