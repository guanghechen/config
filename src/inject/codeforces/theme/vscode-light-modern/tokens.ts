import { vscodeLightModernPalette as palette } from '@/shared/theme/vscode-light-modern/palette'

export const codeforcesTokens: string = `
  :root {
    --tsuki-cf-page: ${palette.page};
    --tsuki-cf-surface: ${palette.surface};
    --tsuki-cf-surface-muted: ${palette.surfaceMuted};
    --tsuki-cf-surface-hover: ${palette.surfaceHover};
    --tsuki-cf-border: ${palette.border};
    --tsuki-cf-text: ${palette.text};
    --tsuki-cf-text-muted: ${palette.textMuted};
    --tsuki-cf-link: ${palette.link};
    --tsuki-cf-link-hover: ${palette.linkHover};
    --tsuki-cf-link-visited: ${palette.linkVisited};
    --tsuki-cf-accent: ${palette.accent};
    --tsuki-cf-accent-soft: ${palette.accentSoft};
    --tsuki-cf-focus: ${palette.focus};
    --tsuki-cf-code: ${palette.code};
    --tsuki-cf-code-text: ${palette.codeText};
    --tsuki-cf-input: ${palette.input};
    --tsuki-cf-button: ${palette.button};
    --tsuki-cf-button-hover: ${palette.buttonHover};
    --tsuki-cf-button-active: ${palette.buttonActive};
    --tsuki-cf-button-text: ${palette.buttonText};
    --tsuki-cf-selection: ${palette.selection};
    --tsuki-cf-selection-text: ${palette.selectionText};
    --tsuki-cf-success: ${palette.success};
    --tsuki-cf-success-surface: ${palette.successSurface};
    --tsuki-cf-warning: ${palette.warning};
    --tsuki-cf-warning-surface: ${palette.warningSurface};
    --tsuki-cf-danger: ${palette.danger};
    --tsuki-cf-danger-surface: ${palette.dangerSurface};
    --tsuki-cf-info: ${palette.info};
    --tsuki-cf-info-surface: ${palette.infoSurface};
    --tsuki-cf-syntax-keyword: ${palette.syntaxKeyword};
    --tsuki-cf-syntax-string: ${palette.syntaxString};
    --tsuki-cf-syntax-comment: ${palette.syntaxComment};
    --tsuki-cf-syntax-number: ${palette.syntaxNumber};
    --tsuki-cf-syntax-type: ${palette.syntaxType};
    --tsuki-cf-syntax-function: ${palette.syntaxFunction};
    --tsuki-cf-user-legendary: ${palette.danger};
    --tsuki-cf-user-first-letter: ${palette.text};
    --tsuki-cf-user-orange: ${palette.warning};
    --tsuki-cf-user-violet: ${palette.syntaxKeyword};
    --tsuki-cf-user-blue: ${palette.info};
    --tsuki-cf-user-cyan: ${palette.syntaxType};
    --tsuki-cf-user-green: ${palette.success};
    --tsuki-cf-user-gray: ${palette.textMuted};
    --tsuki-cf-logo-filter: none;
    --tsuki-cf-formula-filter: none;
    color-scheme: ${palette.kind};
  }
`.trim()
