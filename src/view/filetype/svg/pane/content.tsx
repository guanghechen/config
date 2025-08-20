import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useSvgViewViewModel } from '../context'

export const ContentPane: React.FC = () => {
  const viewmodel = useSvgViewViewModel()
  const scale = useStateValue(viewmodel.scale$)
  const rotation = useStateValue(viewmodel.rotation$)
  const position = useStateValue(viewmodel.position$)
  const content = useStateValue(viewmodel.content$)

  const [isDragging, setIsDragging] = React.useState<boolean>(false)
  const [startPosition, setStartPosition] = React.useState<{ x: number; y: number }>({ x: 0, y: 0 })
  const containerRef = React.useRef<HTMLDivElement>(null)

  const isLoading = !content

  const onMouseDown = useEventCallback((e: React.MouseEvent<HTMLDivElement>): void => {
    e.preventDefault()
    setIsDragging(true)
    setStartPosition({
      x: e.clientX - position.x,
      y: e.clientY - position.y,
    })
  })

  const onMouseMove = useEventCallback((e: React.MouseEvent<HTMLDivElement>): void => {
    if (!isDragging) return
    e.preventDefault()

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
      viewmodel.scale$.setState(prevScale => Math.max(0.1, Math.min(prevScale + delta, 5)))
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

  // Global mouse events for better drag handling
  React.useEffect(() => {
    if (!isDragging) return

    const handleGlobalMouseMove = (e: MouseEvent): void => {
      e.preventDefault()
      viewmodel.position$.next({
        x: e.clientX - startPosition.x,
        y: e.clientY - startPosition.y,
      })
    }

    const handleGlobalMouseUp = (): void => {
      setIsDragging(false)
    }

    document.addEventListener('mousemove', handleGlobalMouseMove)
    document.addEventListener('mouseup', handleGlobalMouseUp)

    return () => {
      document.removeEventListener('mousemove', handleGlobalMouseMove)
      document.removeEventListener('mouseup', handleGlobalMouseUp)
    }
  }, [isDragging, startPosition.x, startPosition.y, viewmodel])

  return (
    <div
      ref={containerRef}
      onWheel={onWheel}
      className="relative flex h-full w-full min-h-0 overflow-hidden items-center justify-center"
      onMouseDown={onMouseDown}
      onMouseMove={onMouseMove}
      onMouseUp={onMouseUp}
      onMouseLeave={onMouseLeave}
      style={{ cursor: isDragging ? 'grabbing' : 'grab' }}
    >
      {isLoading && (
        <div className="flex items-center justify-center">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-gray-300 border-t-blue-600" />
        </div>
      )}

      {!isLoading && content && (
        <div
          className="svg-container pointer-events-none select-none"
          style={{
            transform: `translate(${position.x}px, ${position.y}px) scale(${scale}) rotate(${rotation}deg)`,
            transformOrigin: 'center center',
            transition: isDragging ? 'none' : 'transform 100ms ease-in-out',
          }}
          dangerouslySetInnerHTML={{ __html: content }}
        />
      )}
    </div>
  )
}

ContentPane.displayName = 'SvgViewContentPane'
