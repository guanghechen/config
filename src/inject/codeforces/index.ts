import { codeforcesAgentAdapter } from '@/agent/adapter/codeforces'
import { startAgentPage } from '@/agent/content/runtime'
import { startPageStyle } from '@/shared/page-style'
import { codeforcesThemes } from './theme'

const stopAgentPage = startAgentPage(codeforcesAgentAdapter)
const stopPageStyle = startPageStyle({ themes: codeforcesThemes })

window.addEventListener(
  'pagehide',
  () => {
    stopAgentPage()
    stopPageStyle()
  },
  { once: true },
)
