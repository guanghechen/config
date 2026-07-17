import { startPageStyleController } from '@/inject/shared/page-style-controller'
import { darkTheme } from './theme/darken'

const STYLE_ELEMENT_ID = 'tsuki-reddit-theme'
const systemTheme = window.matchMedia('(prefers-color-scheme: dark)')
const initialThemeClasses = {
  dark: document.documentElement.classList.contains('theme-dark'),
  light: document.documentElement.classList.contains('theme-light'),
}
let pageEnabled = false

function syncStyle() {
  const htmlElement = document.documentElement
  const existingStyle = document.getElementById(STYLE_ELEMENT_ID)

  if (!pageEnabled) {
    htmlElement.classList.toggle('theme-dark', initialThemeClasses.dark)
    htmlElement.classList.toggle('theme-light', initialThemeClasses.light)
    existingStyle?.remove()
    return
  }

  htmlElement.classList.toggle('theme-dark', systemTheme.matches)
  htmlElement.classList.toggle('theme-light', !systemTheme.matches)

  if (!systemTheme.matches) {
    existingStyle?.remove()
    return
  }

  if (existingStyle) return
  const styleElement = document.createElement('style')
  styleElement.id = STYLE_ELEMENT_ID
  styleElement.textContent = darkTheme
  ;(document.head ?? document.documentElement).appendChild(styleElement)
}

const stopPageStyleController = startPageStyleController({
  setEnabled: enabled => {
    pageEnabled = enabled
    syncStyle()
  },
})

const handleSystemThemeChange = () => syncStyle()
systemTheme.addEventListener('change', handleSystemThemeChange)

window.addEventListener(
  'pagehide',
  () => {
    stopPageStyleController()
    systemTheme.removeEventListener('change', handleSystemThemeChange)
  },
  { once: true },
)
