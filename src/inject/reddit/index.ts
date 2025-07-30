import { darkTheme } from './theme/darken'

const darken = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
console.log('[tsuki] inject!', { darken })

if (darken) {
  document.addEventListener('DOMContentLoaded', () => {
    const htmlElement = document.documentElement
    htmlElement.classList.remove('theme-light')
    htmlElement.classList.add('theme-dark')

    const darkThemeId: string = 'tsuki-dark-theme'
    if (!document.getElementById(darkThemeId)) {
      const styleElement = document.createElement('style')
      styleElement.id = darkThemeId
      styleElement.textContent = darkTheme
      document.head.appendChild(styleElement)
    }
  })
} else {
  document.addEventListener('DOMContentLoaded', () => {
    const htmlElement = document.documentElement
    htmlElement.classList.remove('theme-dark')
    htmlElement.classList.add('theme-light')

    const darkThemeElement = document.getElementById('tsuki-dark-theme')
    if (darkThemeElement) {
      darkThemeElement.remove()
    }
  })
}
