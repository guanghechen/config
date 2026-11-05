import { createGenericAgentAdapter } from '@/agent/adapter/generic'
import { startAgentPage } from '@/agent/content/runtime'
import { startPageStyle } from '@/shared/page-style'
import { usacoThemes } from './theme'
import { layoutTheme } from './theme/layout'

const stopAgentPage = startAgentPage(createGenericAgentAdapter('usaco'))
const stopPageStyle = startPageStyle({
  layoutCss: layoutTheme,
  themes: usacoThemes,
})

window.addEventListener(
  'pagehide',
  () => {
    stopAgentPage()
    stopPageStyle()
  },
  { once: true },
)
