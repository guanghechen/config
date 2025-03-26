import type { ISetState } from '@guanghechen/react-viewmodel'
import { useSetState, useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { JsonModeEnum, useWorkspaceViewmodel } from '../../context'

export const JsonModeToggle: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const mode: JsonModeEnum = useStateValue(viewmodel.jsonMode$)
  const setMode: ISetState<JsonModeEnum> = useSetState(viewmodel.jsonMode$)

  return (
    <div
      className="fixed right-4 top-16 z-50 flex h-5 select-none rounded-lg bg-gray-100 bg-opacity-80 text-sm shadow-md transition-all hover:bg-opacity-95 dark:bg-gray-800 dark:bg-opacity-80 dark:hover:bg-opacity-95"
      title={`Current mode: ${mode}`}
    >
      <button
        className={cn(
          'box-border px-3 transition-all duration-200 rounded-l-lg',
          mode === 0 || (mode & JsonModeEnum.VIEW) !== 0
            ? 'bg-indigo-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => setMode(m => m ^ JsonModeEnum.VIEW)}
      >
        view
      </button>
      <button
        className={cn(
          'box-border px-3 transition-all duration-200 rounded-r-lg',
          (mode & JsonModeEnum.LITERAL) !== 0
            ? 'bg-blue-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => setMode(m => m ^ JsonModeEnum.LITERAL)}
      >
        literal
      </button>
    </div>
  )
}

JsonModeToggle.displayName = 'JsonModeToggle'
