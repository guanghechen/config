import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { SiteTheme, useSiteViewmodel } from '../../../context/site'
import { useDrawboardContext } from '../context'
import { gridCacheManager, useRafRender } from '../util/performance'

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

// Create theme-aware grid configuration
const createGridTheme = (siteTheme: SiteTheme): IGridTheme => {
  switch (siteTheme) {
    case SiteTheme.LIGHTEN:
      return {
        minorGridColor: '#d8d8d8',
        majorGridColor: '#d8d8d8',
        minorLineWidth: 0.5,
        majorLineWidth: 1,
        opacity: 1,
      }
    case SiteTheme.DARKEN:
      return {
        minorGridColor: '#555555',
        majorGridColor: '#555555',
        minorLineWidth: 0.5,
        majorLineWidth: 1,
        opacity: 1,
      }
    default:
      return {
        minorGridColor: '#d8d8d8',
        majorGridColor: '#d8d8d8',
        minorLineWidth: 0.5,
        majorLineWidth: 1,
        opacity: 1,
      }
  }
}

const GRID_CONFIG = {
  MIN_VISIBLE_SIZE: 2,
  MINOR_LINE_MIN_SIZE: 8,
  MAJOR_LINE_INTERVAL: 5,
  DASH_PATTERN: [3, 3],
  VIEWPORT_PADDING: 1.2, // Extend grid rendering beyond viewport for smooth panning
  MAX_GRID_LINES: 2000, // Limit maximum grid lines for performance
  CACHE_MISS_THRESHOLD: 0.5, // Re-cache when offset changes by this amount relative to grid size
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
  return React.useMemo(() => createGridTheme(siteTheme), [siteTheme])
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

// Ultra-optimized grid drawing with advanced viewport culling and caching
const drawOptimizedGridLines = (
  ctx: CanvasRenderingContext2D,
  params: IGridParams,
  dimensions: ICanvasDimensions,
  theme: IGridTheme,
): void => {
  const { gridSize, offsetX, offsetY, zoom } = params
  const { width, height } = dimensions
  const scaledGridSize = gridSize * zoom

  if (scaledGridSize < GRID_CONFIG.MIN_VISIBLE_SIZE) return

  // Calculate viewport bounds with padding for smooth panning
  const viewportPadding = scaledGridSize * GRID_CONFIG.VIEWPORT_PADDING
  const viewportLeft = -viewportPadding
  const viewportRight = width + viewportPadding
  const viewportTop = -viewportPadding
  const viewportBottom = height + viewportPadding

  // Compute normalized grid offset for stable caching
  const normalizedOffsetX = ((offsetX % scaledGridSize) + scaledGridSize) % scaledGridSize
  const normalizedOffsetY = ((offsetY % scaledGridSize) + scaledGridSize) % scaledGridSize

  // Generate stable cache key based on grid configuration
  const cacheKey = `grid_${width}x${height}_${scaledGridSize.toFixed(2)}_${theme.minorGridColor}_${theme.majorGridColor}`
  const offsetKey = `${Math.round(normalizedOffsetX * 10) / 10}_${Math.round(normalizedOffsetY * 10) / 10}`

  // Check if we can use cached grid pattern
  const cached = gridCacheManager.getFromCache(cacheKey)

  if (cached && cached.lastParams === offsetKey) {
    try {
      ctx.drawImage(cached.canvas, 0, 0)
      return
    } catch (error) {
      // Cache failed, fall through to direct rendering
      console.warn('Grid cache rendering failed:', error)
    }
  }

  // Clear previous content for fresh render
  const canvasCtx = ctx
  canvasCtx.clearRect(0, 0, width, height)

  const showMinorLines = scaledGridSize >= GRID_CONFIG.MINOR_LINE_MIN_SIZE

  canvasCtx.save()
  canvasCtx.globalAlpha = theme.opacity

  // Calculate grid line positions with viewport culling
  const calculateGridLines = (
    isVertical: boolean,
  ): { majorLines: number[]; minorLines: number[] } => {
    const offset = isVertical ? normalizedOffsetX : normalizedOffsetY
    const viewportStart = isVertical ? viewportLeft : viewportTop
    const viewportEnd = isVertical ? viewportRight : viewportBottom

    const majorLines: number[] = []
    const minorLines: number[] = []

    // Calculate start and end grid indices to minimize computation
    const startIndex = Math.floor((viewportStart - offset) / scaledGridSize) - 1
    const endIndex = Math.ceil((viewportEnd - offset) / scaledGridSize) + 1

    // Limit total number of lines for performance
    const totalLines = endIndex - startIndex
    if (totalLines > GRID_CONFIG.MAX_GRID_LINES) {
      console.warn(
        `Grid line count (${totalLines}) exceeds maximum (${GRID_CONFIG.MAX_GRID_LINES}), skipping grid render`,
      )
      return { majorLines: [], minorLines: [] }
    }

    for (let i = startIndex; i <= endIndex; i++) {
      const pos = i * scaledGridSize + offset

      // Only include lines within extended viewport
      if (pos >= viewportStart && pos <= viewportEnd) {
        const isMajor = i % GRID_CONFIG.MAJOR_LINE_INTERVAL === 0

        if (isMajor) {
          majorLines.push(Math.round(pos))
        } else if (showMinorLines) {
          minorLines.push(Math.round(pos))
        }
      }
    }

    return { majorLines, minorLines }
  }

  // Optimized batch rendering with single stroke calls per line type
  const renderLines = (
    lines: number[],
    isVertical: boolean,
    lineWidth: number,
    strokeStyle: string,
    lineDash: number[] = [],
  ): void => {
    if (lines.length === 0) return

    canvasCtx.lineWidth = lineWidth
    canvasCtx.strokeStyle = strokeStyle
    canvasCtx.setLineDash(lineDash)
    canvasCtx.beginPath()

    for (const pos of lines) {
      if (isVertical) {
        canvasCtx.moveTo(pos, Math.max(0, viewportTop))
        canvasCtx.lineTo(pos, Math.min(height, viewportBottom))
      } else {
        canvasCtx.moveTo(Math.max(0, viewportLeft), pos)
        canvasCtx.lineTo(Math.min(width, viewportRight), pos)
      }
    }

    canvasCtx.stroke()
  }

  // Render vertical lines
  const verticalLines = calculateGridLines(true)
  renderLines(verticalLines.majorLines, true, theme.majorLineWidth, theme.majorGridColor)
  renderLines(verticalLines.minorLines, true, theme.minorLineWidth, theme.minorGridColor, [
    ...GRID_CONFIG.DASH_PATTERN,
  ])

  // Render horizontal lines
  const horizontalLines = calculateGridLines(false)
  renderLines(horizontalLines.majorLines, false, theme.majorLineWidth, theme.majorGridColor)
  renderLines(horizontalLines.minorLines, false, theme.minorLineWidth, theme.minorGridColor, [
    ...GRID_CONFIG.DASH_PATTERN,
  ])

  canvasCtx.restore()

  // Cache the result for reasonable canvas sizes
  if (width * height < 4000000 && scaledGridSize >= GRID_CONFIG.MINOR_LINE_MIN_SIZE) {
    try {
      const offscreenCanvas = new OffscreenCanvas(width, height)
      const offscreenCtx = offscreenCanvas.getContext('2d')
      if (offscreenCtx) {
        offscreenCtx.drawImage(canvasCtx.canvas, 0, 0)
        gridCacheManager.setCache(cacheKey, offscreenCanvas, offsetKey)
      }
    } catch (error) {
      // Non-critical error, continue without caching
      console.warn('Grid caching failed:', error)
    }
  }
}

export const GridCanvas: React.FC = () => {
  const canvasRef = React.useRef<HTMLCanvasElement>(null)
  const { grid, ui } = useDrawboardContext()
  const gridVisible = useStateValue(grid.visible$)
  const gridSize = useStateValue(grid.size$)
  const interactionState = useStateValue(ui.interactionState$)
  const dimensions = useCanvasDimensions(canvasRef)
  const theme = useGridTheme()

  // Use RAF-based rendering for smooth updates with performance optimizations
  const renderGrid = React.useCallback(() => {
    const canvas = canvasRef.current
    if (!canvas || !dimensions) return

    const ctx = setupCanvas(canvas, dimensions)
    if (!ctx) return

    if (!gridVisible) {
      ctx.clearRect(0, 0, dimensions.width, dimensions.height)
      return
    }

    // Use transform coordinates during panning for ultra-smooth rendering
    const activeOffsetX = interactionState.isPanning
      ? interactionState.transformOffsetX
      : interactionState.offsetX
    const activeOffsetY = interactionState.isPanning
      ? interactionState.transformOffsetY
      : interactionState.offsetY
    const activeZoom = interactionState.isPanning
      ? interactionState.transformZoom
      : interactionState.zoom.value

    const gridParams: IGridParams = {
      gridSize: gridSize,
      offsetX: activeOffsetX,
      offsetY: activeOffsetY,
      zoom: activeZoom,
      showGrid: gridVisible,
    }

    // Use performance timing to monitor grid rendering performance
    const renderStart = performance.now()
    drawOptimizedGridLines(ctx, gridParams, dimensions, theme)
    const renderTime = performance.now() - renderStart

    // Log slow renders for debugging (only in development)
    if (renderTime > 16 && process.env.NODE_ENV === 'development') {
      console.warn(`Slow grid render: ${renderTime.toFixed(2)}ms (target: <16ms for 60fps)`)
    }
  }, [
    dimensions,
    gridVisible,
    gridSize,
    interactionState.offsetX,
    interactionState.offsetY,
    interactionState.zoom.value,
    interactionState.transformOffsetX,
    interactionState.transformOffsetY,
    interactionState.transformZoom,
    interactionState.isPanning,
    theme,
  ])

  // Use RAF rendering for smooth 60fps updates
  useRafRender('grid-canvas', renderGrid, [
    dimensions,
    gridVisible,
    gridSize,
    interactionState.offsetX,
    interactionState.offsetY,
    interactionState.zoom.value,
    interactionState.transformOffsetX,
    interactionState.transformOffsetY,
    interactionState.transformZoom,
    interactionState.isPanning,
    theme,
  ])

  return (
    <canvas
      ref={canvasRef}
      className="drawboard-canvas drawboard-canvas--grid drawboard-layer--grid"
    />
  )
}
