import cn from 'clsx'
import React from 'react'
import { Json } from './index'

interface IProps {
  readonly data: unknown
  readonly position: { x: number; y: number }
  readonly visible: boolean
  readonly maxWidth?: number
  readonly maxHeight?: number
  readonly onFocus?: () => void
  readonly onBlur?: () => void
  readonly onKeyDown?: (event: React.KeyboardEvent) => void
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
    onFocus,
    onBlur,
    onKeyDown,
    onMouseEnter,
    onMouseLeave,
  } = props

  const tooltipRef = React.useRef<HTMLDivElement>(null)

  // Handle keyboard navigation
  const handleKeyDown = React.useCallback(
    (event: React.KeyboardEvent) => {
      if (event.key === 'Escape') {
        onBlur?.()
        return
      }
      onKeyDown?.(event)
    },
    [onBlur, onKeyDown],
  )

  // Auto-focus when tooltip becomes visible
  React.useEffect(() => {
    if (visible && tooltipRef.current) {
      tooltipRef.current.focus()
    }
  }, [visible])

  if (!visible) return null

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
      ref={tooltipRef}
      tabIndex={0}
      role="tooltip"
      aria-live="polite"
      onFocus={onFocus}
      onBlur={onBlur}
      onKeyDown={handleKeyDown}
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
        'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2',
        'cursor-default select-text',
      )}
      style={{
        left: Math.min(position.x + 15, window.innerWidth - maxWidth - 20),
        top: Math.max(position.y + 15, 20),
        maxWidth,
        maxHeight,
        transform: position.y > window.innerHeight / 2 ? 'translateY(-100%)' : undefined,
      }}
    >
      {renderContent()}
    </div>
  )
}

JsonTooltip.displayName = 'JsonTooltip'
