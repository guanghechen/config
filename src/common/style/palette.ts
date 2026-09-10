export type LightPalette = 'vsc-light-modern' | 'rose-pine-dawn'
export type DarkPalette = 'vsc-dark-modern' | 'rose-pine' | 'rose-pine-moon'
export type ColorPalette = LightPalette | DarkPalette

export interface IPaletteColors {
  readonly base: string
  readonly surface: string
  readonly overlay: string
  readonly muted: string
  readonly subtle: string
  readonly text: string
  readonly love: string
  readonly gold: string
  readonly rose: string
  readonly pine: string
  readonly foam: string
  readonly iris: string
  readonly highlightLow: string
  readonly highlightMed: string
  readonly highlightHigh: string
}

export interface IColorPalette<T extends ColorPalette = ColorPalette> {
  readonly id: T
  readonly label: string
  readonly colors: IPaletteColors
}

// Rosé Pine's official base, Moon and Dawn palettes: https://rosepinetheme.com/palette/
export const LIGHT_PALETTES: readonly IColorPalette<LightPalette>[] = [
  {
    id: 'vsc-light-modern',
    label: 'VS Code Light Modern',
    colors: {
      base: '#ffffff',
      surface: '#f8f8f8',
      overlay: '#ffffff',
      muted: '#868686',
      subtle: '#616161',
      text: '#3b3b3b',
      love: '#a31515',
      gold: '#795e26',
      rose: '#a31515',
      pine: '#267f99',
      foam: '#005fb8',
      iris: '#0000ff',
      highlightLow: '#f2f2f2',
      highlightMed: '#e8e8e8',
      highlightHigh: '#cecece',
    },
  },
  {
    id: 'rose-pine-dawn',
    label: 'Rosé Pine Dawn',
    colors: {
      base: '#faf4ed',
      surface: '#fffaf3',
      overlay: '#f2e9e1',
      muted: '#9893a5',
      subtle: '#797593',
      text: '#575279',
      love: '#b4637a',
      gold: '#ea9d34',
      rose: '#d7827e',
      pine: '#286983',
      foam: '#56949f',
      iris: '#907aa9',
      highlightLow: '#f4ede8',
      highlightMed: '#dfdad9',
      highlightHigh: '#cecacd',
    },
  },
]

export const DARK_PALETTES: readonly IColorPalette<DarkPalette>[] = [
  {
    id: 'vsc-dark-modern',
    label: 'VS Code Dark Modern',
    colors: {
      base: '#1f1f1f',
      surface: '#181818',
      overlay: '#1f1f1f',
      muted: '#868686',
      subtle: '#9d9d9d',
      text: '#cccccc',
      love: '#f44747',
      gold: '#dcdcaa',
      rose: '#ce9178',
      pine: '#4ec9b0',
      foam: '#4daafc',
      iris: '#569cd6',
      highlightLow: '#2b2b2b',
      highlightMed: '#313131',
      highlightHigh: '#3c3c3c',
    },
  },
  {
    id: 'rose-pine',
    label: 'Rosé Pine',
    colors: {
      base: '#191724',
      surface: '#1f1d2e',
      overlay: '#26233a',
      muted: '#6e6a86',
      subtle: '#908caa',
      text: '#e0def4',
      love: '#eb6f92',
      gold: '#f6c177',
      rose: '#ebbcba',
      pine: '#31748f',
      foam: '#9ccfd8',
      iris: '#c4a7e7',
      highlightLow: '#21202e',
      highlightMed: '#403d52',
      highlightHigh: '#524f67',
    },
  },
  {
    id: 'rose-pine-moon',
    label: 'Rosé Pine Moon',
    colors: {
      base: '#232136',
      surface: '#2a273f',
      overlay: '#393552',
      muted: '#6e6a86',
      subtle: '#908caa',
      text: '#e0def4',
      love: '#eb6f92',
      gold: '#f6c177',
      rose: '#ea9a97',
      pine: '#3e8fb0',
      foam: '#9ccfd8',
      iris: '#c4a7e7',
      highlightLow: '#2a283e',
      highlightMed: '#44415a',
      highlightHigh: '#56526e',
    },
  },
]
