import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useTopbarVisible } from '@/context/workspace'
import { ModeEnum, useJsonlActions, useJsonlState, useJsonlViewViewModel } from '../context'

export const ModeToggle: React.FC = () => {
  const topbarVisible = useTopbarVisible()
  const viewmodel = useJsonlViewViewModel()
  const mode: ModeEnum = useStateValue(viewmodel.mode$)
  const expandedRecords: ReadonlySet<number> = useStateValue(viewmodel.expandedRecords$)
  const { records } = useJsonlState()
  const { toggleAllRecords } = useJsonlActions()

  const showNavigation = (mode & ModeEnum.NAVIGATION) !== 0
  const allExpanded = records.length > 0 && expandedRecords.size === records.length

  return (
    <div
      className={cn(
        'fixed right-4 z-50 flex select-none rounded-lg bg-gray-100 bg-opacity-80 text-sm shadow-md transition-all hover:bg-opacity-95 dark:bg-gray-800 dark:bg-opacity-80 dark:hover:bg-opacity-95',
        topbarVisible ? 'top-16' : 'top-4',
      )}
    >
      <button
        className={cn(
          'box-border px-3 py-1 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
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
          'box-border px-3 py-1 transition-all duration-200 focus:outline-none focus:ring-0',
          showNavigation
            ? 'bg-blue-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.NAVIGATION)}
      >
        nav
      </button>
      <button
        className={cn(
          'box-border px-3 py-1 transition-all duration-200 rounded-r-lg focus:outline-none focus:ring-0',
          allExpanded
            ? 'bg-green-500 bg-opacity-90 font-medium text-white shadow-inner'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={toggleAllRecords}
        title={allExpanded ? 'Collapse all records' : 'Expand all records'}
      >
        {allExpanded ? 'collapse' : 'expand'}
      </button>
    </div>
  )
}

ModeToggle.displayName = 'JsonlModeToggle'
