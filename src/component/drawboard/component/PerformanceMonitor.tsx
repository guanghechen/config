import React from 'react'
import { gridCacheManager, usePerformanceMetrics } from '../util/performance'

interface IPerformanceMonitorProps {
  enabled?: boolean
  position?: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right'
  className?: string
}

const getPositionClasses = (position: string): string => {
  switch (position) {
    case 'top-left':
      return 'top-4 left-4'
    case 'top-right':
      return 'top-4 right-4'
    case 'bottom-left':
      return 'bottom-4 left-4'
    case 'bottom-right':
      return 'bottom-4 right-4'
    default:
      return 'top-4 right-4'
  }
}

export const PerformanceMonitor: React.FC<IPerformanceMonitorProps> = ({
  enabled = false,
  position = 'top-right',
  className = '',
}) => {
  const metrics = usePerformanceMetrics(enabled)
  const [isVisible, setIsVisible] = React.useState(enabled)
  const [gridStats, setGridStats] = React.useState({ size: 0, maxSize: 0, hitRate: 0 })

  // Update grid cache stats periodically
  React.useEffect(() => {
    if (!isVisible) return

    const updateGridStats = (): void => {
      setGridStats(gridCacheManager.getCacheStats())
    }

    updateGridStats()
    const interval = setInterval(updateGridStats, 1000) // Update every second

    return () => clearInterval(interval)
  }, [isVisible])

  // Toggle visibility with keyboard shortcut
  React.useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent): void => {
      if (event.ctrlKey && event.shiftKey && event.key === 'P') {
        event.preventDefault()
        setIsVisible(prev => !prev)
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [])

  if (!isVisible) return null

  const getFrameRateColor = (fps: number): string => {
    if (fps >= 55) return 'text-green-400'
    if (fps >= 30) return 'text-yellow-400'
    return 'text-red-400'
  }

  const getRenderTimeColor = (time: number): string => {
    if (time <= 8) return 'text-green-400'
    if (time <= 16) return 'text-yellow-400'
    return 'text-red-400'
  }

  return (
    <div
      className={`fixed z-50 ${getPositionClasses(position)} ${className}`}
      style={{ pointerEvents: 'none' }}
    >
      <div className="bg-black/80 text-white text-xs font-mono rounded-lg p-2 space-y-1 border border-gray-600">
        <div className="flex items-center justify-between space-x-3">
          <span className="text-gray-300">FPS:</span>
          <span className={getFrameRateColor(metrics.frameRate)}>{metrics.frameRate}</span>
        </div>

        <div className="flex items-center justify-between space-x-3">
          <span className="text-gray-300">Render:</span>
          <span className={getRenderTimeColor(metrics.renderTime)}>{metrics.renderTime}ms</span>
        </div>

        <div className="flex items-center justify-between space-x-3">
          <span className="text-gray-300">Frames:</span>
          <span className="text-blue-400">{metrics.frameCount}</span>
        </div>

        <div className="border-t border-gray-600 pt-1 space-y-1">
          <div className="flex items-center justify-between space-x-3">
            <span className="text-gray-300">Grid Cache:</span>
            <span className="text-purple-400">
              {gridStats.size}/{gridStats.maxSize}
            </span>
          </div>

          <div className="flex items-center justify-between space-x-3">
            <span className="text-gray-300">Hit Rate:</span>
            <span className={gridStats.hitRate > 0.7 ? 'text-green-400' : 'text-yellow-400'}>
              {(gridStats.hitRate * 100).toFixed(0)}%
            </span>
          </div>
        </div>

        <div className="text-gray-500 text-xs pt-1 border-t border-gray-600">
          Ctrl+Shift+P to toggle
        </div>
      </div>
    </div>
  )
}

interface IDevPerformanceMonitorProps extends Omit<IPerformanceMonitorProps, 'enabled'> {}

export const DevPerformanceMonitor: React.FC<IDevPerformanceMonitorProps> = props => {
  // Only show in development mode
  const isDevelopment = process.env.NODE_ENV === 'development'

  if (!isDevelopment) return null

  return <PerformanceMonitor {...props} enabled={true} />
}
