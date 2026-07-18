export const THEME_KINDS = ['light', 'dark'] as const
export type ThemeKind = (typeof THEME_KINDS)[number]

export const COLOR_THEME_IDS = ['vscode-light-modern', 'vscode-dark-modern'] as const
export type ColorThemeId = (typeof COLOR_THEME_IDS)[number]
export type ThemeId = 'original' | ColorThemeId

export interface IThemePalette {
  readonly kind: ThemeKind
  readonly page: string
  readonly surface: string
  readonly surfaceMuted: string
  readonly surfaceHover: string
  readonly border: string
  readonly text: string
  readonly textMuted: string
  readonly link: string
  readonly linkHover: string
  readonly linkVisited: string
  readonly accent: string
  readonly accentSoft: string
  readonly focus: string
  readonly code: string
  readonly codeText: string
  readonly input: string
  readonly button: string
  readonly buttonHover: string
  readonly buttonActive: string
  readonly buttonText: string
  readonly selection: string
  readonly selectionText: string
  readonly success: string
  readonly successSurface: string
  readonly warning: string
  readonly warningSurface: string
  readonly danger: string
  readonly dangerSurface: string
  readonly info: string
  readonly infoSurface: string
  readonly syntaxKeyword: string
  readonly syntaxString: string
  readonly syntaxComment: string
  readonly syntaxNumber: string
  readonly syntaxType: string
  readonly syntaxFunction: string
}

export interface IThemeDefinition {
  readonly id: ColorThemeId
  readonly label: string
  readonly kind: ThemeKind
  readonly palette: IThemePalette
}

export interface IThemeOption {
  readonly id: ThemeId
  readonly label: string
}

export interface IWebsiteTheme {
  readonly id: ColorThemeId
  readonly kind: ThemeKind
  readonly css: string
}
