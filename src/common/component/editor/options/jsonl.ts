import type MonacoEditor from '@monaco-editor/react'
import type { editor } from 'monaco-editor'

type MonacoEditorInstance = Parameters<
  NonNullable<Parameters<typeof MonacoEditor>[0]['onMount']>
>[1]

export interface IJsonlLanguageOptions {
  readonly editorOptions: editor.IStandaloneEditorConstructionOptions
  readonly setupLanguage: (monacoInstance: MonacoEditorInstance) => void
}

export const jsonlLanguageOptions: IJsonlLanguageOptions = {
  editorOptions: {
    quickSuggestions: {
      other: true,
      comments: false,
      strings: true,
    },
    autoIndent: 'full' as const,
    formatOnType: true,
    formatOnPaste: true,
  },

  setupLanguage: (monacoInstance: MonacoEditorInstance) => {
    monacoInstance.languages.json.jsonDefaults.setDiagnosticsOptions({
      validate: true,
      allowComments: false,
      schemas: [],
      enableSchemaRequest: true,
    })
  },
}
