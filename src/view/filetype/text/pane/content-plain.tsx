import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { CodeEditor } from '@/container/code-editor'
import { useTextViewViewModel } from '../context'

export const ContentPlain: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const content: string | null = useStateValue(viewmodel.content$)
  const [editorLanguage, setEditorLanguage] = React.useState('text')

  const handleContentChange = React.useCallback(() => {
    // Content is read-only in this context, so we don't need to handle changes
  }, [])

  const handleLanguageChange = React.useCallback((language: string) => {
    setEditorLanguage(language)
  }, [])

  if (!content) {
    return (
      <div className="size-full flex justify-center">
        <div className="text-red-500 dark:text-red-400">No Content Found</div>
      </div>
    )
  }

  return (
    <div className="box-border size-full">
      <CodeEditor
        content={content}
        editorLanguage={editorLanguage}
        visible={true}
        onContentChange={handleContentChange}
        onLanguageChange={handleLanguageChange}
      />
    </div>
  )
}

ContentPlain.displayName = 'TextViewContentPlain'
