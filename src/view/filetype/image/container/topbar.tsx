import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import {
  ResetZoomIcon,
  RotateLeftIcon,
  RotateRightIcon,
  ZoomInIcon,
  ZoomOutIcon,
} from '@/component/icon/material'
import { useImageViewViewModel } from '../context'

export const ImageTopbar: React.FC = () => {
  const viewmodel = useImageViewViewModel()
  const scale = useStateValue(viewmodel.scale$)

  const onZoomIn = React.useCallback((): void => {
    const currentScale = viewmodel.scale$.getSnapshot()
    viewmodel.scale$.next(Math.min(currentScale + 0.2, 5))
  }, [viewmodel])

  const onZoomOut = React.useCallback((): void => {
    const currentScale = viewmodel.scale$.getSnapshot()
    viewmodel.scale$.next(Math.max(currentScale - 0.2, 0.1))
  }, [viewmodel])

  const onScaleChange = React.useCallback(
    (e: React.ChangeEvent<HTMLInputElement>): void => {
      const value = parseFloat(e.target.value)
      viewmodel.scale$.next(value)
    },
    [viewmodel],
  )

  const onResetZoom = React.useCallback((): void => {
    viewmodel.scale$.next(1)
    viewmodel.rotation$.next(0)
    viewmodel.position$.next({ x: 0, y: 0 })
  }, [viewmodel])

  const onRotateLeft = React.useCallback((): void => {
    const currentRotation = viewmodel.rotation$.getSnapshot()
    viewmodel.rotation$.next(currentRotation - 90)
  }, [viewmodel])

  const onRotateRight = React.useCallback((): void => {
    const currentRotation = viewmodel.rotation$.getSnapshot()
    viewmodel.rotation$.next(currentRotation + 90)
  }, [viewmodel])

  return (
    <div className="flex items-center justify-end rounded-lg border border-gray-200 bg-white shadow-xs dark:border-gray-700 dark:bg-gray-800">
      <div className="flex select-none items-center space-x-2 md:mr-2">
        <div className="flex items-center gap-2">
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
          <div className="flex items-center">
            <input
              type="range"
              min="0.1"
              max="5"
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
        </div>
        <div className="mx-2 h-10 border-r border-gray-300 dark:border-gray-600" />
        <button
          className={cn(
            'p-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
          )}
          onClick={onRotateLeft}
          aria-label="Rotate left"
        >
          <RotateLeftIcon />
        </button>
        <button
          className={cn(
            'p-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
          )}
          onClick={onRotateRight}
          aria-label="Rotate right"
        >
          <RotateRightIcon />
        </button>
        <div className="mx-2 h-10 border-r border-gray-300 dark:border-gray-600" />
        <button
          className={cn(
            'p-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100',
            'dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-700',
            'focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors',
          )}
          onClick={onResetZoom}
          aria-label="Reset view"
        >
          <ResetZoomIcon />
        </button>
      </div>
    </div>
  )
}
ImageTopbar.displayName = 'ImageTopbar'
