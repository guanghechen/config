import { startPageStyleController } from '@/inject/shared/page-style-controller'
import {
  DEFAULT_THEME_PREFERENCE,
  readThemePreference,
  subscribeThemePreference,
  type ThemePreference,
} from '@/shared/setting/theme-preference'
import { darkTheme } from './theme/darken'
import { layoutTheme } from './theme/layout'

const STYLE_ELEMENT_ID = 'tsuki-usaco-theme'
const THEME_ATTRIBUTE = 'data-tsuki-theme'

const systemTheme = window.matchMedia('(prefers-color-scheme: dark)')
let pageEnabled = false
let themePreference = DEFAULT_THEME_PREFERENCE
let storageRevision = 0

function syncStyle() {
  const existingStyle = document.getElementById(STYLE_ELEMENT_ID)
  if (!pageEnabled) {
    document.documentElement.removeAttribute(THEME_ATTRIBUTE)
    existingStyle?.remove()
    return
  }

  const resolvedTheme =
    themePreference === 'system' ? (systemTheme.matches ? 'dark' : 'light') : themePreference
  document.documentElement.setAttribute(THEME_ATTRIBUTE, resolvedTheme)

  if (existingStyle) return
  const styleElement = document.createElement('style')
  styleElement.id = STYLE_ELEMENT_ID
  styleElement.textContent = `${layoutTheme}\n${darkTheme}`
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
