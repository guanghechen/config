import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import {
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
  const pages = useStateValue(viewmodel.pages$)
  const pageno = useStateValue(viewmodel.pageno$)
  const scale = useStateValue(viewmodel.scale$)
  const multiview = useStateValue(viewmodel.multiview$)

  const onGotoPage = useEventCallback((e: React.ChangeEvent<HTMLInputElement>): void => {
    const value = parseInt(e.target.value)
    if (!isNaN(value) && value >= 1 && value <= pages) {
      viewmodel.pageno$.next(value)
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

  const onViewModeToggle = useEventCallback((): void => {
    viewmodel.multiview$.setState(prev => !prev)
  })

  return (
    <div className="flex items-center justify-end rounded-lg border border-gray-200 bg-white shadow-xs dark:border-gray-700 dark:bg-gray-800">
      <div className="flex select-none items-center space-x-2 md:mr-2">
        <button
          className={cn(
            'p-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
            'disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent dark:disabled:hover:bg-transparent',
          )}
          onClick={() => viewmodel.pageno$.setState(prev => Math.max(prev - 1, 1))}
          disabled={pageno <= 1}
          aria-label="Previous page"
        >
          <ChevronLeftIcon />
        </button>
        <div className="flex items-center space-x-2">
          <input
            type="number"
            value={pageno}
            onChange={onGotoPage}
            min={1}
            max={pages}
            className={cn(
              'w-12 bg-gray-50 dark:bg-gray-700 border border-gray-300 dark:border-gray-600',
              'rounded px-2 py-1 text-sm text-center focus:outline-hidden focus:ring-2 focus:ring-blue-500',
            )}
            aria-label="Current page"
          />
          <span className="text-sm text-gray-500 dark:text-gray-400">of {pages}</span>
        </div>
        <button
          className={cn(
            'p-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
            'disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent dark:disabled:hover:bg-transparent',
          )}
          onClick={() => viewmodel.pageno$.setState(prev => Math.min(prev + 1, pages))}
          disabled={pageno >= pages}
          aria-label="Next page"
        >
          <ChevronRightIcon />
        </button>
      </div>
      <div className="flex select-none items-center gap-2">
        <button
          className={cn(
            'p-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
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
            className="h-2 w-24 cursor-pointer appearance-none rounded-lg bg-gray-200 dark:bg-gray-700"
            aria-label="Zoom level"
          />
          <span className="w-10 text-sm font-medium text-gray-600 dark:text-gray-300">
            {Math.round(scale * 100)}%
          </span>
        </div>
        <button
          className={cn(
            'rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
          )}
          onClick={onZoomIn}
          aria-label="Zoom in"
        >
          <ZoomInIcon />
        </button>
        <div className="mx-2 h-10 border-r border-gray-300 dark:border-gray-600" />
        <button
          className={cn(
            'p-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
            multiview && 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
          )}
          onClick={onViewModeToggle}
          aria-label={multiview ? 'Switch to single page view' : 'Switch to all pages view'}
          title={multiview ? 'Switch to single page view' : 'Switch to all pages view'}
        >
          {multiview ? <ViewStreamIcon /> : <ViewPageByPageIcon />}
        </button>
      </div>
    </div>
  )
}

Toolbar.displayName = 'PdfViewToolbar'
