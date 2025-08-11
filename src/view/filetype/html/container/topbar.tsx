import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useHtmlViewViewModel } from '../context'

export const HtmlTopbar: React.FC = () => {
  const viewmodel = useHtmlViewViewModel()
  const filepath = useStateValue(viewmodel.filepath$)

  return (
    <div className="flex h-full items-center justify-between px-4 text-sm text-gray-600 dark:text-gray-300">
      <div className="truncate font-mono">{filepath}</div>
      <div className="text-xs">HTML</div>
    </div>
  )
}

HtmlTopbar.displayName = 'HtmlTopbar'
