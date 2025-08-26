import type MonacoEditor from '@monaco-editor/react'
import type { editor } from 'monaco-editor'

type MonacoEditorInstance = Parameters<
  NonNullable<Parameters<typeof MonacoEditor>[0]['onMount']>
>[1]

export interface ITextLanguageOptions {
  readonly editorOptions: editor.IStandaloneEditorConstructionOptions
  readonly setupLanguage: (monacoInstance: MonacoEditorInstance) => void
}

export const textLanguageOptions: ITextLanguageOptions = {
  editorOptions: {
    suggest: {
      showKeywords: false,
      showSnippets: false,
      showFunctions: false,
      showVariables: false,
      showClasses: false,
      showInterfaces: false,
      showModules: false,
      showProperties: false,
      showColors: true,
      showFiles: true,
      showReferences: true,
      showFolders: true,
      showTypeParameters: true,
      showIssues: true,
      showUsers: true,
      showValues: true,
    },
    wordBasedSuggestions: 'currentDocument' as const,
  },

  setupLanguage: (monacoInstance: MonacoEditorInstance) => {
    monacoInstance.languages.setLanguageConfiguration('plaintext', {
      brackets: [
        ['[', ']'],
        ['(', ')'],
        ['{', '}'],
      ],
      autoClosingPairs: [
        { open: '[', close: ']' },
        { open: '(', close: ')' },
        { open: '{', close: '}' },
        { open: '"', close: '"' },
        { open: "'", close: "'" },
      ],
    })
  },
}
