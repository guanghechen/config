import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { CodeEditor } from '@/container/code-editor'
import { useWhiteboardViewmodel } from '../context'

export const WhiteboardCodeEditor: React.FC = () => {
  const viewmodel = useWhiteboardViewmodel()
  const content = useStateValue(viewmodel.content$)
  const filetype = useStateValue(viewmodel.filetype$)
  const editorVisible = useStateValue(viewmodel.editorVisible$)
  const editorLanguage = useStateValue(viewmodel.editorLanguage$)

  return (
    <CodeEditor
      content={content}
      filetype={filetype}
      editorLanguage={editorLanguage}
      visible={editorVisible}
      onContentChange={viewmodel.updateContent}
      onLanguageChange={viewmodel.updateEditorLanguage}
    />
  )
}
