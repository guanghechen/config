import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useJsonlViewViewModel } from '../context'

interface IProps {
  readonly topbarVisible: boolean
}

export const ModeToggle: React.FC<IProps> = ({ topbarVisible }) => {
  const viewmodel = useJsonlViewViewModel()
  const mode: ModeEnum = useStateValue(viewmodel.mode$)
  const expandTick: number = useStateValue(viewmodel.expandTick$)

  const toggleAllRecords = React.useCallback(() => {
    viewmodel.expandTick$.setState(prev => prev + 1)
  }, [viewmodel])

  const showNavigation = (mode & ModeEnum.NAVIGATION) !== 0
  const allExpanded = expandTick % 2 === 0

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
            ? 'bg-emerald-500 font-medium text-white shadow-sm'
            : 'text-gray-500 hover:bg-gray-200 hover:bg-opacity-50 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:bg-opacity-50',
        )}
        onClick={() => viewmodel.mode$.next(viewmodel.mode$.getSnapshot() ^ ModeEnum.VIEW)}
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
        onClick={() => viewmodel.mode$.next(viewmodel.mode$.getSnapshot() ^ ModeEnum.NAVIGATION)}
      >
        nav
      </button>
      <button
        className="box-border px-3 py-1 transition-all duration-200 rounded-r-lg focus:outline-none focus:ring-0 bg-violet-500 font-medium text-white shadow-sm"
        onClick={toggleAllRecords}
        title={allExpanded ? 'Collapse all records' : 'Expand all records'}
      >
        {allExpanded ? 'collapse' : 'expand'}
      </button>
    </div>
  )
}

ModeToggle.displayName = 'JsonlModeToggle'
