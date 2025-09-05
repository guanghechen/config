import { useStateValue } from '@guanghechen/react-viewmodel'
import React, { useEffect, useRef } from 'react'
import { useDrawboardContext } from '../context'
import { RoughRenderer } from '../renderer/RoughRenderer'

export const StaticCanvas: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const { viewmodel } = useDrawboardContext()
  const elements = useStateValue(viewmodel.elements$)
  const viewData = useStateValue(viewmodel.viewData$)

  useEffect(() => {
    if (!canvasRef.current) return

    const canvas = canvasRef.current
    const ctx = canvas.getContext('2d')!
    const { width, height } = canvas.getBoundingClientRect()

    // Set canvas resolution
    canvas.width = width * window.devicePixelRatio
    canvas.height = height * window.devicePixelRatio
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio)

    // Clear canvas
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

  return <canvas ref={canvasRef} className="absolute inset-0" style={{ cursor: 'crosshair' }} />
}
