import { startPageStyleController } from '@/inject/shared/page-style-controller'
import { darkTheme } from './theme/darken'

const STYLE_ELEMENT_ID = 'tsuki-bilibili-theme'
const systemTheme = window.matchMedia('(prefers-color-scheme: dark)')
let pageEnabled = false

function syncStyle() {
  const existingStyle = document.getElementById(STYLE_ELEMENT_ID)
  if (!pageEnabled || !systemTheme.matches) {
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
