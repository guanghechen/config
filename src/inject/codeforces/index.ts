import { startPageStyleController } from '@/inject/shared/page-style-controller'
import {
  DEFAULT_THEME_PREFERENCE,
  readThemePreference,
  subscribeThemePreference,
  type ThemePreference,
} from '@/shared/setting/theme-preference'
import { darkTheme } from './theme/darken'

const STYLE_ELEMENT_ID = 'tsuki-codeforces-theme'

const systemTheme = window.matchMedia('(prefers-color-scheme: dark)')
let pageEnabled = false
let themePreference = DEFAULT_THEME_PREFERENCE
let storageRevision = 0

function syncStyle() {
  const useDarkTheme =
    pageEnabled &&
    (themePreference === 'dark' || (themePreference === 'system' && systemTheme.matches))
  const existingStyle = document.getElementById(STYLE_ELEMENT_ID)

  if (!useDarkTheme) {
    existingStyle?.remove()
    return
  }

  if (existingStyle) return
  const styleElement = document.createElement('style')
  styleElement.id = STYLE_ELEMENT_ID
  styleElement.textContent = darkTheme
  ;(document.head ?? document.documentElement).appendChild(styleElement)
}

function applyThemePreference(value: ThemePreference) {
  themePreference = value
  syncStyle()
}

const stopPageStyleController = startPageStyleController({
  setEnabled: enabled => {
    pageEnabled = enabled
    syncStyle()
  },
})

const unsubscribeThemePreference = subscribeThemePreference(value => {
  storageRevision += 1
  applyThemePreference(value)
})

const initialStorageRevision = storageRevision
void readThemePreference()
  .then(value => {
    if (storageRevision === initialStorageRevision) applyThemePreference(value)
  })
  .catch(() => applyThemePreference(DEFAULT_THEME_PREFERENCE))

const handleSystemThemeChange = () => syncStyle()
systemTheme.addEventListener('change', handleSystemThemeChange)

window.addEventListener(
  'pagehide',
  () => {
    stopPageStyleController()
    unsubscribeThemePreference()
    systemTheme.removeEventListener('change', handleSystemThemeChange)
  },
  { once: true },
)
