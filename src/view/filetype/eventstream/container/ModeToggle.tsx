import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useEventStreamViewViewModel } from '../context'

export const ModeToggle: React.FC = () => {
  const viewmodel = useEventStreamViewViewModel()
  const mode = useStateValue(viewmodel.mode$)
  const expandTick = useStateValue(viewmodel.expandTick$)

  const showView = (mode & ModeEnum.VIEW) !== 0
  const showNavigation = (mode & ModeEnum.NAVIGATION) !== 0
  const allExpanded = expandTick % 2 === 0

  const toggleAllEvents = React.useCallback(() => {
    viewmodel.expandTick$.setState(prev => prev + 1)
  }, [viewmodel])

  return (
    <div className="fixed right-4 z-50 flex select-none rounded-lg bg-white/80 text-sm shadow-lg backdrop-blur-sm transition-all hover:bg-white/90 dark:bg-gray-900/80 dark:hover:bg-gray-900/90 top-4">
      <button
        className={cn(
          'box-border px-3 py-1 transition-all duration-200 rounded-l-lg focus:outline-none focus:ring-0',
          showView
            ? 'bg-emerald-500 font-medium text-white shadow-sm'
            : 'text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800',
        )}
        onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.VIEW)}
      >
        view
      </button>
      <button
        className={cn(
          'box-border px-3 py-1 transition-all duration-200 focus:outline-none focus:ring-0',
          showNavigation
            ? 'bg-blue-500 font-medium text-white shadow-sm'
            : 'text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800',
        )}
        onClick={() => viewmodel.mode$.setState(m => m ^ ModeEnum.NAVIGATION)}
      >
        nav
      </button>
      <button
        className="box-border px-3 py-1 transition-all duration-200 rounded-r-lg focus:outline-none focus:ring-0 bg-violet-500 font-medium text-white shadow-sm"
        onClick={toggleAllEvents}
        title={allExpanded ? 'Collapse all events' : 'Expand all events'}
      >
        {allExpanded ? 'collapse' : 'expand'}
      </button>
    </div>
  )
}

ModeToggle.displayName = 'EventStreamModeToggle'
