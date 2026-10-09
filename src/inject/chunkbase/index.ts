import { startPageStyle } from '@/shared/page-style'
import { suppressCoordinateAutofill } from './coordinate-autofill'
import { layoutTheme } from './theme/layout'

if (/^\/apps\/seed-map\/?$/.test(window.location.pathname)) {
  startLayout()

  window.addEventListener('pageshow', event => {
    if (event.persisted) startLayout()
  })
}

function startLayout(): void {
  let stopCoordinateAutofill: (() => void) | undefined
  const stopPageStyle = startPageStyle({
    layoutCss: layoutTheme,
    themes: [],
    onEnabledChange: enabled => {
      stopCoordinateAutofill?.()
      stopCoordinateAutofill = enabled ? suppressCoordinateAutofill() : undefined
    },
  })
  window.addEventListener('pagehide', stopPageStyle, { once: true })
}
