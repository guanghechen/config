import type { IThemeColors } from '@/shared/whiteboard/colors'

export interface IWhiteboardTheme {
  readonly tokens?: Readonly<Record<string, string>>
  readonly canvas: string
  readonly paper: string
  readonly ink: string
  readonly muted: string
  readonly border: string
  readonly selection: string
  readonly onAccent: string
  readonly activeInk: string
  readonly colors: IThemeColors
}

export const DEFAULT_WHITEBOARD_THEME: IWhiteboardTheme = {
  canvas: '#ffffff',
  paper: '#ffffff',
  ink: '#3b3b3b',
  muted: '#666666',
  border: '#cccccc',
  selection: '#0066cc',
  onAccent: '#ffffff',
  activeInk: '#0066cc',
  colors: {
    'theme:ink': '#3b3b3b',
    'theme:paper': '#ffffff',
    'theme:accent': '#0066cc',
    'theme:red': '#b3212d',
    'theme:amber': '#80662c',
    'theme:green': '#297988',
    'theme:blue': '#1763aa',
    'theme:purple': '#5828bd',
  },
  tokens: {
    '--wb-canvas': '#ffffff',
    '--wb-paper': '#ffffff',
    '--wb-panel': '#f8f8f8',
    '--wb-popover': '#ffffff',
    '--wb-input': '#ffffff',
    '--wb-ink': '#3b3b3b',
    '--wb-muted': '#666666',
    '--wb-border': '#e2e2e2',
    '--wb-control-border': '#cccccc',
    '--wb-accent': '#0066cc',
    '--wb-focus': '#0066cc',
    '--wb-hover': '#eeeeee',
    '--wb-selected': '#e7edf6',
    '--wb-selected-ink': '#0066cc',
    '--wb-shadow': '#0000001a',
    '--wb-grid': 'color-mix(in srgb, var(--wb-ink) 20%, transparent)',
    '--wb-warning': 'color-mix(in srgb, #80662c 12%, var(--wb-paper))',
    '--wb-warning-border': 'color-mix(in srgb, #80662c 45%, var(--wb-border))',
    '--wb-error': 'color-mix(in srgb, #c93838 65%, var(--wb-ink))',
    '--wb-error-bg': 'color-mix(in srgb, #c93838 12%, var(--wb-paper))',
  },
}
