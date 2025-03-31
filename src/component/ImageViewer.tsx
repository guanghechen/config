import { useEventCallback } from '@guanghechen/react-hooks'
import React from 'react'

interface IProps {
  readonly open: boolean
  readonly children: React.ReactNode
  readonly onClose: () => void
}

export const ImageViewer: React.FC<IProps> = props => {
  const { open, children, onClose } = props
  const [scale, setScale] = React.useState<number>(1)
  const [rotation, setRotation] = React.useState<number>(0)
  const [translateX, setTranslateX] = React.useState<number>(0)
  const [translateY, setTranslateY] = React.useState<number>(0)
  const [isDragging, setIsDragging] = React.useState(false)
  const [dragStart, setDragStart] = React.useState({ x: 0, y: 0 })

  const onZoomIn = React.useCallback(() => {
    setScale(prev => prev * 1.2)
  }, [])

  const onZoomOut = React.useCallback(() => {
    setScale(prev => prev / 1.2)
  }, [])

  const onRotateClockwise = React.useCallback(() => {
    setRotation(prev => prev + 90)
  }, [])

  const onRotateCounterClockwise = React.useCallback(() => {
    setRotation(prev => prev - 90)
  }, [])

  const onReset = React.useCallback(() => {
    setScale(1)
    setRotation(0)
    setTranslateX(0)
    setTranslateY(0)
  }, [])

  const onKeyDown = useEventCallback((event: KeyboardEvent) => {
    if (event.key === 'Escape') {
      onClose()
    }
  })

  const onMouseDown = React.useCallback((e: React.MouseEvent) => {
    setIsDragging(true)
    setDragStart({ x: e.clientX, y: e.clientY })
  }, [])

  const onMouseUp = React.useCallback(() => {
    setIsDragging(false)
  }, [])

  const onMouseMove = useEventCallback((e: React.MouseEvent) => {
    if (isDragging) {
      const dx = e.clientX - dragStart.x
      const dy = e.clientY - dragStart.y
      setTranslateX(prev => prev + dx)
      setTranslateY(prev => prev + dy)
      setDragStart({ x: e.clientX, y: e.clientY })
    }
  })

  const onWheel = useEventCallback((e: React.WheelEvent) => {
    e.preventDefault()
    e.stopPropagation()

    const scaleFactor = e.deltaY < 0 ? 1.1 : 0.9
    const newScale = scale * scaleFactor
    if (newScale >= 0.1 && newScale <= 10) setScale(newScale)
  })

  React.useEffect(() => {
    if (open) {
      document.addEventListener('keydown', onKeyDown)
      return () => {
        document.removeEventListener('keydown', onKeyDown)
      }
    }
  }, [open, onKeyDown])

  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex flex-col items-center bg-black/60 backdrop-blur-sm">
      <div className="absolute right-4 top-4 flex gap-4">
        <button
          onClick={onRotateCounterClockwise}
          title="Rotate Counter-Clockwise"
          className="rounded-full bg-gray-800/80 p-2 text-white hover:bg-gray-700"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
            <path d="M3 3v5h5" />
          </svg>
        </button>
        <button
          onClick={onRotateClockwise}
          title="Rotate Clockwise"
          className="rounded-full bg-gray-800/80 p-2 text-white hover:bg-gray-700"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M21 12a9 9 0 1 0-9 9 9.75 9.75 0 0 0 6.74-2.74L21 16" />
            <path d="M21 21v-5h-5" />
          </svg>
        </button>
        <button
          onClick={onZoomIn}
          title="Zoom In"
          className="rounded-full bg-gray-800/80 p-2 text-white hover:bg-gray-700"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
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
          onClick={onZoomOut}
          title="Zoom Out"
          className="rounded-full bg-gray-800/80 p-2 text-white hover:bg-gray-700"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
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
          onClick={onReset}
          title="Reset View"
          className="rounded-full bg-gray-800/80 p-2 text-white hover:bg-gray-700"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
            <polyline points="9 22 9 12 15 12 15 22" />
          </svg>
        </button>
        <button
          onClick={onClose}
          title="Close (Esc)"
          className="rounded-full bg-gray-800/80 p-2 text-white hover:bg-gray-700"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <line x1="18" y1="6" x2="6" y2="18" />
            <line x1="6" y1="6" x2="18" y2="18" />
          </svg>
        </button>
      </div>
      <div
        className="flex h-screen w-screen items-center justify-center overflow-hidden"
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onMouseLeave={onMouseUp}
        onWheel={onWheel}
      >
        <div
          className="transition-transform duration-200 bg-white/10 rounded-lg p-6 shadow-2xl"
          style={{
            transform: `translate(${translateX}px, ${translateY}px) scale(${scale}) rotate(${rotation}deg)`,
            cursor: isDragging ? 'grabbing' : 'grab',
          }}
        >
          {children}
        </div>
      </div>
    </div>
  )
}
ImageViewer.displayName = 'ImageViewer'
