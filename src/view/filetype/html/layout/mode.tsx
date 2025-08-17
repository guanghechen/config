import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useHtmlViewViewModel } from '../context'

export const Mode: React.FC = () => {
  const viewmodel = useHtmlViewViewModel()
  const mode: ModeEnum = useStateValue(viewmodel.mode$)

  const viewEnabled = (mode & ModeEnum.VIEW) !== 0
  const tailwindEnabled = (mode & ModeEnum.TAILWIND) !== 0

  return (
    <div
      className="flex h-5 select-none rounded-lg bg-gray-100 bg-opacity-80 text-sm shadow-md transition-all hover:bg-opacity-95 dark:bg-gray-800 dark:bg-opacity-80 dark:hover:bg-opacity-95"
      title={`Current mode: ${mode}`}
    >
      <button
        className={cn(
          'box-border px-3 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
          viewEnabled
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
          tailwindEnabled
            ? 'bg-blue-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.TAILWIND)}
        title={`Tailwind CSS: ${tailwindEnabled ? 'Enabled' : 'Disabled'}`}
      >
        <svg className="inline mr-1 h-3 w-3" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12.001,4.8c-3.2,0-5.2,1.6-6,4.8c1.2-1.6,2.6-2.2,4.2-1.8c0.913,0.228,1.565,0.89,2.288,1.624 C13.666,10.618,15.027,12,18.001,12c3.2,0,5.2-1.6,6-4.8c-1.2,1.6-2.6,2.2-4.2,1.8c-0.913-0.228-1.565-0.89-2.288-1.624 C16.337,6.182,14.976,4.8,12.001,4.8z M6.001,12c-3.2,0-5.2,1.6-6,4.8c1.2-1.6,2.6-2.2,4.2-1.8c0.913,0.228,1.565,0.89,2.288,1.624 C7.666,17.818,9.027,19.2,12.001,19.2c3.2,0,5.2-1.6,6-4.8c-1.2,1.6-2.6,2.2-4.2,1.8c-0.913-0.228-1.565-0.89-2.288-1.624 C10.337,13.382,8.976,12,6.001,12z" />
        </svg>
        TW
      </button>
    </div>
  )
}

Mode.displayName = 'HtmlViewMode'
