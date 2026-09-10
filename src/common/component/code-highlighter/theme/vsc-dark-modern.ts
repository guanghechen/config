import type { IPrismThemeScheme } from '../types'

// VS Code Modern colors adapted to Prism token categories.
// https://github.com/microsoft/vscode/tree/main/extensions/theme-defaults/themes
export const vscDarkModernTheme: IPrismThemeScheme = {
  plain: { color: '#cccccc', backgroundColor: '#1f1f1f' },
  styles: [
    { types: ['comment', 'prolog', 'doctype', 'cdata'], style: { color: '#6a9955' } },
    { types: ['punctuation', 'operator'], style: { color: '#d4d4d4' } },
    { types: ['keyword', 'boolean'], style: { color: '#569cd6' } },
    { types: ['string', 'char', 'attr-value'], style: { color: '#ce9178' } },
    { types: ['number', 'inserted'], style: { color: '#b5cea8' } },
    { types: ['function'], style: { color: '#dcdcaa' } },
    { types: ['class-name', 'builtin'], style: { color: '#4ec9b0' } },
    { types: ['variable', 'property'], style: { color: '#9cdcfe' } },
    { types: ['constant'], style: { color: '#4fc1ff' } },
    { types: ['tag'], style: { color: '#569cd6' } },
    { types: ['attr-name'], style: { color: '#9cdcfe' } },
    { types: ['selector'], style: { color: '#d7ba7d' } },
    { types: ['deleted'], style: { color: '#f44747' } },
  ],
}

export default vscDarkModernTheme
