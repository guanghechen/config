import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useJsonViewViewModel } from '../context'

export const Mode: React.FC = () => {
  const viewmodel = useJsonViewViewModel()
  const mode: ModeEnum = useStateValue(viewmodel.mode$)

  return (
    <div
      className="flex h-5 select-none rounded-lg bg-gray-100 bg-opacity-80 text-sm shadow-md transition-all hover:bg-opacity-95 dark:bg-gray-800 dark:bg-opacity-80 dark:hover:bg-opacity-95"
      title={`Current mode: ${mode}`}
    >
      <button
        className={cn(
          'box-border px-3 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
          (mode & ModeEnum.VIEW) !== 0
            ? 'bg-indigo-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.VIEW)}
      >
        view
      </button>
      <button
        className={cn(
          'box-border px-3 transition-all duration-200 rounded-r-lg focus:outline-none focus:ring-0',
          (mode & ModeEnum.LITERAL) !== 0
            ? 'bg-blue-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.LITERAL)}
      >
        literal
      </button>
    </div>
  )
}

Mode.displayName = 'JsonViewMode'
