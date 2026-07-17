import { darkTheme } from './theme/darken'
import { layoutTheme } from './theme/layout'

const STYLE_ELEMENT_ID = 'tsuki-usaco-theme'

if (!document.getElementById(STYLE_ELEMENT_ID)) {
  const styleElement = document.createElement('style')
  styleElement.id = STYLE_ELEMENT_ID
  styleElement.textContent = `${layoutTheme}\n${darkTheme}`
  ;(document.head ?? document.documentElement).appendChild(styleElement)
}
