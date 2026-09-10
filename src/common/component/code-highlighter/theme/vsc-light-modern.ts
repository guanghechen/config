import type { IPrismThemeScheme } from '../types'

// VS Code Modern colors adapted to Prism token categories.
// https://github.com/microsoft/vscode/tree/main/extensions/theme-defaults/themes
export const vscLightModernTheme: IPrismThemeScheme = {
  plain: { color: '#3b3b3b', backgroundColor: '#ffffff' },
  styles: [
    { types: ['comment', 'prolog', 'doctype', 'cdata'], style: { color: '#008000' } },
    { types: ['punctuation', 'operator'], style: { color: '#3b3b3b' } },
    { types: ['keyword', 'boolean'], style: { color: '#0000ff' } },
    { types: ['string', 'char', 'attr-value'], style: { color: '#a31515' } },
    { types: ['number', 'inserted'], style: { color: '#098658' } },
    { types: ['function'], style: { color: '#795e26' } },
    { types: ['class-name', 'builtin'], style: { color: '#267f99' } },
    { types: ['variable', 'property'], style: { color: '#001080' } },
    { types: ['constant'], style: { color: '#0070c1' } },
    { types: ['tag'], style: { color: '#800000' } },
    { types: ['attr-name'], style: { color: '#e50000' } },
    { types: ['selector'], style: { color: '#800000' } },
    { types: ['deleted'], style: { color: '#a31515' } },
  ],
}

export default vscLightModernTheme
