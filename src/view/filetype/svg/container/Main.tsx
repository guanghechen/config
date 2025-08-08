import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toSearch } from '@/util/url'
import { useSvgViewViewModel } from '../context'

export const Main: React.FC = () => {
  const viewmodel = useSvgViewViewModel()
  const workspace = useStateValue(viewmodel.workspace$)
  const filepath = useStateValue(viewmodel.filepath$)
  const scale = useStateValue(viewmodel.scale$)
  const rotation = useStateValue(viewmodel.rotation$)
  const position = useStateValue(viewmodel.position$)

  const [isDragging, setIsDragging] = React.useState<boolean>(false)
  const [startPosition, setStartPosition] = React.useState<{ x: number; y: number }>({ x: 0, y: 0 })
  const [svgContent, setSvgContent] = React.useState<string | null>(null)
  const [isLoading, setIsLoading] = React.useState<boolean>(true)
  const [error, setError] = React.useState<string | null>(null)
  const containerRef = React.useRef<HTMLDivElement>(null)

  const url = React.useMemo<string>(() => {
    const search = toSearch({ filepath, workspace })
    return `/api/file${search}`
  }, [filepath, workspace])

  React.useEffect(() => {
    if (!url) return

    setIsLoading(true)
    setError(null)

    fetch(url)
      .then(response => {
        if (!response.ok) {
          throw new Error(`Failed to load SVG: ${response.statusText}`)
        }
        return response.text()
      })
      .then(content => {
        setSvgContent(content)
        setIsLoading(false)
      })
      .catch(err => {
        setError(err.message)
        setIsLoading(false)
      })
  }, [url])

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
      {isLoading && (
        <div className="flex items-center justify-center">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-gray-300 border-t-blue-600" />
        </div>
      )}

      {error && (
        <div className="text-center text-red-500">
          <p>Error loading SVG:</p>
          <p>{error}</p>
        </div>
      )}

      {!isLoading && !error && svgContent && (
        <div
          className="svg-container max-h-full max-w-full"
          style={{
            transform: `translate(${position.x}px, ${position.y}px) scale(${scale}) rotate(${rotation}deg)`,
            transformOrigin: 'center center',
            transition: 'transform 100ms ease-in-out',
          }}
          dangerouslySetInnerHTML={{ __html: svgContent }}
        />
      )}
    </div>
  )
}

Main.displayName = 'SvgViewMain'
