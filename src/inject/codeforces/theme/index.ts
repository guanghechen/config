import type { IWebsiteTheme } from '@/shared/theme/contract'
import { codeforcesVscodeDarkModernTheme } from './vscode-dark-modern'
import { codeforcesVscodeLightModernTheme } from './vscode-light-modern'

export const codeforcesThemes: ReadonlyArray<IWebsiteTheme> = [
  codeforcesVscodeLightModernTheme,
  codeforcesVscodeDarkModernTheme,
]
