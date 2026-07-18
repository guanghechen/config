import type { IWebsiteTheme } from '@/shared/theme/contract'
import { redditVscodeDarkModernTheme } from './vscode-dark-modern'
import { redditVscodeLightModernTheme } from './vscode-light-modern'

export const redditThemes: ReadonlyArray<IWebsiteTheme> = [
  redditVscodeLightModernTheme,
  redditVscodeDarkModernTheme,
]
