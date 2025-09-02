import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { createPortal } from 'react-dom'
import { ModeEnum, useMarkdownViewViewModel } from '../context'

export const ModeToggle: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const mode: ModeEnum = useStateValue(viewmodel.mode$)

  const portalTarget = React.useMemo(() => {
    return document.querySelector('.vlt-rightest')
  }, [])

  const toggleContent = (
    <div className="flex items-center justify-end">
      <div
        className="flex h-5 select-none rounded-lg bg-gray-100 bg-opacity-80 text-sm shadow-md transition-all hover:bg-opacity-95 dark:bg-gray-700 dark:bg-opacity-90 dark:hover:bg-opacity-95"
        title={`Current mode: ${mode}`}
      >
        <button
          className={cn(
            'box-border px-3 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
            mode === 0 || (mode & ModeEnum.CONTENT) !== 0
              ? 'bg-indigo-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.CONTENT)}
        >
          md
        </button>
        <button
          className={cn(
            'box-border px-3 transition-all duration-200 focus:outline-none focus:ring-0',
            (mode & ModeEnum.AST) !== 0
              ? 'bg-blue-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.AST)}
        >
          ast
        </button>
        <button
          className={cn(
            'box-border px-3 transition-all duration-200 focus:outline-none focus:ring-0',
            (mode & ModeEnum.TOC) !== 0
              ? 'bg-sky-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.TOC)}
        >
          toc
        </button>
        <button
          className={cn(
            'box-border px-3 transition-all duration-200 rounded-r-lg focus:outline-none focus:ring-0',
            (mode & ModeEnum.FM) !== 0
              ? 'bg-teal-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.FM)}
        >
          fm
        </button>
      </div>
    </div>
  )

  if (!portalTarget) {
    return null
  }

  return createPortal(toggleContent, portalTarget)
}

ModeToggle.displayName = 'MarkdownViewModeToggle'
