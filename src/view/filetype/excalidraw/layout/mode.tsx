import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useExcalidrawViewViewModel } from '../context'

export const Mode: React.FC = () => {
  const viewmodel = useExcalidrawViewViewModel()
  const mode: ModeEnum = useStateValue(viewmodel.mode$)

  return (
    <div className="fixed top-3 right-4 z-50">
      <div
        className="flex h-5 select-none rounded-lg bg-gray-100 bg-opacity-80 text-sm shadow-md transition-all hover:bg-opacity-95 dark:bg-gray-700 dark:bg-opacity-90 dark:hover:bg-opacity-95"
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
          content
        </button>
      </div>
    </div>
  )
}

Mode.displayName = 'ExcalidrawViewMode'
