import { vscodeDarkModernTheme } from '@/shared/theme/vscode-dark-modern'
import type { IWebsiteTheme } from '@/shared/theme/contract'
import { redditStyles } from '../styles'
import { redditTokens } from './tokens'

export const redditVscodeDarkModernTheme: IWebsiteTheme = {
  id: vscodeDarkModernTheme.id,
  kind: vscodeDarkModernTheme.kind,
  css: `${redditTokens}\n${redditStyles}`,
}
