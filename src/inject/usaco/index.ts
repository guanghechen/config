import { startPageStyle } from '@/shared/page-style'
import { layoutTheme } from './theme/layout'
import { usacoThemes } from './theme'

const stopPageStyle = startPageStyle({
  layoutCss: layoutTheme,
  themes: usacoThemes,
})

window.addEventListener('pagehide', stopPageStyle, { once: true })
