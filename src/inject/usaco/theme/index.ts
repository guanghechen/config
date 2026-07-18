import type { IWebsiteTheme } from '@/shared/theme/contract'
import { usacoVscodeDarkModernTheme } from './vscode-dark-modern'
import { usacoVscodeLightModernTheme } from './vscode-light-modern'

export const usacoThemes: ReadonlyArray<IWebsiteTheme> = [
  usacoVscodeLightModernTheme,
  usacoVscodeDarkModernTheme,
]
