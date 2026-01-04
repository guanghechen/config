import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useDrawboardContext } from '../context'
import { RoughRenderer } from '../renderer/RoughRenderer'
import type { IDrawboardElement } from '../types/elements'
import { performanceManager } from '../util/performance'

interface ILayerCanvasProps {
  layerName: string
  zIndex: number
  blendMode?: string
  opacity?: number
}

const LayerCanvasComponent: React.FC<ILayerCanvasProps> = ({
  layerName,
  zIndex,
  blendMode = 'normal',
  opacity = 1,
}) => {
  const canvasRef = React.useRef<HTMLCanvasElement>(null)
  const { layers, ui } = useDrawboardContext()
  const allLayers = useStateValue(layers.layers$)
  const interactionState = useStateValue(ui.interactionState$)

  // Find the specific layer and get its elements
  const layerElements = React.useMemo(() => {
    const layer = allLayers.find(l => l.id === layerName)
    return layer?.elements || []
  }, [allLayers, layerName])

  // Viewport culling - only render elements that are visible
  const visibleElements = React.useMemo(() => {
    const viewportPadding = 100 // Extra padding to account for partially visible elements
    const container = canvasRef.current?.parentElement
    if (!container) return layerElements

    const { width, height } = container.getBoundingClientRect()
    const activeOffsetX = interactionState.isPanning
      ? interactionState.transformOffsetX
      : interactionState.offsetX
    const activeOffsetY = interactionState.isPanning
      ? interactionState.transformOffsetY
      : interactionState.offsetY
    const activeZoom = interactionState.isPanning
      ? interactionState.transformZoom
      : interactionState.zoom.value

    // Calculate viewport bounds in world coordinates
    const viewportLeft = (-activeOffsetX - viewportPadding) / activeZoom
    const viewportTop = (-activeOffsetY - viewportPadding) / activeZoom
    const viewportRight = (width - activeOffsetX + viewportPadding) / activeZoom
    const viewportBottom = (height - activeOffsetY + viewportPadding) / activeZoom

    return layerElements.filter((element: IDrawboardElement) => {
      const { x, y, width: elementWidth = 100, height: elementHeight = 100 } = element

      // Simple AABB intersection test
      return !(
        x + elementWidth < viewportLeft ||
        x > viewportRight ||
        y + elementHeight < viewportTop ||
        y > viewportBottom
      )
    })
  }, [layerElements, interactionState])

  // Determine if this is a complex layer (many elements or complex shapes)
  const isComplexLayer = React.useMemo(() => {
    return (
      visibleElements.length > 50 ||
      visibleElements.some(el => el.type === 'line' && (el as any).points?.length > 100)
    )
  }, [visibleElements])

  // Setup canvas dimensions and context
  const setupCanvasForRender = React.useCallback(() => {
    const canvas = canvasRef.current
    if (!canvas) return null

    const container = canvas.parentElement
    if (!container) return null

    const { width, height } = container.getBoundingClientRect()
    if (width === 0 || height === 0) return null

    const dpr = window.devicePixelRatio || 1
    canvas.width = width * dpr
    canvas.height = height * dpr
    canvas.style.width = `${width}px`
    canvas.style.height = `${height}px`

    const ctx = canvas.getContext('2d')
    if (!ctx) return null

    ctx.scale(dpr, dpr)
    return { ctx, width, height }
  }, [])

  // Render function with optimized coordinate handling
  const renderLayer = React.useCallback(() => {
    const setup = setupCanvasForRender()
    if (!setup) return

    const { ctx, width, height } = setup

    // Clear canvas
    ctx.clearRect(0, 0, width, height)
    ctx.globalAlpha = opacity
    ctx.save()

    // Apply CSS transforms to individual canvas for hardware acceleration
    const canvas = canvasRef.current!
    const activeOffsetX = interactionState.isPanning
      ? interactionState.transformOffsetX
      : interactionState.offsetX
    const activeOffsetY = interactionState.isPanning
      ? interactionState.transformOffsetY
      : interactionState.offsetY
    const activeZoom = interactionState.isPanning
      ? interactionState.transformZoom
      : interactionState.zoom.value

    // Apply transform to canvas element for hardware acceleration
    canvas.style.transform = `translate(${activeOffsetX}px, ${activeOffsetY}px) scale(${activeZoom})`
    canvas.style.transformOrigin = '0 0'
    canvas.style.willChange = 'transform'

    // Render elements without transform (since canvas is already transformed)
    const renderer = new RoughRenderer(canvas)
    visibleElements.forEach((element: IDrawboardElement) => {
      try {
        renderer.renderElement(element)
      } catch (error) {
        console.warn('Failed to render element on layer:', layerName, element.id, error)
      }
    })

    ctx.restore()
  }, [
    visibleElements,
    interactionState.offsetX,
    interactionState.offsetY,
    interactionState.zoom.value,
    interactionState.transformOffsetX,
    interactionState.transformOffsetY,
    interactionState.transformZoom,
    interactionState.isPanning,
    opacity,
    layerName,
    setupCanvasForRender,
  ])

  // Use appropriate rendering strategy based on layer complexity and interaction state
  React.useEffect(() => {
    if (interactionState.isPanning || isComplexLayer) {
      // Use debounced rendering during panning or for complex layers to maintain 60fps
      const timeoutId = setTimeout(
        () => {
          renderLayer()
        },
        interactionState.isPanning ? 8 : 32,
      ) // Faster updates during panning
      return () => clearTimeout(timeoutId)
    } else {
      // Use RAF rendering for simple layers during normal interactions
      performanceManager.scheduleRender(`layer-${layerName}`, renderLayer, 5) // Medium priority
      return () => performanceManager.cancelRender(`layer-${layerName}`)
    }
  }, [
    renderLayer,
    isComplexLayer,
    visibleElements,
    interactionState.offsetX,
    interactionState.offsetY,
    interactionState.zoom.value,
    interactionState.transformOffsetX,
    interactionState.transformOffsetY,
    interactionState.transformZoom,
    interactionState.isPanning,
    opacity,
    layerName,
  ])

  return (
    <canvas
      ref={canvasRef}
      className="drawboard-canvas drawboard-canvas--layer"
      style={{
        cursor: 'crosshair',
        zIndex,
        mixBlendMode: blendMode as any,
        opacity,
      }}
    />
  )
}

// Smart equality check for React.memo optimization
const arePropsEqual = (prevProps: ILayerCanvasProps, nextProps: ILayerCanvasProps): boolean => {
  // Quick reference equality checks first
  return (
    prevProps.layerName === nextProps.layerName &&
    prevProps.zIndex === nextProps.zIndex &&
    prevProps.blendMode === nextProps.blendMode &&
    prevProps.opacity === nextProps.opacity
  )
}

// Memoized component with smart equality checks
export const LayerCanvas = React.memo(LayerCanvasComponent, arePropsEqual)
