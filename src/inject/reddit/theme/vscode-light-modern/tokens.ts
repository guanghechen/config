import { vscodeLightModernPalette as palette } from '@/shared/theme/vscode-light-modern/palette'

export const redditTokens: string = `
  :root {
    --tsuki-reddit-page: ${palette.page};
    --tsuki-reddit-surface: ${palette.surface};
    --tsuki-reddit-surface-muted: ${palette.surfaceMuted};
    --tsuki-reddit-surface-hover: ${palette.surfaceHover};
    --tsuki-reddit-border: ${palette.border};
    --tsuki-reddit-text: ${palette.text};
    --tsuki-reddit-text-muted: ${palette.textMuted};
    --tsuki-reddit-link: ${palette.link};
    --tsuki-reddit-link-hover: ${palette.linkHover};
    --tsuki-reddit-link-visited: ${palette.linkVisited};
    --tsuki-reddit-focus: ${palette.focus};
    --tsuki-reddit-input: ${palette.input};
    --tsuki-reddit-button: ${palette.button};
    --tsuki-reddit-button-hover: ${palette.buttonHover};
    --tsuki-reddit-button-active: ${palette.buttonActive};
    --tsuki-reddit-button-text: ${palette.buttonText};
    --tsuki-reddit-arrow-filter: none;
    color-scheme: ${palette.kind};
  }
`.trim()
