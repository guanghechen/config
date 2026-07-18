import { startPageStyle } from '@/shared/page-style'
import { codeforcesThemes } from './theme'

const stopPageStyle = startPageStyle({ themes: codeforcesThemes })

window.addEventListener('pagehide', stopPageStyle, { once: true })
