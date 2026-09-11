import type { IStyle } from './model.ts'

export const THEME_COLORS = [
  'theme:ink',
  'theme:paper',
  'theme:accent',
  'theme:red',
  'theme:amber',
  'theme:green',
  'theme:blue',
  'theme:purple',
] as const
export type IThemeColor = (typeof THEME_COLORS)[number]
export type IThemeColors = Readonly<Record<IThemeColor, string>>
const themeColors = new Set<string>(THEME_COLORS)

export function isThemeColor(color: unknown): color is IThemeColor {
  return typeof color === 'string' && themeColors.has(color)
}

function channels(color: string): number[] {
  return [1, 3, 5].map(index => Number.parseInt(color.slice(index, index + 2), 16))
}

export function mixColor(color: string, background: string, weight: number): string {
  const base = channels(background)
  return (
    '#' +
    channels(color)
      .map((channel, index) =>
        Math.round(channel * weight + base[index] * (1 - weight))
          .toString(16)
          .padStart(2, '0'),
      )
      .join('')
  )
}

export function contrastRatio(a: string, b: string): number {
  const luminance = (color: string): number => {
    const rgb = channels(color).map(channel => {
      const value = channel / 255
      return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4
    })
    return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722
  }
  const first = luminance(a),
    second = luminance(b)
  return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05)
}

export function readableColor(color: string, background: string, ink: string): string {
  if (contrastRatio(color, background) >= 4.5) return color
  const target =
    contrastRatio(ink, background) >= 4.5
      ? ink
      : contrastRatio('#111111', background) > contrastRatio('#ffffff', background)
        ? '#111111'
        : '#ffffff'
  for (let step = 1; step <= 20; step++) {
    const adjusted = mixColor(target, color, step / 20)
    if (contrastRatio(adjusted, background) >= 4.5) return adjusted
  }
  return target
}

export function resolveColor(color: string, colors: IThemeColors): string {
  return isThemeColor(color) ? colors[color] : color
}

export function resolveStyle(style: IStyle, colors: IThemeColors, filled = false): IStyle {
  let fill = resolveColor(style.fill, colors)
  let stroke = resolveColor(style.stroke, colors)
  const solid = !style.fillPattern || style.fillPattern === 'solid'
  if (solid && isThemeColor(style.fill) && !['theme:paper', 'theme:ink'].includes(style.fill))
    fill = mixColor(fill, colors['theme:paper'], 0.14)
  if (isThemeColor(style.stroke))
    stroke = readableColor(
      stroke,
      filled && solid && fill !== 'transparent' ? fill : colors['theme:paper'],
      colors['theme:ink'],
    )
  return stroke === style.stroke && fill === style.fill ? style : { ...style, stroke, fill }
}
