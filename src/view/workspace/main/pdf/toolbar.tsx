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

interface IProps {
  readonly pages: number
  readonly pageno: number
  readonly scale: number
  readonly multiview: boolean
  readonly setPageno: React.Dispatch<React.SetStateAction<number>>
  readonly setScale: React.Dispatch<React.SetStateAction<number>>
  readonly setMultiview: React.Dispatch<React.SetStateAction<boolean>>
  readonly className?: string
}

export const PDFToolbar: React.FC<IProps> = props => {
  const { pages, pageno, scale, multiview, setPageno, setScale, setMultiview, className } = props

  const onGotoPage = React.useCallback(
    (e: React.ChangeEvent<HTMLInputElement>): void => {
      const value = parseInt(e.target.value)
      if (!isNaN(value) && value >= 1 && value <= pages) {
        setPageno(value)
      }
    },
    [pages, setPageno],
  )

  const onScaleChange = React.useCallback(
    (e: React.ChangeEvent<HTMLInputElement>): void => {
      const value = parseFloat(e.target.value)
      setScale(value)
    },
    [setScale],
  )

  const onZoomIn = React.useCallback((): void => {
    setScale(prev => Math.min(prev + 0.2, 3))
  }, [setScale])

  const onZoomOut = React.useCallback((): void => {
    setScale(prev => Math.max(prev - 0.2, 0.5))
  }, [setScale])

  const onViewModeToggle = React.useCallback((): void => {
    setMultiview(prev => !prev)
  }, [setMultiview])

  return (
    <div
      className={cn(
        'flex justify-between items-center bg-white dark:bg-gray-800 rounded-lg shadow-xs',
        'border border-gray-200 dark:border-gray-700',
        className,
      )}
    >
      <div className="mb-2 flex select-none items-center space-x-2 md:mb-0">
        <button
          className={cn(
            'p-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
            'disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent dark:disabled:hover:bg-transparent',
          )}
          onClick={() => setPageno(prev => Math.max(prev - 1, 1))}
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
          onClick={() => setPageno(prev => Math.min(prev + 1, pages))}
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

PDFToolbar.displayName = 'PDFToolbar'
