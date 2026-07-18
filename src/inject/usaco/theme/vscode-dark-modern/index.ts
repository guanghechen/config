import { vscodeDarkModernTheme } from '@/shared/theme/vscode-dark-modern'
import type { IWebsiteTheme } from '@/shared/theme/contract'
import { usacoStyles } from '../styles'
import { usacoTokens } from './tokens'

export const usacoVscodeDarkModernTheme: IWebsiteTheme = {
  id: vscodeDarkModernTheme.id,
  kind: vscodeDarkModernTheme.kind,
  css: `${usacoTokens}\n${usacoStyles}`,
}
