import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ChevronDownIcon, ViewPageByPageIcon, ViewStreamIcon } from '@/component/icon/material'
import { usePdfViewViewModel } from '../context'

export const ContentViewMode: React.FC = () => {
  const viewmodel = usePdfViewViewModel()
  const multiview: boolean = useStateValue(viewmodel.multiview$)
  const [isOpen, setIsOpen] = React.useState<boolean>(false)
  const dropdownRef = React.useRef<HTMLDivElement>(null)

  const toggleDropdown = React.useCallback(() => {
    setIsOpen(prev => !prev)
  }, [])

  const handleViewModeChange = React.useCallback(
    (mode: boolean) => {
      viewmodel.multiview$.next(mode)
      setIsOpen(false)
    },
    [viewmodel],
  )

  // Close dropdown when clicking outside
  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent): void => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [])

  return (
    <div className="relative" ref={dropdownRef}>
      <button
        className={cn(
          'flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm',
          'text-gray-700 hover:bg-gray-50',
          'dark:border-gray-600 dark:bg-gray-800 dark:text-gray-300 dark:hover:bg-gray-700',
          'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50',
          'transition-colors',
        )}
        onClick={toggleDropdown}
        aria-label="View mode"
        aria-expanded={isOpen}
      >
        {multiview ? (
          <ViewStreamIcon className="h-4 w-4" />
        ) : (
          <ViewPageByPageIcon className="h-4 w-4" />
        )}
        <span>{multiview ? 'Multi View' : 'Single View'}</span>
        <ChevronDownIcon className={cn('h-4 w-4 transition-transform', isOpen && 'rotate-180')} />
      </button>

      {isOpen && (
        <div
          className={cn(
            'absolute left-0 top-full z-50 mt-1 min-w-full overflow-hidden rounded-lg',
            'border border-gray-200 bg-white shadow-lg',
            'dark:border-gray-600 dark:bg-gray-800',
          )}
        >
          <button
            className={cn(
              'flex w-full items-center gap-2 px-3 py-2 text-left text-sm',
              'text-gray-700 hover:bg-gray-50',
              'dark:text-gray-300 dark:hover:bg-gray-700',
              !multiview && 'bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
            )}
            onClick={() => handleViewModeChange(false)}
          >
            <ViewPageByPageIcon className="h-4 w-4" />
            <span>Single View</span>
          </button>
          <button
            className={cn(
              'flex w-full items-center gap-2 px-3 py-2 text-left text-sm',
              'text-gray-700 hover:bg-gray-50',
              'dark:text-gray-300 dark:hover:bg-gray-700',
              multiview && 'bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
            )}
            onClick={() => handleViewModeChange(true)}
          >
            <ViewStreamIcon className="h-4 w-4" />
            <span>Multi View</span>
          </button>
        </div>
      )}
    </div>
  )
}

ContentViewMode.displayName = 'ExcalidrawViewContentViewMode'
