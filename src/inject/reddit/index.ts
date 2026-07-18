import { startPageStyle } from '@/shared/page-style'
import { redditThemes } from './theme'

const stopPageStyle = startPageStyle({ themes: redditThemes })

window.addEventListener('pagehide', stopPageStyle, { once: true })
