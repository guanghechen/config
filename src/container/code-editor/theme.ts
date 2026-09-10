import type { Monaco } from '@monaco-editor/react'
import { DARK_PALETTES, LIGHT_PALETTES } from '@/common/style/palette'

// Modern's syntax colors inherit VS Code's light/dark token families;
// register before mounting to avoid a flash of Monaco's default theme.
export function registerEditorThemes(monaco: Monaco): void {
  monaco.editor.defineTheme('vsc-dark-modern', {
    base: 'vs-dark',
    inherit: true,
    rules: [
      { token: 'comment', foreground: '6A9955' },
      { token: 'keyword', foreground: '569CD6' },
      { token: 'string', foreground: 'CE9178' },
      { token: 'number', foreground: 'B5CEA8' },
      { token: 'type.identifier', foreground: '4EC9B0' },
    ],
    colors: {
      'editor.background': '#1F1F1F',
      'editor.foreground': '#CCCCCC',
      'editorLineNumber.foreground': '#6E7681',
      'editorLineNumber.activeForeground': '#CCCCCC',
      'editor.selectionBackground': '#264F78',
      'editor.inactiveSelectionBackground': '#3A3D41',
      'editorWidget.background': '#202020',
      'editorWidget.border': '#454545',
      'minimap.background': '#1F1F1F',
      focusBorder: '#0078D4',
    },
  })
  monaco.editor.defineTheme('vsc-light-modern', {
    base: 'vs',
    inherit: true,
    rules: [
      { token: 'comment', foreground: '008000' },
      { token: 'keyword', foreground: '0000FF' },
      { token: 'string', foreground: 'A31515' },
      { token: 'number', foreground: '098658' },
      { token: 'type.identifier', foreground: '267F99' },
    ],
    colors: {
      'editor.background': '#FFFFFF',
      'editor.foreground': '#3B3B3B',
      'editorLineNumber.foreground': '#6E7681',
      'editorLineNumber.activeForeground': '#171184',
      'editor.selectionBackground': '#ADD6FF',
      'editor.inactiveSelectionBackground': '#E5EBF1',
      'editorWidget.background': '#F8F8F8',
      'editorWidget.border': '#C8C8C8',
      'minimap.background': '#FFFFFF',
      focusBorder: '#005FB8',
    },
  })
  for (const { id, colors } of [...LIGHT_PALETTES, ...DARK_PALETTES]) {
    if (id.startsWith('vsc-')) continue
    const color = (value: string): string => value.slice(1)
    monaco.editor.defineTheme(id, {
      base: id === 'rose-pine-dawn' ? 'vs' : 'vs-dark',
      inherit: true,
      rules: [
        { token: '', foreground: color(colors.text) },
        { token: 'comment', foreground: color(colors.muted) },
        { token: 'keyword', foreground: color(colors.pine) },
        { token: 'string', foreground: color(colors.gold) },
        { token: 'number', foreground: color(colors.rose) },
        { token: 'type.identifier', foreground: color(colors.foam) },
        { token: 'delimiter', foreground: color(colors.subtle) },
      ],
      colors: {
        'editor.background': colors.base,
        'editor.foreground': colors.text,
        'editorLineNumber.foreground': colors.muted,
        'editorLineNumber.activeForeground': colors.text,
        'editor.selectionBackground': colors.highlightMed,
        'editor.inactiveSelectionBackground': colors.highlightLow,
        'editorWidget.background': colors.surface,
        'editorWidget.border': colors.highlightHigh,
        'minimap.background': colors.base,
        focusBorder: colors.iris,
      },
    })
  }
}
