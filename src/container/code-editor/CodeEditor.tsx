import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import { Editor, type EditorProps } from '@monaco-editor/react'
import React from 'react'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site/hook'
import {
  FILETYPE_TO_LANGUAGE_MAP,
  SITE_THEME_TO_CUSTOMIZED_THEME_MAP,
  SITE_THEME_TO_MONACO_THEME_MAP,
} from './constant'
import { LanguageDropdown } from './LanguageDropdown'

const MONACO_EDITOR_OPTIONS: EditorProps['options'] = {
  minimap: {
    enabled: true,
    autohide: false,
    side: 'right',
  },
  fontSize: 14,
  lineNumbers: 'on',
  wordWrap: 'on',
  automaticLayout: true,
  scrollBeyondLastLine: false,
  padding: { top: 10, bottom: 10 },
  lineHeight: 1.6,
  fontFamily: 'Maple Mono NF CN, Roboto Mono, monospace, sans-serif',
} as const

// Custom transparent themes
const TRANSPARENT_LIGHT_THEME = {
  base: 'vs' as const,
  inherit: true,
  rules: [],
  colors: {
    'editor.background': '#f8fafc90', // Semi-transparent light background
    'editor.foreground': '#1f2937',
    'editorLineNumber.foreground': '#6b7280',
    'editorLineNumber.activeForeground': '#374151',
    'editor.selectionBackground': '#3b82f640',
    'editor.inactiveSelectionBackground': '#3b82f620',
    // Minimap colors
    'minimap.background': '#f8fafc80', // Semi-transparent light background
    'minimap.foregroundOpacity': '#000000dd',
    'minimapSlider.background': '#94a3b840',
    'minimapSlider.hoverBackground': '#64748b60',
    'minimapSlider.activeBackground': '#475569',
  },
}

const TRANSPARENT_DARK_THEME = {
  base: 'vs-dark' as const,
  inherit: true,
  rules: [],
  colors: {
    'editor.background': '#1e293b90', // Semi-transparent dark background
    'editor.foreground': '#e5e7eb',
    'editorLineNumber.foreground': '#6b7280',
    'editorLineNumber.activeForeground': '#9ca3af',
    'editor.selectionBackground': '#3b82f640',
    'editor.inactiveSelectionBackground': '#3b82f620',
    // Minimap colors
    'minimap.background': '#1e293b80', // Semi-transparent dark background
    'minimap.foregroundOpacity': '#e2e8f0dd',
    'minimapSlider.background': '#64748b40',
    'minimapSlider.hoverBackground': '#94a3b860',
    'minimapSlider.activeBackground': '#cbd5e1',
  },
}

interface IProps {
  readonly content: string | null
  readonly filetype: string
  readonly editorLanguage: string
  readonly visible: boolean
  readonly onContentChange: (content: string | null) => void
  readonly onLanguageChange: (language: string) => void
}

export const CodeEditor: React.FC<IProps> = (props: IProps) => {
  const { content, filetype, editorLanguage, visible, onContentChange, onLanguageChange } = props
  const language: string = FILETYPE_TO_LANGUAGE_MAP[editorLanguage] || editorLanguage

  const siteViewmodel = useSiteViewmodel()
  const siteTheme: SiteTheme = useStateValue(siteViewmodel.theme$)

  const [_monaco, setMonaco] = React.useState<any>(null)
  const [mounted, setMounted] = React.useState<boolean>(false)

  const theme: string = mounted
    ? SITE_THEME_TO_CUSTOMIZED_THEME_MAP[siteTheme]
    : SITE_THEME_TO_MONACO_THEME_MAP[siteTheme]

  React.useEffect(() => {
    const detectedLanguage = FILETYPE_TO_LANGUAGE_MAP[filetype]
    if (detectedLanguage && detectedLanguage !== editorLanguage) {
      onLanguageChange(detectedLanguage)
    }
  }, [filetype, editorLanguage, onLanguageChange])

  const handleEditorDidMount = useEventCallback((_editor: any, monacoInstance: any) => {
    setMonaco(monacoInstance)

    // Define custom transparent themes
    monacoInstance.editor.defineTheme('transparent-light', TRANSPARENT_LIGHT_THEME)
    monacoInstance.editor.defineTheme('transparent-dark', TRANSPARENT_DARK_THEME)
    setMounted(true)
  })

  if (!visible) {
    return <React.Fragment />
  }

  return (
    <div className="h-full w-full">
      <div className="h-8 flex items-center justify-between px-3 border-b border-gray-200/50 dark:border-gray-700/30 bg-gray-50/50 dark:bg-gray-900/50">
        <div className="flex items-center gap-2">
          <svg
            className="h-4 w-4 text-gray-500 dark:text-gray-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
            />
          </svg>
          <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Code Editor</span>
        </div>
        <div className="flex items-center gap-2">
          <LanguageDropdown value={editorLanguage} onChange={onLanguageChange} />
        </div>
      </div>
      <div className="h-[calc(100%-2rem)]">
        <Editor
          height="100%"
          language={language}
          value={content || ''}
          onChange={value => onContentChange(value || null)}
          theme={theme}
          options={MONACO_EDITOR_OPTIONS}
          onMount={handleEditorDidMount}
        />
      </div>
    </div>
  )
}

CodeEditor.displayName = 'CodeEditor'
