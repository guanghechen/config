import React from 'react'
import type { IWhiteboardRichContent } from '../context/types'

interface IWhiteboardImageContentProps {
  readonly richContent: IWhiteboardRichContent
}

export const WhiteboardImageContent: React.FC<IWhiteboardImageContentProps> = ({ richContent }) => {
  const [isDragging, setIsDragging] = React.useState<boolean>(false)
  const [position, setPosition] = React.useState<{ x: number; y: number }>({ x: 0, y: 0 })
  const [scale, setScale] = React.useState<number>(1)
  const [startPosition, setStartPosition] = React.useState<{ x: number; y: number }>({ x: 0, y: 0 })
  const containerRef = React.useRef<HTMLDivElement>(null)

  React.useEffect(() => {
    // Clean up blob URL when component unmounts or when richContent changes
    return () => {
      if (richContent.data.startsWith('blob:')) {
        URL.revokeObjectURL(richContent.data)
      }
    }
  }, [richContent.data])

  const onMouseDown = React.useCallback(
    (e: React.MouseEvent<HTMLDivElement>): void => {
      setIsDragging(true)
      setStartPosition({
        x: e.clientX - position.x,
        y: e.clientY - position.y,
      })
    },
    [position.x, position.y],
  )

  const onMouseMove = React.useCallback(
    (e: React.MouseEvent<HTMLDivElement>): void => {
      if (!isDragging) return

      setPosition({
        x: e.clientX - startPosition.x,
        y: e.clientY - startPosition.y,
      })
    },
    [isDragging, startPosition.x, startPosition.y],
  )

  const onMouseUp = React.useCallback((): void => {
    setIsDragging(false)
  }, [])

  const onMouseLeave = React.useCallback((): void => {
    setIsDragging(false)
  }, [])

  const onWheel = React.useCallback((e: React.WheelEvent<HTMLDivElement>): void => {
    if (e.ctrlKey) {
      e.preventDefault()
      const delta = e.deltaY < 0 ? 0.1 : -0.1
      setScale(prevScale => Math.max(0.1, Math.min(prevScale + delta, 3)))
    }
  }, [])

  React.useEffect(() => {
    const container = containerRef.current
    if (container) {
      const preventDefaultWheel = (e: WheelEvent): void => {
        if (e.ctrlKey) {
          e.preventDefault()
        }
      }

      container.addEventListener('wheel', preventDefaultWheel, { passive: false })
      return () => container.removeEventListener('wheel', preventDefaultWheel)
    }
  }, [])

  const formatFileSize = (bytes?: number): string => {
    if (!bytes) return 'Unknown size'
    const kb = bytes / 1024
    if (kb < 1024) return `${kb.toFixed(1)} KB`
    const mb = kb / 1024
    return `${mb.toFixed(1)} MB`
  }

  return (
    <div className="flex h-full w-full flex-col">
      {/* Image metadata */}
      <div className="flex items-center justify-between border-b border-gray-200 bg-gray-50 px-4 py-2 text-sm text-gray-600 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-300">
        <div className="flex items-center space-x-4">
          {richContent.metadata?.filename && <span>📁 {richContent.metadata.filename}</span>}
          {richContent.metadata?.mimeType && <span>🖼️ {richContent.metadata.mimeType}</span>}
          {richContent.metadata?.size && (
            <span>📏 {formatFileSize(richContent.metadata.size)}</span>
          )}
        </div>
        <div className="text-xs text-gray-500 dark:text-gray-400">
          Ctrl+Scroll to zoom • Drag to move
        </div>
      </div>

      {/* Image viewer */}
      <div
        ref={containerRef}
        onWheel={onWheel}
        className="relative flex flex-1 items-center justify-center overflow-hidden bg-gray-100 dark:bg-gray-900"
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onMouseLeave={onMouseLeave}
        style={{ cursor: isDragging ? 'grabbing' : 'grab' }}
      >
        <img
          src={richContent.data}
          alt={richContent.metadata?.filename || 'Pasted image'}
          className="max-h-full max-w-full object-contain transition-transform duration-100 ease-in-out"
          style={{
            transform: `translate(${position.x}px, ${position.y}px) scale(${scale})`,
            transformOrigin: 'center center',
          }}
          draggable={false}
          onLoad={e => {
            const img = e.target as HTMLImageElement
            // We don't modify the props directly, just log dimensions for potential future use
            if (
              richContent.metadata &&
              !richContent.metadata.width &&
              !richContent.metadata.height
            ) {
              // Image dimensions: img.naturalWidth x img.naturalHeight
              console.debug('Image loaded:', {
                width: img.naturalWidth,
                height: img.naturalHeight,
                filename: richContent.metadata.filename,
              })
            }
          }}
        />
      </div>

      {/* Zoom indicator */}
      <div className="absolute bottom-4 left-4 rounded bg-black/50 px-2 py-1 text-xs text-white backdrop-blur-sm">
        {Math.round(scale * 100)}%
      </div>
    </div>
  )
}

WhiteboardImageContent.displayName = 'WhiteboardImageContent'
