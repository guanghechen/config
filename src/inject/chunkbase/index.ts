import { startPageStyle } from '@/shared/page-style'
import { layoutTheme } from './theme/layout'

if (/^\/apps\/seed-map\/?$/.test(window.location.pathname)) {
  startLayout()

  window.addEventListener('pageshow', event => {
    if (event.persisted) startLayout()
  })
}

function startLayout(): void {
  const stopPageStyle = startPageStyle({ layoutCss: layoutTheme, themes: [] })
  window.addEventListener('pagehide', stopPageStyle, { once: true })
}
