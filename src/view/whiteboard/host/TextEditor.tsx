import React from 'react'
import { Editor, loader } from '@monaco-editor/react'
import * as monaco from 'monaco-editor'
import { useStateValue } from '@guanghechen/react-viewmodel'
import { useSiteViewmodel } from '@/context/site'
import { registerEditorThemes } from '@/container/code-editor/theme'
import EditorWorker from 'monaco-editor/editor/editor.worker.js?worker'
import CssWorker from 'monaco-editor/languages/features/css/css.worker.js?worker'
import HtmlWorker from 'monaco-editor/languages/features/html/html.worker.js?worker'
import JsonWorker from 'monaco-editor/languages/features/json/json.worker.js?worker'
import TypeScriptWorker from 'monaco-editor/languages/features/typescript/ts.worker.js?worker'
import type { IWhiteboardEditorProps } from '../contracts'

// Reuse the installed Monaco package; no CDN or extra dependency is needed.
const previousEnvironment = self.MonacoEnvironment
self.MonacoEnvironment = {
  ...previousEnvironment,
  getWorker: (moduleId, label) => {
    if (label === 'json') return new JsonWorker()
    if (['css', 'scss', 'less'].includes(label)) return new CssWorker()
    if (['html', 'handlebars', 'razor'].includes(label)) return new HtmlWorker()
    if (['typescript', 'javascript'].includes(label)) return new TypeScriptWorker()
    return previousEnvironment?.getWorker?.(moduleId, label) ?? new EditorWorker()
  },
}
loader.config({ monaco })

export const TextEditor: React.FC<IWhiteboardEditorProps> = ({
  initialValue,
  language,
  readOnly,
  onChange,
  onMount,
}) => {
  const palette = useStateValue(useSiteViewmodel().palette$)
  return (
    <Editor
      language={language}
      defaultValue={initialValue}
      onChange={value => onChange(value ?? '')}
      beforeMount={registerEditorThemes}
      theme={palette}
      options={{
        fontSize: 15,
        minimap: { enabled: false },
        wordWrap: 'on',
        automaticLayout: true,
        scrollBeyondLastLine: false,
        padding: { top: 12 },
        readOnly,
        editContext: false,
      }}
      onMount={onMount}
    />
  )
}
