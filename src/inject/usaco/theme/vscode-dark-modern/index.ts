import type { IWebsiteTheme } from '@/shared/theme/contract'
import { vscodeDarkModernTheme } from '@/shared/theme/vscode-dark-modern'
import { usacoStyles } from '../styles'
import { usacoTokens } from './tokens'

export const usacoVscodeDarkModernTheme: IWebsiteTheme = {
  id: vscodeDarkModernTheme.id,
  kind: vscodeDarkModernTheme.kind,
  css: `${usacoTokens}\n${usacoStyles}`,
}
