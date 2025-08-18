import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useTextViewViewModel } from '../context'

export const ContentPlain: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const content: string | null = useStateValue(viewmodel.content$)

  if (!content) {
    return (
      <div className="size-full flex justify-center">
        <div className="text-red-500 dark:text-red-400">No Content Found</div>
      </div>
    )
  }

  return (
    <div className="size-full flex justify-center">
      <pre className="font-mono-maple whitespace-pre-wrap break-words text-sm leading-relaxed text-gray-800 dark:text-gray-200">
        {content}
      </pre>
    </div>
  )
}

ContentPlain.displayName = 'TextViewContentPlain'
