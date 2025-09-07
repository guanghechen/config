import cn from 'clsx'
import React from 'react'

interface IZoomControlsProps {
  zoom: number
  onZoomIn: () => void
  onZoomOut: () => void
  onResetZoom: () => void
  className?: string
}

export const ZoomControls: React.FC<IZoomControlsProps> = ({
  zoom,
  onZoomIn,
  onZoomOut,
  onResetZoom,
  className,
}) => {
  return (
    <div
      className={cn(
        'bg-white/90 dark:bg-gray-800/90 backdrop-blur-sm rounded-lg border border-gray-200/60 dark:border-gray-600/60 shadow-sm px-2 py-1 flex items-center gap-1 h-10',
        className,
      )}
    >
      <button
        type="button"
        onClick={onZoomOut}
        className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
        title="Zoom out"
      >
        <span className="text-sm font-medium">−</span>
      </button>

      <button
        type="button"
        onClick={onResetZoom}
        className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors min-w-[60px] text-center"
        title="Reset zoom"
      >
        <span className="text-sm font-medium">{Math.round(zoom * 100)}%</span>
      </button>

      <button
        type="button"
        onClick={onZoomIn}
        className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
        title="Zoom in"
      >
        <span className="text-sm font-medium">+</span>
      </button>
    </div>
  )
}
