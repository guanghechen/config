import React from 'react'

interface IProps {
  readonly src: string
  readonly alt: string
  readonly isOpen: boolean
  readonly initialScale?: number
  readonly initialRotation?: number
  readonly onClose?: (e: React.MouseEvent) => void
}

// Scale step for mouse wheel scaling
const SCALE_STEP = 0.1

export const ImageViewer: React.FC<IProps> = props => {
  const { src, alt, isOpen, initialScale = 1, initialRotation = 0, onClose } = props
  const [rotation, setRotation] = React.useState(initialRotation)
  const [scale, setScale] = React.useState(initialScale)
  const [position, setPosition] = React.useState({ x: 0, y: 0 })
  const [isDragging, setIsDragging] = React.useState(false)
  const [dragStart, setDragStart] = React.useState({ x: 0, y: 0 })

  const handleClose = React.useCallback(
    (e: React.MouseEvent): void => {
      e.stopPropagation()
      setRotation(initialRotation)
      setScale(initialScale)
      setPosition({ x: 0, y: 0 })
      onClose?.(e)
    },
    [initialRotation, initialScale, onClose],
  )

  const handleRotateLeft = React.useCallback((e: React.MouseEvent): void => {
    e.stopPropagation()
    setRotation(prevRotation => prevRotation - 90)
  }, [])

  const handleRotateRight = React.useCallback((e: React.MouseEvent): void => {
    e.stopPropagation()
    setRotation(prevRotation => prevRotation + 90)
  }, [])

  const handleZoomIn = React.useCallback((e: React.MouseEvent): void => {
    e.stopPropagation()
    setScale(prevScale => prevScale + 0.2)
  }, [])

  const handleZoomOut = React.useCallback((e: React.MouseEvent): void => {
    e.stopPropagation()
    setScale(prevScale => Math.max(0.2, prevScale - 0.2))
  }, [])

  const handleReset = React.useCallback(
    (e: React.MouseEvent): void => {
      e.stopPropagation()
      setRotation(initialRotation)
      setScale(initialScale)
      setPosition({ x: 0, y: 0 })
    },
    [initialRotation, initialScale],
  )

  const handleMouseDown = React.useCallback(
    (e: React.MouseEvent): void => {
      e.stopPropagation()
      setIsDragging(true)
      setDragStart({ x: e.clientX - position.x, y: e.clientY - position.y })
    },
    [position],
  )

  const handleMouseMove = React.useCallback(
    (e: React.MouseEvent): void => {
      if (isDragging) {
        e.stopPropagation()
        setPosition({
          x: e.clientX - dragStart.x,
          y: e.clientY - dragStart.y,
        })
      }
    },
    [isDragging, dragStart],
  )

  const handleMouseUp = React.useCallback((): void => {
    setIsDragging(false)
  }, [])

  // Handle mouse events outside the component
  React.useEffect(() => {
    if (isOpen) {
      const handleGlobalMouseUp = (): void => {
        setIsDragging(false)
      }

      const handleGlobalMouseMove = (e: MouseEvent): void => {
        if (isDragging) {
          setPosition({
            x: e.clientX - dragStart.x,
            y: e.clientY - dragStart.y,
          })
        }
      }

      window.addEventListener('mouseup', handleGlobalMouseUp)
      window.addEventListener('mousemove', handleGlobalMouseMove)

      return () => {
        window.removeEventListener('mouseup', handleGlobalMouseUp)
        window.removeEventListener('mousemove', handleGlobalMouseMove)
      }
    }
  }, [isOpen, isDragging, dragStart])

  if (!isOpen) return null

  return (
    <div
      className="fixed inset-0 z-50 flex select-none flex-col items-center justify-center bg-black/80"
      onClick={handleClose}
    >
      <div className="absolute right-4 top-4 flex gap-4">
        <button
          className="rounded-full bg-gray-800 p-2 text-white hover:bg-gray-700"
          onClick={handleRotateLeft}
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
          className="rounded-full bg-gray-800 p-2 text-white hover:bg-gray-700"
          onClick={handleRotateRight}
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
          className="rounded-full bg-gray-800 p-2 text-white hover:bg-gray-700"
          onClick={handleZoomIn}
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
          className="rounded-full bg-gray-800 p-2 text-white hover:bg-gray-700"
          onClick={handleZoomOut}
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
          className="rounded-full bg-gray-800 p-2 text-white hover:bg-gray-700"
          onClick={handleReset}
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
          className="rounded-full bg-gray-800 p-2 text-white hover:bg-gray-700"
          onClick={handleClose}
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
        onClick={e => e.stopPropagation()}
        onWheel={e => {
          // Only handle scaling when Alt key is pressed (as per your current implementation)
          // or Ctrl key is pressed (as per your request)
          if (e.altKey || e.ctrlKey) {
            e.preventDefault()
            e.stopPropagation()

            // Determine scaling direction from wheel delta
            const delta = e.deltaY < 0 ? SCALE_STEP : -SCALE_STEP
            setScale(prevScale => Math.max(0.2, prevScale + delta))
          }
        }}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
      >
        <div
          style={{
            position: 'relative',
            left: `${position.x}px`,
            top: `${position.y}px`,
            cursor: isDragging ? 'grabbing' : 'grab',
          }}
          onMouseDown={handleMouseDown}
        >
          <img
            alt={alt}
            src={src}
            className="object-contain"
            style={{
              transform: `rotate(${rotation}deg) scale(${scale})`,
              transition: isDragging ? 'none' : 'transform 0.3s ease',
            }}
          />
        </div>
      </div>
    </div>
  )
}

ImageViewer.displayName = 'ImageViewer'
