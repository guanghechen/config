import { useEventCallback } from '@guanghechen/react-hooks'
import MonacoEditor from '@monaco-editor/react'
import cn from 'clsx'
import type { editor } from 'monaco-editor'
import React from 'react'
import { baseEditorOptions } from './options/base'
import { htmlLanguageOptions } from './options/html'
import { jsonLanguageOptions } from './options/json'
import { jsonlLanguageOptions } from './options/jsonl'
import { markdownLanguageOptions } from './options/markdown'
import { textLanguageOptions } from './options/text'

type MonacoEditorInstance = Parameters<
  NonNullable<Parameters<typeof MonacoEditor>[0]['onMount']>
>[1]

type SupportedLanguage = 'markdown' | 'json' | 'jsonl' | 'text' | 'html'
type MonacoLanguage = 'markdown' | 'json' | 'plaintext' | 'html'
type EditorTheme = 'lighten' | 'darken'

const LANGUAGE_MAP: Record<SupportedLanguage, MonacoLanguage> = {
  markdown: 'markdown',
  json: 'json',
  jsonl: 'json',
  text: 'plaintext',
  html: 'html',
}

const THEME_MAP: Record<EditorTheme, string> = {
  lighten: 'light',
  darken: 'vs-dark',
}

interface IEditorProps {
  readonly lang: SupportedLanguage
  readonly code: string
  readonly theme: EditorTheme
  readonly className?: string
  readonly onChange: (code: string) => void
  readonly onSave: (code: string) => void
}

export const Editor: React.FC<IEditorProps> = props => {
  const { lang, code, theme, className, onChange, onSave } = props
  const language = LANGUAGE_MAP[lang] || 'plaintext'
  const monacoTheme = THEME_MAP[theme] || 'vs-dark'

  const handleEditorChange = useEventCallback((value: string | undefined) => {
    const newValue = value ?? ''
    onChange(newValue)
  })

  const handleKeyDown = useEventCallback((event: React.KeyboardEvent) => {
    if ((event.ctrlKey || event.metaKey) && event.key === 's') {
      event.preventDefault()
      onSave(code)
    }
  })

  const handleEditorDidMount = useEventCallback(
    (editorInstance: editor.IStandaloneCodeEditor, monacoInstance: MonacoEditorInstance) => {
      // Setup language-specific configurations
      switch (lang) {
        case 'json':
          jsonLanguageOptions.setupLanguage(monacoInstance)
          break
        case 'jsonl':
          jsonlLanguageOptions.setupLanguage(monacoInstance)
          break
        case 'markdown':
          markdownLanguageOptions.setupLanguage(monacoInstance)
          break
        case 'text':
          textLanguageOptions.setupLanguage(monacoInstance)
          break
        case 'html':
          htmlLanguageOptions.setupLanguage(monacoInstance)
          break
      }

      // Global editor enhancements
      editorInstance.addCommand(monacoInstance.KeyMod.CtrlCmd | monacoInstance.KeyCode.KeyS, () => {
        onSave(editorInstance.getValue())
      })
    },
  )

  const editorOptions = React.useMemo(() => {
    // Apply language-specific options
    switch (lang) {
      case 'json':
        return {
          ...baseEditorOptions,
          ...jsonLanguageOptions.editorOptions,
        }
      case 'jsonl':
        return {
          ...baseEditorOptions,
          ...jsonlLanguageOptions.editorOptions,
        }
      case 'markdown':
        return {
          ...baseEditorOptions,
          ...markdownLanguageOptions.editorOptions,
        }
      case 'html':
        return {
          ...baseEditorOptions,
          ...htmlLanguageOptions.editorOptions,
        }
      case 'text':
      default:
        return {
          ...baseEditorOptions,
          ...textLanguageOptions.editorOptions,
        }
    }
  }, [lang])

  return (
    <div className={cn('h-full w-full', className)} onKeyDown={handleKeyDown}>
      <MonacoEditor
        height="100%"
        language={language}
        value={code}
        onChange={handleEditorChange}
        onMount={handleEditorDidMount}
        theme={monacoTheme}
        options={editorOptions}
      />
    </div>
  )
}

Editor.displayName = 'Editor'
