import React from 'react'
import { useStateValue } from '@guanghechen/react-viewmodel'
import { useSiteViewmodel } from '@/context/site'
import { contrastRatio, readableColor } from '@/shared/whiteboard/colors'
import type { IWhiteboardTheme } from '../theme'

export function readWhiteboardTheme(): IWhiteboardTheme {
  const css = getComputedStyle(document.documentElement)
  const value = (name: string): string => css.getPropertyValue(name).trim()
  const paper = value('--vscode-surface-background')
  const ink = value('--vscode-foreground')
  const tone = (name: string): string => readableColor(value(name) || ink, paper, ink)
  return {
    tokens: {
      '--wb-canvas': `${value('--vscode-editor-background')}`,
      '--wb-paper': `${value('--vscode-surface-background')}`,
      '--wb-panel': `${value('--vscode-sidebar-background')}`,
      '--wb-popover': `${value('--vscode-popover-background')}`,
      '--wb-input': `${value('--vscode-input-background')}`,
      '--wb-ink': `${value('--vscode-foreground')}`,
      '--wb-muted': `${value('--vscode-muted-foreground')}`,
      '--wb-border': `${value('--vscode-border')}`,
      '--wb-control-border': `${value('--vscode-control-border')}`,
      '--wb-accent': `${value('--vscode-accent')}`,
      '--wb-focus': `${value('--vscode-focus-border')}`,
      '--wb-hover': `${value('--vscode-list-hover-background')}`,
      '--wb-selected': `${value('--vscode-list-active-background')}`,
      '--wb-selected-ink': `${value('--vscode-link')}`,
      '--wb-shadow': `${value('--vscode-shadow')}`,
      '--wb-grid': `color-mix(in srgb, var(--wb-ink) 20%, transparent)`,
      '--wb-warning': `color-mix(in srgb, ${value('--palette-gold')} 12%, var(--wb-paper))`,
      '--wb-warning-border': `color-mix(in srgb, ${value('--palette-gold')} 45%, var(--wb-border))`,
      '--wb-error': `color-mix(in srgb, ${value('--vscode-error')} 65%, var(--wb-ink))`,
      '--wb-error-bg': `color-mix(in srgb, ${value('--vscode-error')} 12%, var(--wb-paper))`,
    },
    canvas: value('--vscode-editor-background'),
    paper,
    ink,
    muted: value('--vscode-muted-foreground'),
    border: value('--vscode-control-border'),
    selection: value('--vscode-focus-border'),
    onAccent: contrastRatio('#ffffff', value('--vscode-accent')) >= 4.5 ? '#ffffff' : '#111111',
    activeInk: readableColor(value('--vscode-link'), value('--vscode-list-active-background'), ink),
    colors: {
      'theme:ink': ink,
      'theme:paper': paper,
      'theme:accent': tone('--vscode-link'),
      'theme:red': tone('--palette-love'),
      'theme:amber': tone('--palette-gold'),
      'theme:green': tone('--palette-pine'),
      'theme:blue': tone('--palette-foam'),
      'theme:purple': tone('--palette-iris'),
    },
  }
}

export function useWhiteboardTheme() {
  const site = useSiteViewmodel()
  const mode = useStateValue(site.theme$)
  const palette = useStateValue(site.palette$)
  const [theme, setTheme] = React.useState(readWhiteboardTheme)
  const [ready, setReady] = React.useState(false)
  React.useLayoutEffect(() => {
    // SiteContextProvider applies root variables in a sibling layout effect.
    const frame = requestAnimationFrame(() => {
      setTheme(readWhiteboardTheme())
      setReady(true)
    })
    return () => cancelAnimationFrame(frame)
  }, [mode, palette])
  return { theme, ready }
}
