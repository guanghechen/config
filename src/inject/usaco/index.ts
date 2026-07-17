import { darkTheme } from './theme/darken'
import { layoutTheme } from './theme/layout'
import {
  DEFAULT_THEME_PREFERENCE,
  readThemePreference,
  subscribeThemePreference,
  type ThemePreference,
} from '@/shared/setting/theme-preference'

const STYLE_ELEMENT_ID = 'tsuki-usaco-theme'
const THEME_ATTRIBUTE = 'data-tsuki-theme'

const systemTheme = window.matchMedia('(prefers-color-scheme: dark)')
let themePreference = DEFAULT_THEME_PREFERENCE
let storageRevision = 0

function applyThemePreference(value: ThemePreference) {
  themePreference = value
  const resolvedTheme = value === 'system' ? (systemTheme.matches ? 'dark' : 'light') : value
  document.documentElement.setAttribute(THEME_ATTRIBUTE, resolvedTheme)
}

function handleSystemThemeChange() {
  if (themePreference === 'system') applyThemePreference(themePreference)
}

applyThemePreference(DEFAULT_THEME_PREFERENCE)

if (!document.getElementById(STYLE_ELEMENT_ID)) {
  const styleElement = document.createElement('style')
  styleElement.id = STYLE_ELEMENT_ID
  styleElement.textContent = `${layoutTheme}\n${darkTheme}`
  ;(document.head ?? document.documentElement).appendChild(styleElement)
}

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

systemTheme.addEventListener('change', handleSystemThemeChange)
window.addEventListener(
  'pagehide',
  () => {
    unsubscribeThemePreference()
    systemTheme.removeEventListener('change', handleSystemThemeChange)
  },
  { once: true },
)
