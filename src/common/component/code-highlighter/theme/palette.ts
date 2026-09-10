import { type ColorPalette, DARK_PALETTES, LIGHT_PALETTES } from '@/common/style/palette'
import type { IPrismThemeScheme } from '../types'
import { vscDarkModernTheme } from './vsc-dark-modern'
import { vscLightModernTheme } from './vsc-light-modern'

const schemes = new Map<ColorPalette, IPrismThemeScheme>([
  ['vsc-dark-modern', vscDarkModernTheme],
  ['vsc-light-modern', vscLightModernTheme],
])
for (const { id, colors } of [...LIGHT_PALETTES, ...DARK_PALETTES]) {
  if (schemes.has(id)) continue
  schemes.set(id, {
    plain: { color: colors.text, backgroundColor: colors.base },
    styles: [
      { types: ['comment', 'prolog', 'doctype', 'cdata'], style: { color: colors.muted } },
      { types: ['punctuation'], style: { color: colors.subtle } },
      { types: ['keyword', 'operator', 'tag'], style: { color: colors.pine } },
      { types: ['string', 'char', 'attr-value'], style: { color: colors.gold } },
      { types: ['number', 'boolean', 'constant'], style: { color: colors.rose } },
      { types: ['function'], style: { color: colors.rose } },
      { types: ['class-name', 'builtin'], style: { color: colors.foam } },
      { types: ['variable', 'property'], style: { color: colors.text } },
      { types: ['attr-name', 'selector'], style: { color: colors.iris } },
      { types: ['deleted'], style: { color: colors.love } },
      { types: ['inserted'], style: { color: colors.foam } },
    ],
  })
}

export function getPrismTheme(palette: ColorPalette): IPrismThemeScheme {
  return schemes.get(palette)!
}
