import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useImageViewViewModel } from '../context'

export const ContentPane: React.FC = () => {
  const viewmodel = useImageViewViewModel()
  const filepath: string = useStateValue(viewmodel.filepath$)
  const position = useStateValue(viewmodel.position$)
  const rotation: number = useStateValue(viewmodel.rotation$)
  const scale: number = useStateValue(viewmodel.scale$)
  const content = useStateValue(viewmodel.data$)
  const [isDragging, setIsDragging] = React.useState<boolean>(false)
  const [startPosition, setStartPosition] = React.useState<{ x: number; y: number }>({ x: 0, y: 0 })
  const containerRef = React.useRef<HTMLDivElement>(null)

  const onMouseDown = useEventCallback((e: React.MouseEvent<HTMLDivElement>): void => {
    setIsDragging(true)
    setStartPosition({
      x: e.clientX - position.x,
      y: e.clientY - position.y,
    })
  })

  const onMouseMove = useEventCallback((e: React.MouseEvent<HTMLDivElement>): void => {
    if (!isDragging) return

    viewmodel.position$.next({
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
      const currentScale = viewmodel.scale$.getSnapshot()
      viewmodel.scale$.next(Math.max(0.1, Math.min(currentScale + delta, 3)))
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
    <div
      ref={containerRef}
      onWheel={onWheel}
      className="relative flex h-full w-full items-center justify-center"
      onMouseDown={onMouseDown}
      onMouseMove={onMouseMove}
      onMouseUp={onMouseUp}
      onMouseLeave={onMouseLeave}
      style={{ cursor: isDragging ? 'grabbing' : 'grab' }}
    >
      {content?.url ? (
        <img
          src={content.url}
          alt={filepath || 'unknown'}
          className="max-h-full max-w-full object-contain transition-transform duration-100 ease-in-out"
          style={{
            transform: `translate(${position.x}px, ${position.y}px) scale(${scale}) rotate(${rotation}deg)`,
            transformOrigin: 'center center',
          }}
          draggable={false}
        />
      ) : (
        <div className="flex items-center justify-center text-gray-500 dark:text-gray-400">
          {content === null ? 'Failed to load image' : 'Loading...'}
        </div>
      )}
    </div>
  )
}

ContentPane.displayName = 'ImageViewContentPane'
