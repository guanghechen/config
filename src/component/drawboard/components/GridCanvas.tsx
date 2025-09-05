import { useStateValue } from '@guanghechen/react-viewmodel'
import React, { useEffect, useRef } from 'react'
import { useDrawboardContext } from '../context'

export const GridCanvas: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const { viewmodel } = useDrawboardContext()
  const viewData = useStateValue(viewmodel.viewData$)

  useEffect(() => {
    if (!canvasRef.current || !viewData.showGrid) return

    const canvas = canvasRef.current
    const ctx = canvas.getContext('2d')!
    const { width, height } = canvas.getBoundingClientRect()

    canvas.width = width * window.devicePixelRatio
    canvas.height = height * window.devicePixelRatio
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio)

    drawGrid(
      ctx,
      viewData.gridSize,
      viewData.offsetX,
      viewData.offsetY,
      width,
      height,
      viewData.zoom,
    )
  }, [viewData.showGrid, viewData.gridSize, viewData.offsetX, viewData.offsetY, viewData.zoom])

  if (!viewData.showGrid) return null

  return (
    <canvas
      ref={canvasRef}
      className="absolute inset-0 pointer-events-none"
      style={{ opacity: 0.5 }}
    />
  )
}

function drawGrid(
  ctx: CanvasRenderingContext2D,
  gridSize: number,
  offsetX: number,
  offsetY: number,
  width: number,
  height: number,
  zoom: number,
): void {
  ctx.clearRect(0, 0, width, height)

  const scaledGridSize = gridSize * zoom

  // Only draw grid if it's not too small
  if (scaledGridSize < 5) return

  // Set canvas properties
  const context = ctx
  context.strokeStyle = '#e5e7eb' // gray-200
  context.lineWidth = 1

  // Draw vertical lines
  for (let x = offsetX % scaledGridSize; x < width; x += scaledGridSize) {
    ctx.beginPath()
    ctx.moveTo(x, 0)
    ctx.lineTo(x, height)
    ctx.stroke()
  }

  // Draw horizontal lines
  for (let y = offsetY % scaledGridSize; y < height; y += scaledGridSize) {
    ctx.beginPath()
    ctx.moveTo(0, y)
    ctx.lineTo(width, y)
    ctx.stroke()
  }

  // Draw stronger lines every 5 grid units
  const majorGridSize = scaledGridSize * 5

  if (majorGridSize >= 10) {
    context.strokeStyle = '#d1d5db' // gray-300
    context.lineWidth = 2

    for (let x = offsetX % majorGridSize; x < width; x += majorGridSize) {
      ctx.beginPath()
      ctx.moveTo(x, 0)
      ctx.lineTo(x, height)
      ctx.stroke()
    }

    for (let y = offsetY % majorGridSize; y < height; y += majorGridSize) {
      ctx.beginPath()
      ctx.moveTo(0, y)
      ctx.lineTo(width, y)
      ctx.stroke()
    }
  }
}
