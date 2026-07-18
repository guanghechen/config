import { vscodeLightModernTheme } from '@/shared/theme/vscode-light-modern'
import type { IWebsiteTheme } from '@/shared/theme/contract'
import { codeforcesStyles } from '../styles'
import { codeforcesTokens } from './tokens'

export const codeforcesVscodeLightModernTheme: IWebsiteTheme = {
  id: vscodeLightModernTheme.id,
  kind: vscodeLightModernTheme.kind,
  css: `${codeforcesTokens}\n${codeforcesStyles}`,
}
