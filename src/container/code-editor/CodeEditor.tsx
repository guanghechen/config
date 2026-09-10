import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import { Editor, type EditorProps } from '@monaco-editor/react'
import React from 'react'
import { usePrettier } from '@/common/hook/usePrettier'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { FILETYPE_TO_LANGUAGE_MAP, SITE_THEME_TO_MONACO_THEME_MAP } from './constant'
import { DefaultCodeDropdown } from './DefaultCodeDropdown'
import { LanguageDropdown } from './LanguageDropdown'
import { PrettierFormatButton } from './PrettierFormatButton'
import { registerModernThemes } from './theme'

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
  // Remove any focus outlines or borders
  hover: {
    enabled: true,
    delay: 300,
  },
  // Remove the default Monaco border/outline
  renderLineHighlight: 'gutter',
  hideCursorInOverviewRuler: true,
} as const

interface IProps {
  readonly content: string | null
  readonly editorLanguage: string
  readonly visible: boolean
  readonly onContentChange: (content: string | null) => void
  readonly onLanguageChange: (language: string) => void
}

export const CodeEditor: React.FC<IProps> = (props: IProps) => {
  const { content, editorLanguage, visible, onContentChange, onLanguageChange } = props
  const language: string = FILETYPE_TO_LANGUAGE_MAP[editorLanguage] || editorLanguage

  const siteViewmodel = useSiteViewmodel()
  const siteTheme: SiteTheme = useStateValue(siteViewmodel.theme$)
  const { formatWithNotifications } = usePrettier()

  const [_monaco, setMonaco] = React.useState<any>(null)

  const theme = SITE_THEME_TO_MONACO_THEME_MAP[siteTheme]

  const handleEditorDidMount = useEventCallback((editor: any, monacoInstance: any) => {
    setMonaco(monacoInstance)

    // Add Prettier format command
    editor.addCommand(
      monacoInstance.KeyMod.CtrlCmd | monacoInstance.KeyMod.Shift | monacoInstance.KeyCode.KeyF,
      async () => {
        const model = editor.getModel()
        if (!model) return

        const code = model.getValue()
        const currentLanguage = editorLanguage

        const result = await formatWithNotifications(code, currentLanguage)
        if (result.success && result.formatted && result.formatted !== code) {
          const selection = editor.getSelection()
          model.setValue(result.formatted)
          if (selection) {
            editor.setSelection(selection)
          }
          onContentChange(result.formatted)
        }
      },
    )

    // Add action to command palette
    editor.addAction({
      id: 'prettier-format',
      label: 'Format with Prettier',
      keybindings: [
        monacoInstance.KeyMod.CtrlCmd | monacoInstance.KeyMod.Shift | monacoInstance.KeyCode.KeyF,
      ],
      contextMenuGroupId: 'modification',
      contextMenuOrder: 1.5,
      run: async () => {
        const model = editor.getModel()
        if (!model) return

        const code = model.getValue()
        const currentLanguage = editorLanguage

        const result = await formatWithNotifications(code, currentLanguage)
        if (result.success && result.formatted && result.formatted !== code) {
          const selection = editor.getSelection()
          model.setValue(result.formatted)
          if (selection) {
            editor.setSelection(selection)
          }
          onContentChange(result.formatted)
        }
      },
    })
  })

  const handleLoadTemplate = useEventCallback((templateContent: string) => {
    onContentChange(templateContent)
  })

  if (!visible) {
    return <React.Fragment />
  }

  return (
    <div className="size-full focus:outline-none">
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
          <PrettierFormatButton
            code={content || ''}
            language={editorLanguage}
            onFormatted={onContentChange}
          />
          <div className="w-px h-4 bg-gray-300 dark:bg-gray-600" />
          <DefaultCodeDropdown onLoadTemplate={handleLoadTemplate} />
          <LanguageDropdown value={editorLanguage} onChange={onLanguageChange} />
        </div>
      </div>
      <div className="h-[calc(100%-2rem)] focus:outline-none">
        <Editor
          height="100%"
          language={language}
          value={content || ''}
          onChange={value => onContentChange(value || null)}
          beforeMount={registerModernThemes}
          theme={theme}
          options={MONACO_EDITOR_OPTIONS}
          onMount={handleEditorDidMount}
        />
      </div>
    </div>
  )
}

CodeEditor.displayName = 'CodeEditor'
