import type MonacoEditor from '@monaco-editor/react'
import type { editor } from 'monaco-editor'

type MonacoEditorInstance = Parameters<
  NonNullable<Parameters<typeof MonacoEditor>[0]['onMount']>
>[1]

export interface IMarkdownLanguageOptions {
  readonly editorOptions: editor.IStandaloneEditorConstructionOptions
  readonly setupLanguage: (monacoInstance: MonacoEditorInstance) => void
}

export const markdownLanguageOptions: IMarkdownLanguageOptions = {
  editorOptions: {
    wordWrap: 'on' as const,
    quickSuggestions: {
      other: true,
      comments: true,
      strings: true,
    },
    suggest: {
      showKeywords: false,
      showSnippets: true,
      showFunctions: false,
      showVariables: false,
      showClasses: false,
      showInterfaces: false,
      showModules: false,
      showProperties: false,
      showColors: false,
      showFiles: true,
      showReferences: true,
      showFolders: false,
      showTypeParameters: false,
      showIssues: false,
      showUsers: false,
      showValues: true,
    },
    wordBasedSuggestions: 'allDocuments' as const,
    acceptSuggestionOnCommitCharacter: true,
    acceptSuggestionOnEnter: 'on',
    suggestOnTriggerCharacters: true,
    autoIndent: 'keep' as const,
    formatOnType: false,
    formatOnPaste: false,
    lineHeight: 1.5,
    fontLigatures: true,
    renderLineHighlight: 'gutter' as const,
    smoothScrolling: true,
    cursorBlinking: 'smooth' as const,
    bracketPairColorization: {
      enabled: true,
    },
    guides: {
      bracketPairs: true,
      indentation: false,
    },
    links: true,
    colorDecorators: false,
    unicodeHighlight: {
      ambiguousCharacters: false,
      invisibleCharacters: false,
    },
  },

  setupLanguage: (monacoInstance: MonacoEditorInstance) => {
    monacoInstance.languages.setLanguageConfiguration('markdown', {
      wordPattern: /(-?\d*\.\d\w*)|([^`~!@#%^&*()\-=+[{}\\|;:'",.<>/?s]+)/g,
      brackets: [
        ['[', ']'],
        ['(', ')'],
        ['{', '}'],
        ['```', '```'],
        ['`', '`'],
      ],
      autoClosingPairs: [
        { open: '[', close: ']' },
        { open: '(', close: ')' },
        { open: '{', close: '}' },
        { open: '"', close: '"' },
        { open: "'", close: "'" },
        { open: '`', close: '`' },
        { open: '*', close: '*' },
        { open: '_', close: '_' },
        { open: '**', close: '**' },
        { open: '__', close: '__' },
        { open: '~~', close: '~~' },
        { open: '```', close: '```', notIn: ['string', 'comment'] },
        { open: '<', close: '>', notIn: ['string'] },
      ],
      surroundingPairs: [
        { open: '[', close: ']' },
        { open: '(', close: ')' },
        { open: '{', close: '}' },
        { open: '"', close: '"' },
        { open: "'", close: "'" },
        { open: '`', close: '`' },
        { open: '*', close: '*' },
        { open: '_', close: '_' },
        { open: '**', close: '**' },
        { open: '__', close: '__' },
        { open: '~~', close: '~~' },
        { open: '<', close: '>' },
      ],
      folding: {
        markers: {
          start: new RegExp('^\\s*<!--\\s*#?region\\b.*-->'),
          end: new RegExp('^\\s*<!--\\s*#?endregion\\b.*-->'),
        },
        offSide: true,
      },
      comments: {
        blockComment: ['<!--', '-->'],
      },
      onEnterRules: [
        {
          beforeText: /^\s*[-*+]\s+.*$/,
          action: {
            indentAction: monacoInstance.languages.IndentAction.None,
            appendText: '- ',
          },
        },
        {
          beforeText: /^\s*\d+\.\s+.*$/,
          action: {
            indentAction: monacoInstance.languages.IndentAction.None,
            appendText: '1. ',
          },
        },
        {
          beforeText: /^\s*>\s+.*$/,
          action: {
            indentAction: monacoInstance.languages.IndentAction.None,
            appendText: '> ',
          },
        },
        {
          beforeText: /^\s*```.*$/,
          action: {
            indentAction: monacoInstance.languages.IndentAction.IndentOutdent,
          },
        },
      ],
    })

    // Register markdown-specific completion provider
    monacoInstance.languages.registerCompletionItemProvider('markdown', {
      provideCompletionItems: (model, position) => {
        const word = model.getWordUntilPosition(position)
        const range = {
          startLineNumber: position.lineNumber,
          endLineNumber: position.lineNumber,
          startColumn: word.startColumn,
          endColumn: word.endColumn,
        }

        const suggestions = [
          /* eslint-disable no-template-curly-in-string */
          {
            label: 'h1',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '# ${1:Heading 1}',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert heading level 1',
            range,
          },
          {
            label: 'h2',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '## ${1:Heading 2}',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert heading level 2',
            range,
          },
          {
            label: 'h3',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '### ${1:Heading 3}',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert heading level 3',
            range,
          },
          {
            label: 'link',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '[${1:text}](${2:url})',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert link',
            range,
          },
          {
            label: 'image',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '![${1:alt text}](${2:image url})',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert image',
            range,
          },
          {
            label: 'code',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '`${1:code}`',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert inline code',
            range,
          },
          {
            label: 'codeblock',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '```${1:language}\n${2:code}\n```',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert code block',
            range,
          },
          {
            label: 'table',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText:
              '| ${1:Header 1} | ${2:Header 2} |\n|----------|----------|\n| ${3:Cell 1} | ${4:Cell 2} |',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert table',
            range,
          },
          {
            label: 'bold',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '**${1:text}**',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert bold text',
            range,
          },
          {
            label: 'italic',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '*${1:text}*',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert italic text',
            range,
          },
          {
            label: 'strikethrough',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '~~${1:text}~~',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert strikethrough text',
            range,
          },
          {
            label: 'blockquote',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '> ${1:quote}',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert blockquote',
            range,
          },
          {
            label: 'list',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '- ${1:item 1}\n- ${2:item 2}\n- ${3:item 3}',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert unordered list',
            range,
          },
          {
            label: 'orderedlist',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '1. ${1:item 1}\n2. ${2:item 2}\n3. ${3:item 3}',
            insertTextRules: monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: 'Insert ordered list',
            range,
          },
          {
            label: 'hr',
            kind: monacoInstance.languages.CompletionItemKind.Snippet,
            insertText: '---',
            documentation: 'Insert horizontal rule',
            range,
          },
        ]
        /* eslint-enable no-template-curly-in-string */

        return { suggestions }
      },
    })
  },
}
