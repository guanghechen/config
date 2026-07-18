import { vscodeLightModernTheme } from '@/shared/theme/vscode-light-modern'
import type { IWebsiteTheme } from '@/shared/theme/contract'
import { redditStyles } from '../styles'
import { redditTokens } from './tokens'

export const redditVscodeLightModernTheme: IWebsiteTheme = {
  id: vscodeLightModernTheme.id,
  kind: vscodeLightModernTheme.kind,
  css: `${redditTokens}\n${redditStyles}`,
}
