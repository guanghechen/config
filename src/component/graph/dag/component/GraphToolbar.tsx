import cn from 'clsx'
import React from 'react'
import type { IToolbarProps } from '../types'

export const GraphToolbar: React.FC<IToolbarProps> = ({
  transform,
  onZoomIn,
  onZoomOut,
  onZoomReset,
  onFitToView,
  onReLayout,
  theme = 'light',
}) => {
  const isDark = theme === 'dark'

  const buttonClass = cn('flex items-center justify-center w-8 h-8 rounded transition-colors', {
    'bg-white hover:bg-gray-50 border border-gray-200 text-gray-700 hover:text-gray-900': !isDark,
    'bg-gray-800 hover:bg-gray-700 border border-gray-600 text-gray-300 hover:text-white': isDark,
  })

  const separatorClass = cn('w-full h-px', {
    'bg-gray-200': !isDark,
    'bg-gray-600': isDark,
  })

  const containerClass = cn(
    'flex flex-col gap-1 p-2 rounded-lg shadow-lg border backdrop-blur-sm',
    {
      'bg-white/90 border-gray-200': !isDark,
      'bg-gray-900/90 border-gray-600': isDark,
    },
  )

  const zoomLevel = Math.round(transform.scale * 100)

  return (
    <div className={containerClass}>
      <button
        onClick={onZoomIn}
        className={buttonClass}
        title="Zoom In"
        disabled={transform.scale >= 5}
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 6v6m0 0v6m0-6h6m-6 0H6"
          />
        </svg>
      </button>

      <button
        onClick={onZoomOut}
        className={buttonClass}
        title="Zoom Out"
        disabled={transform.scale <= 0.1}
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18 12H6" />
        </svg>
      </button>

      <div className={separatorClass} />

      <div
        className={cn(
          'flex items-center justify-center h-6 text-xs font-mono',
          isDark ? 'text-gray-300' : 'text-gray-600',
        )}
        title={`Zoom Level: ${zoomLevel}%`}
      >
        {zoomLevel}%
      </div>

      <button onClick={onZoomReset} className={buttonClass} title="Reset Zoom">
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
          />
        </svg>
      </button>

      <div className={separatorClass} />

      <button onClick={onFitToView} className={buttonClass} title="Fit to View">
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"
          />
        </svg>
      </button>

      <button onClick={onReLayout} className={buttonClass} title="Re-layout Graph">
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
          />
        </svg>
      </button>
    </div>
  )
}

GraphToolbar.displayName = 'GraphToolbar'
