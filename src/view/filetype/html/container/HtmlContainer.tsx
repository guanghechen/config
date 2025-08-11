import React from 'react'
import { HtmlMain } from './main'
import { HtmlTopbar } from './topbar'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
}

export const HtmlContainer: React.FC<IProps> = props => {
  const { workspace: _workspace, filepath: _filepath } = props

  return (
    <div className="w-full">
      <div className="h-[4rem] border-b border-gray-200 dark:border-gray-700">
        <HtmlTopbar />
      </div>
      <div className="h-[calc(100vh-10rem)] select-none overflow-hidden bg-white dark:bg-gray-900">
        <HtmlMain />
      </div>
    </div>
  )
}

HtmlContainer.displayName = 'HtmlContainer'
