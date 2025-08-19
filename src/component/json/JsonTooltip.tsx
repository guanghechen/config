import cn from 'clsx'
import React from 'react'
import { Json } from './index'

interface IProps {
  readonly data: unknown
  readonly position: { x: number; y: number }
  readonly visible: boolean
  readonly maxWidth?: number
  readonly maxHeight?: number
  readonly onMouseEnter?: () => void
  readonly onMouseLeave?: () => void
}

export const JsonTooltip: React.FC<IProps> = props => {
  const {
    data,
    position,
    visible,
    maxWidth = 400,
    maxHeight = 300,
    onMouseEnter,
    onMouseLeave,
  } = props

  if (!visible) return null

  // Calculate smart positioning based on anchor position
  const getSmartPosition = (): { left: number; top: number } => {
    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight
    const offset = 10

    // Determine if tooltip should appear to the right or left of the anchor
    const shouldAppearRight = position.x + maxWidth + offset < viewportWidth

    let left: number
    let top: number

    if (shouldAppearRight) {
      // Appear to the right of the boundary (no overlap)
      left = position.x + offset
    } else {
      // Appear to the left of the boundary (no overlap)
      left = position.x - maxWidth - offset
    }

    // Center tooltip vertically relative to the anchor point
    top = position.y - maxHeight / 2

    // Ensure tooltip stays within viewport bounds
    left = Math.max(20, Math.min(left, viewportWidth - maxWidth - 20))
    top = Math.max(20, Math.min(top, viewportHeight - maxHeight - 20))

    return { left, top }
  }

  const { left, top } = getSmartPosition()

  // Handle different data types
  const renderContent = (): React.ReactNode => {
    if (data === null) {
      return <span className="text-gray-500 italic">null</span>
    }

    if (data === undefined) {
      return <span className="text-gray-500 italic">undefined</span>
    }

    if (typeof data === 'string') {
      return <div className="whitespace-pre-wrap break-words text-sm">{data}</div>
    }

    if (typeof data === 'number' || typeof data === 'boolean') {
      return <div className="text-sm font-mono">{String(data)}</div>
    }

    // For objects and arrays, use the Json component
    return (
      <div className="text-sm">
        <Json json={data} initialCollapsed="expanded" />
      </div>
    )
  }

  return (
    <div
      role="tooltip"
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
      className={cn(
        'fixed z-50',
        'bg-white dark:bg-gray-800',
        'border border-gray-200 dark:border-gray-600',
        'rounded-lg shadow-lg',
        'p-3',
        'transition-opacity duration-200',
        'overflow-auto',
        'cursor-default select-text',
      )}
      style={{
        left,
        top,
        maxWidth,
        maxHeight,
      }}
    >
      {renderContent()}
    </div>
  )
}

JsonTooltip.displayName = 'JsonTooltip'
