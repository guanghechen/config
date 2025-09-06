import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../context'
import { RoughRenderer } from '../renderer/RoughRenderer'

export const StaticCanvas: React.FC = () => {
  const canvasRef = React.useRef<HTMLCanvasElement>(null)
  const { viewmodel } = useDrawboardContext()
  const elements = useStateValue(viewmodel.elements$)
  const viewData = useStateValue(viewmodel.viewData$)

  React.useEffect(() => {
    if (!canvasRef.current) return

    const canvas = canvasRef.current
    const container = canvas.parentElement
    if (!container) return

    const { width, height } = container.getBoundingClientRect()

    // Ensure we have valid dimensions
    if (width === 0 || height === 0) return

    // Set canvas resolution
    canvas.width = width * window.devicePixelRatio
    canvas.height = height * window.devicePixelRatio
    canvas.style.width = `${width}px`
    canvas.style.height = `${height}px`

    const ctx = canvas.getContext('2d')!
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio)

    // Clear canvas with transparent background
    ctx.clearRect(0, 0, width, height)

    // Apply transformations
    ctx.save()
    ctx.translate(viewData.offsetX, viewData.offsetY)
    ctx.scale(viewData.zoom, viewData.zoom)

    // Render elements
    const renderer = new RoughRenderer(canvas)
    elements.forEach(element => {
      if (!element.isDeleted) {
        try {
          renderer.renderElement(element)
        } catch (error) {
          console.warn('Failed to render element:', element.id, error)
        }
      }
    })

    ctx.restore()
  }, [elements, viewData.offsetX, viewData.offsetY, viewData.zoom])

  // Window resize handler - trigger re-render by updating viewData
  React.useEffect(() => {
    const handleResize = (): void => {
      // Trigger re-render by updating a dependency
      viewmodel.viewData$.next({ ...viewmodel.viewData$.getSnapshot() })
    }

    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [viewmodel])

  return (
    <canvas
      ref={canvasRef}
      className="absolute inset-0 z-10 bg-transparent"
      style={{ cursor: 'crosshair' }}
    />
  )
}
