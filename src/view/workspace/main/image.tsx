import { useEventCallback } from '@guanghechen/react-hooks'
import React from 'react'
import { CopyButton } from '@/component/CopyButton'
import { toSearch } from '@/util/url'

export interface ImageContainerProps {
  readonly workspace: string | null
  readonly filepath: string | null
}

export const ImageContainer: React.FC<ImageContainerProps> = props => {
  const { filepath, workspace } = props
  const [scale, setScale] = React.useState<number>(1)
  const [rotation, setRotation] = React.useState<number>(0)
  const [isDragging, setIsDragging] = React.useState<boolean>(false)
  const [position, setPosition] = React.useState<{ x: number; y: number }>({ x: 0, y: 0 })
  const [startPosition, setStartPosition] = React.useState<{ x: number; y: number }>({ x: 0, y: 0 })
  const containerRef = React.useRef<HTMLDivElement>(null)

  const url = React.useMemo<string>(() => {
    const search = toSearch({ filepath, workspace })
    return `/api/file${search}`
  }, [filepath, workspace])

  const onZoomIn = React.useCallback((): void => {
    setScale(prevScale => Math.min(prevScale + 0.1, 3))
  }, [])

  const onZoomOut = React.useCallback((): void => {
    setScale(prevScale => Math.max(prevScale - 0.1, 0.1))
  }, [])

  const onResetZoom = React.useCallback((): void => {
    setScale(1)
    setRotation(0)
    setPosition({ x: 0, y: 0 })
  }, [])

  const onRotateLeft = React.useCallback((): void => {
    setRotation(prevRotation => prevRotation - 90)
  }, [])

  const onRotateRight = React.useCallback((): void => {
    setRotation(prevRotation => prevRotation + 90)
  }, [])

  const onMouseDown = useEventCallback((e: React.MouseEvent<HTMLDivElement>): void => {
    setIsDragging(true)
    setStartPosition({
      x: e.clientX - position.x,
      y: e.clientY - position.y,
    })
  })

  const onMouseMove = useEventCallback((e: React.MouseEvent<HTMLDivElement>): void => {
    if (!isDragging) return

    setPosition({
      x: e.clientX - startPosition.x,
      y: e.clientY - startPosition.y,
    })
  })

  const onMouseUp = React.useCallback((): void => {
    setIsDragging(false)
  }, [])

  const onMouseLeave = React.useCallback((): void => {
    setIsDragging(false)
  }, [])

  const onWheel = useEventCallback((e: React.WheelEvent<HTMLDivElement>): void => {
    if (e.ctrlKey) {
      e.preventDefault()
      const delta = e.deltaY < 0 ? 0.1 : -0.1
      setScale(prevScale => Math.max(0.1, Math.min(prevScale + delta, 3)))
    }
  })

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

  return (
    <div className="flex h-full flex-col">
      <div className="mb-4 flex items-center justify-between border-b border-gray-200 pb-3 dark:border-gray-700">
        <div className="overflow-hidden">
          <h2 className="truncate font-mono text-sm font-medium text-gray-700 dark:text-gray-300">
            {filepath}
          </h2>
        </div>
        <div className="flex items-center space-x-2">
          <button
            onClick={onZoomOut}
            className="rounded p-1 text-gray-500 hover:bg-gray-200 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
            title="Zoom out"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
              <line x1="8" y1="11" x2="14" y2="11" />
            </svg>
          </button>
          <button
            onClick={onZoomIn}
            className="rounded p-1 text-gray-500 hover:bg-gray-200 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
            title="Zoom in"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
              <line x1="11" y1="8" x2="11" y2="14" />
              <line x1="8" y1="11" x2="14" y2="11" />
            </svg>
          </button>
          <button
            onClick={onRotateLeft}
            className="rounded p-1 text-gray-500 hover:bg-gray-200 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
            title="Rotate left"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M2 12c0 5.5 4.5 10 10 10s10-4.5 10-10S17.5 2 12 2" />
              <path d="M12 2v10l-4-4" />
            </svg>
          </button>
          <button
            onClick={onRotateRight}
            className="rounded p-1 text-gray-500 hover:bg-gray-200 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
            title="Rotate right"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M22 12c0 5.5-4.5 10-10 10S2 17.5 2 12 6.5 2 12 2" />
              <path d="M12 2v10l4-4" />
            </svg>
          </button>
          <button
            onClick={onResetZoom}
            className="rounded p-1 text-gray-500 hover:bg-gray-200 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
            title="Reset view"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M3 2v6h6" />
              <path d="M21 12A9 9 0 0 0 3.86 8.14" />
              <path d="M21 22v-6h-6" />
              <path d="M3 12a9 9 0 0 0 17.14 3.86" />
            </svg>
          </button>
          <CopyButton
            className="flex-shrink-0 rounded p-1 text-gray-500 hover:bg-gray-200 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
            calcContentForCopy={() => filepath || ''}
          />
        </div>
      </div>
      <div
        ref={containerRef}
        className="flex-1 overflow-hidden bg-gray-100 dark:bg-gray-800"
        onWheel={onWheel}
      >
        <div
          className="relative flex h-full w-full items-center justify-center"
          onMouseDown={onMouseDown}
          onMouseMove={onMouseMove}
          onMouseUp={onMouseUp}
          onMouseLeave={onMouseLeave}
          style={{ cursor: isDragging ? 'grabbing' : 'grab' }}
        >
          <img
            src={url}
            alt={filepath || 'unknown'}
            className="max-h-full max-w-full object-contain transition-transform duration-100 ease-in-out"
            style={{
              transform: `translate(${position.x}px, ${position.y}px) scale(${scale}) rotate(${rotation}deg)`,
              transformOrigin: 'center center',
            }}
            draggable={false}
          />
        </div>
      </div>
    </div>
  )
}

ImageContainer.displayName = 'ImageContainer'
export default ImageContainer
