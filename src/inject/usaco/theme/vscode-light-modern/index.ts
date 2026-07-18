import { vscodeLightModernTheme } from '@/shared/theme/vscode-light-modern'
import type { IWebsiteTheme } from '@/shared/theme/contract'
import { usacoStyles } from '../styles'
import { usacoTokens } from './tokens'

export const usacoVscodeLightModernTheme: IWebsiteTheme = {
  id: vscodeLightModernTheme.id,
  kind: vscodeLightModernTheme.kind,
  css: `${usacoTokens}\n${usacoStyles}`,
}
