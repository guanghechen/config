import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { SiteTheme, useSiteViewmodel } from '../../../context/site'
import { useDrawboardContext } from '../context'

interface IGridTheme {
  readonly minorGridColor: string
  readonly majorGridColor: string
  readonly minorLineWidth: number
  readonly majorLineWidth: number
  readonly opacity: number
}

interface IGridParams {
  readonly gridSize: number
  readonly offsetX: number
  readonly offsetY: number
  readonly zoom: number
  readonly showGrid: boolean
}

interface ICanvasDimensions {
  readonly width: number
  readonly height: number
  readonly dpr: number
}

// Constants
const GRID_THEMES: Record<SiteTheme, IGridTheme> = {
  [SiteTheme.LIGHTEN]: {
    minorGridColor: '#c0c0c0',
    majorGridColor: '#a0a0a0',
    minorLineWidth: 0.5,
    majorLineWidth: 1,
    opacity: 1,
  },
  [SiteTheme.DARKEN]: {
    minorGridColor: '#404040',
    majorGridColor: '#606060',
    minorLineWidth: 0.5,
    majorLineWidth: 1,
    opacity: 1,
  },
} as const

const GRID_CONFIG = {
  MIN_VISIBLE_SIZE: 2,
  MINOR_LINE_MIN_SIZE: 8,
  MAJOR_LINE_INTERVAL: 5,
  DASH_PATTERN: [3, 3],
} as const

// Custom hooks
const useCanvasDimensions = (
  canvasRef: React.RefObject<HTMLCanvasElement | null>,
): ICanvasDimensions | null => {
  const [dimensions, setDimensions] = React.useState<ICanvasDimensions | null>(null)

  React.useEffect(() => {
    const canvas = canvasRef.current
    const container = canvas?.parentElement
    if (!canvas || !container) return

    const updateDimensions = (): void => {
      const { width, height } = container.getBoundingClientRect()
      const dpr = window.devicePixelRatio || 1

      if (width > 0 && height > 0) {
        setDimensions({ width, height, dpr })
      }
    }

    updateDimensions()

    const resizeObserver = new ResizeObserver(updateDimensions)
    resizeObserver.observe(container)

    return () => resizeObserver.disconnect()
  }, [canvasRef])

  return dimensions
}

const useGridTheme = (): IGridTheme => {
  const siteViewmodel = useSiteViewmodel()
  const siteTheme = useStateValue(siteViewmodel.theme$)
  return GRID_THEMES[siteTheme]
}

// Grid drawing utilities
const setupCanvas = (
  canvasDimensions: HTMLCanvasElement,
  dimensions: ICanvasDimensions,
): CanvasRenderingContext2D | null => {
  const { width, height, dpr } = dimensions

  try {
    const canvas = canvasDimensions
    canvas.width = width * dpr
    canvas.height = height * dpr
    canvas.style.width = `${width}px`
    canvas.style.height = `${height}px`

    const ctx = canvas.getContext('2d')
    if (!ctx) return null

    ctx.scale(dpr, dpr)
    return ctx
  } catch (error) {
    console.warn('Failed to setup canvas:', error)
    return null
  }
}

const drawGridLines = (
  ctx: CanvasRenderingContext2D,
  params: IGridParams,
  dimensions: ICanvasDimensions,
  theme: IGridTheme,
): void => {
  const { gridSize, offsetX, offsetY, zoom } = params
  const { width, height } = dimensions
  const scaledGridSize = gridSize * zoom

  if (scaledGridSize < GRID_CONFIG.MIN_VISIBLE_SIZE) return

  const gridOffsetX = (offsetX % scaledGridSize) - scaledGridSize
  const gridOffsetY = (offsetY % scaledGridSize) - scaledGridSize
  const showMinorLines = scaledGridSize >= GRID_CONFIG.MINOR_LINE_MIN_SIZE

  const canvasContext = ctx
  canvasContext.save()
  canvasContext.globalAlpha = theme.opacity

  // Draw lines function to reduce duplication
  const drawLines = (isVertical: boolean): void => {
    const dimension = isVertical ? width : height
    const offset = isVertical ? gridOffsetX : gridOffsetY

    for (let pos = offset; pos < dimension + scaledGridSize * 2; pos += scaledGridSize) {
      const gridIndex = Math.round((pos - offset) / scaledGridSize)
      const isMajor = gridIndex % GRID_CONFIG.MAJOR_LINE_INTERVAL === 0

      if (!isMajor && !showMinorLines) continue

      canvasContext.lineWidth = isMajor ? theme.majorLineWidth : theme.minorLineWidth
      canvasContext.strokeStyle = isMajor ? theme.majorGridColor : theme.minorGridColor
      canvasContext.setLineDash(isMajor ? [] : GRID_CONFIG.DASH_PATTERN)

      canvasContext.beginPath()
      if (isVertical) {
        canvasContext.moveTo(Math.round(pos), 0)
        canvasContext.lineTo(Math.round(pos), height)
      } else {
        canvasContext.moveTo(0, Math.round(pos))
        canvasContext.lineTo(width, Math.round(pos))
      }
      canvasContext.stroke()
    }
  }

  drawLines(true) // Vertical lines
  drawLines(false) // Horizontal lines

  canvasContext.restore()
}

export const GridCanvas: React.FC = () => {
  const canvasRef = React.useRef<HTMLCanvasElement>(null)
  const { viewmodel } = useDrawboardContext()
  const viewData = useStateValue(viewmodel.viewData$)
  const dimensions = useCanvasDimensions(canvasRef)
  const theme = useGridTheme()

  React.useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas || !dimensions) return

    const ctx = setupCanvas(canvas, dimensions)
    if (!ctx) return

    if (!viewData.showGrid) {
      ctx.clearRect(0, 0, dimensions.width, dimensions.height)
      return
    }

    const gridParams: IGridParams = {
      gridSize: viewData.gridSize,
      offsetX: viewData.offsetX,
      offsetY: viewData.offsetY,
      zoom: viewData.zoom,
      showGrid: viewData.showGrid,
    }

    drawGridLines(ctx, gridParams, dimensions, theme)
  }, [dimensions, viewData, theme])

  return <canvas ref={canvasRef} className="absolute inset-0 pointer-events-none z-0" />
}
