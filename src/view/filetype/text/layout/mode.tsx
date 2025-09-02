import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { createPortal } from 'react-dom'
import { ContentModeEnum, ModeEnum, useTextViewViewModel } from '../context'

export const ModeToggle: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const mode: ModeEnum = useStateValue(viewmodel.mode$)
  const contentMode: ContentModeEnum = useStateValue(viewmodel.contentMode$)

  const showView: boolean = (mode & ModeEnum.CONTENT) !== 0
  const showNav: boolean = showView && contentMode === ContentModeEnum.LIST

  const portalTarget = React.useMemo(() => {
    return document.querySelector('.vlt-rightest')
  }, [])

  const toggleContent = (
    <div className="flex items-center justify-end">
      <div
        className="flex h-5 select-none rounded-lg bg-gray-200 bg-opacity-70 text-sm shadow-md transition-all hover:bg-opacity-90 dark:bg-gray-700 dark:bg-opacity-70 dark:hover:bg-opacity-90"
        title={`Current mode: ${mode}`}
      >
        <button
          className={cn(
            'box-border px-3 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
            (mode & ModeEnum.CONTENT) !== 0
              ? 'bg-indigo-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.CONTENT)}
        >
          view
        </button>
        {showNav && (
          <button
            className={cn(
              'box-border px-3 transition-all duration-200 focus:outline-none focus:ring-0',
              (mode & ModeEnum.NAV) !== 0
                ? 'bg-purple-500 bg-opacity-90 font-medium text-white shadow-inner'
                : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
            )}
            onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.NAV)}
          >
            nav
          </button>
        )}
        <button
          className={cn(
            'box-border px-3 transition-all duration-200 focus:outline-none focus:ring-0',
            (mode & ModeEnum.RAW) !== 0
              ? 'bg-blue-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.RAW)}
        >
          raw
        </button>
        <button
          className={cn(
            'box-border px-3 transition-all duration-200 rounded-r-lg focus:outline-none focus:ring-0',
            (mode & ModeEnum.TRANSFORM) !== 0
              ? 'bg-green-500 bg-opacity-90 font-medium text-white shadow-inner'
              : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
          )}
          onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.TRANSFORM)}
        >
          transform
        </button>
      </div>
    </div>
  )

  if (!portalTarget) {
    return null
  }

  return createPortal(toggleContent, portalTarget)
}

ModeToggle.displayName = 'TextViewModeToggle'
