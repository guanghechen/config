import React from 'react'
import { useStateValue } from '@guanghechen/react-viewmodel'
import { useSiteViewmodel } from '@/context/site'
import { contrastRatio, readableColor } from '@/shared/whiteboard/colors'
import type { IThemeColors } from '@/shared/whiteboard/colors'

export interface IWhiteboardTheme {
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

export function readWhiteboardTheme(): IWhiteboardTheme {
  const css = getComputedStyle(document.documentElement)
  const value = (name: string): string => css.getPropertyValue(name).trim()
  const paper = value('--vscode-surface-background')
  const ink = value('--vscode-foreground')
  const tone = (name: string): string => readableColor(value(name) || ink, paper, ink)
  return {
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
