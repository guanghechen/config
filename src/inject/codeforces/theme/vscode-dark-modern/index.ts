import { vscodeDarkModernTheme } from '@/shared/theme/vscode-dark-modern'
import type { IWebsiteTheme } from '@/shared/theme/contract'
import { codeforcesStyles } from '../styles'
import { codeforcesTokens } from './tokens'

export const codeforcesVscodeDarkModernTheme: IWebsiteTheme = {
  id: vscodeDarkModernTheme.id,
  kind: vscodeDarkModernTheme.kind,
  css: `${codeforcesTokens}\n${codeforcesStyles}`,
}
