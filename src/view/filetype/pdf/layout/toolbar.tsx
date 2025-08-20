import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import {
  ChevronDownIcon,
  ChevronLeftIcon,
  ChevronRightIcon,
  ViewPageByPageIcon,
  ViewStreamIcon,
  ZoomInIcon,
  ZoomOutIcon,
} from '@/component/icon/material'
import { usePdfViewViewModel } from '../context'

export const Toolbar: React.FC = () => {
  const viewmodel = usePdfViewViewModel()
  const pageTotal: number = useStateValue(viewmodel.pageTotal$)
  const pageNo: number = useStateValue(viewmodel.pageNo$)
  const scale: number = useStateValue(viewmodel.scale$)
  const multiview: boolean = useStateValue(viewmodel.multiview$)

  const [isViewModeOpen, setIsViewModeOpen] = React.useState<boolean>(false)
  const dropdownRef = React.useRef<HTMLDivElement>(null)

  const onGotoPage = useEventCallback((e: React.ChangeEvent<HTMLInputElement>): void => {
    const value = parseInt(e.target.value)
    if (!isNaN(value) && value >= 1 && value <= pageTotal) {
      viewmodel.pageNo$.next(value)
    }
  })

  const onScaleChange = useEventCallback((e: React.ChangeEvent<HTMLInputElement>): void => {
    const value = parseFloat(e.target.value)
    viewmodel.scale$.next(value)
  })

  const onZoomIn = useEventCallback((): void => {
    viewmodel.scale$.setState(prev => Math.min(prev + 0.2, 3))
  })

  const onZoomOut = useEventCallback((): void => {
    viewmodel.scale$.setState(prev => Math.max(prev - 0.2, 0.5))
  })

  const toggleViewModeDropdown = React.useCallback(() => {
    setIsViewModeOpen(prev => !prev)
  }, [])

  const handleViewModeChange = React.useCallback(
    (mode: boolean) => {
      viewmodel.multiview$.next(mode)
      setIsViewModeOpen(false)
    },
    [viewmodel],
  )

  // Close dropdown when clicking outside
  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent): void => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsViewModeOpen(false)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [])

  return (
    <div className="fixed left-1/2 top-0 z-50 flex flex-row items-center gap-3 rounded-lg border border-gray-200 bg-white shadow-lg dark:border-gray-700 dark:bg-gray-800 px-4 py-1 transform -translate-x-1/2">
      <div className="relative" ref={dropdownRef}>
        <button
          className={cn(
            'flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-3 py-1 text-xs',
            'text-gray-700 shadow-sm hover:bg-gray-50',
            'dark:border-gray-600 dark:bg-gray-800 dark:text-gray-300 dark:hover:bg-gray-700',
            'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50',
            'transition-colors',
          )}
          onClick={toggleViewModeDropdown}
          aria-label="View mode"
          aria-expanded={isViewModeOpen}
        >
          {multiview ? (
            <ViewStreamIcon className="h-4 w-4" />
          ) : (
            <ViewPageByPageIcon className="h-4 w-4" />
          )}
          <span className="text-center leading-tight">{multiview ? 'Multi' : 'Single'}</span>
          <ChevronDownIcon
            className={cn('h-3 w-3 transition-transform', isViewModeOpen && 'rotate-180')}
          />
        </button>

        {isViewModeOpen && (
          <div
            className={cn(
              'absolute top-full left-0 z-50 mt-2 min-w-[120px] overflow-hidden rounded-lg',
              'border border-gray-200 bg-white shadow-lg',
              'dark:border-gray-600 dark:bg-gray-800',
            )}
          >
            <button
              className={cn(
                'flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm',
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
                'flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm',
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
      <div className="flex items-center space-x-2">
        <button
          className={cn(
            'p-1.5 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
            'disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent dark:disabled:hover:bg-transparent',
          )}
          onClick={() => viewmodel.pageNo$.setState(prev => Math.max(prev - 1, 1))}
          disabled={pageNo <= 1}
          aria-label="Previous page"
        >
          <ChevronLeftIcon />
        </button>
        <div className="flex items-center space-x-1">
          <input
            type="number"
            value={pageNo}
            onChange={onGotoPage}
            min={1}
            max={pageTotal}
            className={cn(
              'w-12 bg-gray-50 dark:bg-gray-700 border border-gray-300 dark:border-gray-600',
              'rounded px-2 py-1 text-xs text-center focus:outline-hidden focus:ring-2 focus:ring-blue-500',
            )}
            aria-label="Current page"
          />
          <span className="text-xs text-gray-500 dark:text-gray-400">of {pageTotal}</span>
        </div>
        <button
          className={cn(
            'p-1.5 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
            'disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent dark:disabled:hover:bg-transparent',
          )}
          onClick={() => viewmodel.pageNo$.setState(prev => Math.min(prev + 1, pageTotal))}
          disabled={pageNo >= pageTotal}
          aria-label="Next page"
        >
          <ChevronRightIcon />
        </button>
      </div>
      <div className="flex items-center gap-2">
        <button
          className={cn(
            'p-1.5 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
          )}
          onClick={onZoomOut}
          aria-label="Zoom out"
        >
          <ZoomOutIcon />
        </button>
        <div className="flex items-center space-x-2">
          <input
            type="range"
            min="0.5"
            max="3"
            step="0.1"
            value={scale}
            onChange={onScaleChange}
            className="h-2 w-20 cursor-pointer appearance-none rounded-lg bg-gray-200 dark:bg-gray-700"
            aria-label="Zoom level"
          />
          <span className="text-xs font-medium text-gray-600 dark:text-gray-300 min-w-[3rem]">
            {Math.round(scale * 100)}%
          </span>
        </div>
        <button
          className={cn(
            'p-1.5 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
          )}
          onClick={onZoomIn}
          aria-label="Zoom in"
        >
          <ZoomInIcon />
        </button>
      </div>
    </div>
  )
}

Toolbar.displayName = 'PdfViewToolbar'
