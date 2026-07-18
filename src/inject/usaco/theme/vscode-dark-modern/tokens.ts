import { vscodeDarkModernPalette as palette } from '@/shared/theme/vscode-dark-modern/palette'

export const usacoTokens: string = `
  :root {
    --tsuki-usaco-page: ${palette.page};
    --tsuki-usaco-surface: ${palette.surface};
    --tsuki-usaco-surface-muted: ${palette.surfaceMuted};
    --tsuki-usaco-surface-hover: ${palette.surfaceHover};
    --tsuki-usaco-text: ${palette.text};
    --tsuki-usaco-text-muted: ${palette.textMuted};
    --tsuki-usaco-border: ${palette.border};
    --tsuki-usaco-link: ${palette.link};
    --tsuki-usaco-link-hover: ${palette.linkHover};
    --tsuki-usaco-link-visited: ${palette.linkVisited};
    --tsuki-usaco-focus: ${palette.focus};
    --tsuki-usaco-input: ${palette.input};
    --tsuki-usaco-button: ${palette.button};
    --tsuki-usaco-button-hover: ${palette.buttonHover};
    --tsuki-usaco-button-active: ${palette.buttonActive};
    --tsuki-usaco-button-text: ${palette.buttonText};
    --tsuki-usaco-code: ${palette.code};
    --tsuki-usaco-danger: ${palette.danger};
    --tsuki-usaco-selection: ${palette.selection};
    --tsuki-usaco-selection-text: ${palette.selectionText};
    --tsuki-usaco-image-filter: brightness(0.82) contrast(1.05);
    color-scheme: ${palette.kind};
  }
`.trim()
