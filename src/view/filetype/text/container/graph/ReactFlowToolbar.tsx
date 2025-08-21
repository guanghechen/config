import { Panel, useReactFlow } from '@xyflow/react'
import cn from 'clsx'
import React from 'react'

interface IProps {
  readonly theme?: 'light' | 'dark'
  readonly onReLayout?: () => void
}

export const ReactFlowToolbar: React.FC<IProps> = props => {
  const { theme = 'light', onReLayout } = props
  const { zoomIn, zoomOut, setCenter, fitView } = useReactFlow()

  const handleZoomIn = React.useCallback(() => {
    void zoomIn()
  }, [zoomIn])

  const handleZoomOut = React.useCallback(() => {
    void zoomOut()
  }, [zoomOut])

  const handleFitView = React.useCallback(() => {
    void fitView({ padding: 0.2, duration: 800 })
  }, [fitView])

  const handleResetZoom = React.useCallback(() => {
    void setCenter(0, 0, { zoom: 1, duration: 800 })
  }, [setCenter])

  const buttonClass = cn(
    'w-10 h-10 rounded-lg border transition-all duration-200',
    'flex items-center justify-center text-sm font-medium',
    'hover:shadow-md focus:outline-none focus:ring-2',
    {
      // Light theme
      'bg-white border-gray-300 text-gray-700 hover:bg-gray-50 focus:ring-blue-500':
        theme === 'light',
      // Dark theme
      'bg-gray-800 border-gray-600 text-gray-200 hover:bg-gray-700 focus:ring-blue-400':
        theme === 'dark',
    },
  )

  return (
    <Panel position="bottom-left">
      <div className="flex flex-col gap-2 p-2 bg-white/90 dark:bg-gray-900/90 rounded-lg shadow-lg backdrop-blur-sm">
        <button onClick={handleZoomIn} className={buttonClass} title="Zoom In" aria-label="Zoom In">
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
          onClick={handleZoomOut}
          className={buttonClass}
          title="Zoom Out"
          aria-label="Zoom Out"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 12H4" />
          </svg>
        </button>

        <button
          onClick={handleFitView}
          className={buttonClass}
          title="Fit to View"
          aria-label="Fit to View"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"
            />
          </svg>
        </button>

        <button
          onClick={handleResetZoom}
          className={buttonClass}
          title="Reset Zoom"
          aria-label="Reset Zoom"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
            />
          </svg>
        </button>

        {onReLayout && (
          <button
            onClick={onReLayout}
            className={buttonClass}
            title="Re-layout"
            aria-label="Re-layout"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"
              />
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 9h6v6H9z" />
            </svg>
          </button>
        )}
      </div>
    </Panel>
  )
}

ReactFlowToolbar.displayName = 'ReactFlowToolbar'
