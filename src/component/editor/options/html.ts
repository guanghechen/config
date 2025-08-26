import type MonacoEditor from '@monaco-editor/react'
import type { editor } from 'monaco-editor'

type MonacoEditorInstance = Parameters<
  NonNullable<Parameters<typeof MonacoEditor>[0]['onMount']>
>[1]

export interface IHtmlLanguageOptions {
  readonly editorOptions: editor.IStandaloneEditorConstructionOptions
  readonly setupLanguage: (monacoInstance: MonacoEditorInstance) => void
}

export const htmlLanguageOptions: IHtmlLanguageOptions = {
  editorOptions: {
    quickSuggestions: {
      other: true,
      comments: false,
      strings: true,
    },
    autoIndent: 'full' as const,
    formatOnType: true,
    formatOnPaste: true,
    suggest: {
      showKeywords: true,
      showSnippets: true,
      showFunctions: false,
      showVariables: false,
      showClasses: true,
      showInterfaces: false,
      showModules: false,
      showProperties: true,
      showColors: true,
      showFiles: true,
      showReferences: true,
      showFolders: true,
      showTypeParameters: true,
      showIssues: true,
      showUsers: true,
      showValues: true,
    },
    wordBasedSuggestions: 'allDocuments' as const,
    acceptSuggestionOnCommitCharacter: true,
    acceptSuggestionOnEnter: 'on',
    suggestOnTriggerCharacters: true,
  },

  setupLanguage: (monacoInstance: MonacoEditorInstance) => {
    monacoInstance.languages.setLanguageConfiguration('html', {
      wordPattern: /(-?\d*\.\d\w*)|([^`~!@#%^&*()=+[\]{}\\|;:'",.<>/?s]+)/g,
      brackets: [
        ['<!--', '-->'],
        ['<', '>'],
        ['{', '}'],
        ['[', ']'],
        ['(', ')'],
      ],
      autoClosingPairs: [
        { open: '{', close: '}' },
        { open: '[', close: ']' },
        { open: '(', close: ')' },
        { open: '"', close: '"' },
        { open: "'", close: "'" },
        { open: '<', close: '>', notIn: ['string'] },
      ],
      surroundingPairs: [
        { open: '"', close: '"' },
        { open: "'", close: "'" },
        { open: '{', close: '}' },
        { open: '[', close: ']' },
        { open: '(', close: ')' },
        { open: '<', close: '>' },
      ],
      folding: {
        markers: {
          start: new RegExp('^\\s*<!--\\s*#?region\\b.*-->'),
          end: new RegExp('^\\s*<!--\\s*#?endregion\\b.*-->'),
        },
      },
    })
  },
}
