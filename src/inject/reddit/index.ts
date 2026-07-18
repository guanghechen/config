import { createGenericAgentAdapter } from '@/agent/adapter/generic'
import { startAgentPage } from '@/agent/content/runtime'
import { startPageStyle } from '@/shared/page-style'
import { redditThemes } from './theme'

const stopAgentPage = startAgentPage(createGenericAgentAdapter('reddit'))
const stopPageStyle = startPageStyle({ themes: redditThemes })

window.addEventListener(
  'pagehide',
  () => {
    stopAgentPage()
    stopPageStyle()
  },
  { once: true },
)
