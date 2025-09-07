import { useEffect, useRef } from 'react'
import { v4 as uuidv4 } from 'uuid'
import { ToolMode } from '../context/types'
import type { HistoryViewModel } from '../context/viewmodel/history'
import type { LayersViewModel } from '../context/viewmodel/layers'
import type { UIViewModel } from '../context/viewmodel/ui'
import type { IDrawboardElement } from '../types/elements'
import { type IBatchedGesture, gestureBatchManager } from '../util/performance'

interface IDrawboardState {
  selectedTool: ToolMode
  strokeColor: string
  fillColor: string
  fillStyle: string
  strokeWidth: number
  strokeStyle: string
  roughness: number
  opacity: number
}

export function usePointerEvents(
  containerRef: React.RefObject<HTMLDivElement | null>,
  historyViewModel: HistoryViewModel,
  layersViewModel: LayersViewModel,
  uiViewModel: UIViewModel,
  appState: IDrawboardState,
): void {
  const isDrawingRef = useRef(false)
  const currentElementRef = useRef<IDrawboardElement | null>(null)
  const lastPointerRef = useRef({ x: 0, y: 0 })
  const lastScreenPointerRef = useRef({ x: 0, y: 0 })
  const gestureIdRef = useRef<string | null>(null)

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const getPointerPosition = (event: PointerEvent): { x: number; y: number } => {
      const rect = container.getBoundingClientRect()
      const interactionState = uiViewModel.interactionState$.getSnapshot()
      // Use logical coordinates for element positioning
      const activeOffsetX = interactionState.isPanning
        ? interactionState.offsetX
        : interactionState.offsetX
      const activeOffsetY = interactionState.isPanning
        ? interactionState.offsetY
        : interactionState.offsetY
      const activeZoom = interactionState.isPanning
        ? interactionState.zoom.value
        : interactionState.zoom.value

      return {
        x: (event.clientX - rect.left - activeOffsetX) / activeZoom,
        y: (event.clientY - rect.top - activeOffsetY) / activeZoom,
      }
    }

    const handlePointerDown = (event: PointerEvent): void => {
      event.preventDefault()
      isDrawingRef.current = true
      lastPointerRef.current = getPointerPosition(event)

      // Generate new gesture ID
      gestureIdRef.current = `gesture-${Date.now()}-${Math.random().toString(36).substring(2)}`

      // Store screen coordinates for panning
      const rect = container.getBoundingClientRect()
      lastScreenPointerRef.current = {
        x: event.clientX - rect.left,
        y: event.clientY - rect.top,
      }

      const tool = appState.selectedTool

      if (tool === ToolMode.PAN) {
        container.style.cursor = 'grabbing'
        uiViewModel.startPanning()
        return
      }

      // Create new element based on tool
      const baseElement = {
        id: uuidv4(),
        x: lastPointerRef.current.x,
        y: lastPointerRef.current.y,
        width: 0,
        height: 0,
        angle: 0,
        strokeColor: appState.strokeColor,
        backgroundColor: appState.fillColor,
        fillStyle: appState.fillStyle as any,
        strokeWidth: appState.strokeWidth,
        strokeStyle: appState.strokeStyle as any,
        roughness: appState.roughness,
        opacity: appState.opacity,
        seed: Math.floor(Math.random() * 2 ** 31),
        versionNonce: 0,
        isDeleted: false,
        updated: Date.now(),
      }

      switch (tool) {
        case ToolMode.RECTANGLE:
          currentElementRef.current = { ...baseElement, type: 'rectangle' }
          break
        case ToolMode.CIRCLE:
          currentElementRef.current = { ...baseElement, type: 'circle' }
          break
        case ToolMode.LINE:
          currentElementRef.current = {
            ...baseElement,
            type: 'line',
            points: [[0, 0]],
          }
          break
        case ToolMode.ARROW:
          currentElementRef.current = {
            ...baseElement,
            type: 'arrow',
            points: [[0, 0]],
            endArrowhead: 'arrow',
          }
          break
      }

      if (currentElementRef.current) {
        layersViewModel.addElementsToActiveLayer([currentElementRef.current])
        const layerData = layersViewModel.dump()
        historyViewModel.updateLayerData(layerData)
        historyViewModel.saveToHistory()
      }
    }

    // Batched gesture processing for smooth 60fps performance
    const processPanGesture = (batch: IBatchedGesture): void => {
      if (batch.events.length === 0) return

      const latestEvent = batch.events[batch.events.length - 1]
      const rect = container.getBoundingClientRect()
      const currentScreenX = latestEvent.clientX - rect.left
      const currentScreenY = latestEvent.clientY - rect.top

      const deltaX = currentScreenX - lastScreenPointerRef.current.x
      const deltaY = currentScreenY - lastScreenPointerRef.current.y

      uiViewModel.updateTransformDuringPan(deltaX, deltaY)
      lastScreenPointerRef.current = { x: currentScreenX, y: currentScreenY }
    }

    const processDrawGesture = (batch: IBatchedGesture): void => {
      if (batch.events.length === 0 || !currentElementRef.current) return

      const latestEvent = batch.events[batch.events.length - 1]
      const current = getPointerPosition(latestEvent)
      const element = currentElementRef.current
      const deltaX = current.x - element.x
      const deltaY = current.y - element.y

      const activeLayer = layersViewModel.getActiveLayer()
      if (!activeLayer) return

      const updatedElements = activeLayer.elements.map(el => {
        if (el.id === element.id) {
          switch (element.type) {
            case 'rectangle':
            case 'circle':
              return { ...el, width: deltaX, height: deltaY, updated: Date.now() }
            case 'line':
            case 'arrow': {
              const lineElement = element as any
              const newPoints =
                lineElement.points.length === 1
                  ? [
                      [0, 0],
                      [deltaX, deltaY],
                    ]
                  : [...lineElement.points.slice(0, -1), [deltaX, deltaY]]
              return { ...el, points: newPoints, updated: Date.now() }
            }
            default:
              return el
          }
        }
        return el
      })

      layersViewModel.setActiveLayerElements(updatedElements)
      const layerData = layersViewModel.dump()
      historyViewModel.updateLayerData(layerData)
    }

    const handlePointerMove = (event: PointerEvent): void => {
      if (!isDrawingRef.current) return

      // Create gesture ID if not exists
      if (!gestureIdRef.current) {
        gestureIdRef.current = `gesture-${Date.now()}-${Math.random().toString(36).substring(2)}`
      }

      if (appState.selectedTool === ToolMode.PAN) {
        gestureBatchManager.addGestureEvent(gestureIdRef.current, 'pan', event, processPanGesture)
      } else {
        gestureBatchManager.addGestureEvent(gestureIdRef.current, 'draw', event, processDrawGesture)
      }
    }

    const handlePointerUp = (): void => {
      const interactionState = uiViewModel.interactionState$.getSnapshot()

      if (isDrawingRef.current && currentElementRef.current) {
        historyViewModel.saveToHistory()
      }

      // Finish panning and commit transform to logical coordinates
      if (interactionState.isPanning) {
        uiViewModel.finishPanning()
      }

      // Clean up gesture batching
      if (gestureIdRef.current) {
        gestureBatchManager.cancelGesture(gestureIdRef.current)
        gestureIdRef.current = null
      }

      isDrawingRef.current = false
      currentElementRef.current = null
      container.style.cursor = 'default'
    }

    const handleWheel = (event: WheelEvent): void => {
      if (event.ctrlKey || event.metaKey) {
        event.preventDefault()
        const interactionState = uiViewModel.interactionState$.getSnapshot()
        const zoomFactor = event.deltaY > 0 ? 0.9 : 1.1
        const newZoom = Math.max(0.1, Math.min(30, interactionState.zoom.value * zoomFactor))

        // Get mouse position relative to container for zoom center
        const rect = container.getBoundingClientRect()
        const centerX = event.clientX - rect.left
        const centerY = event.clientY - rect.top

        // Use smooth animated zoom for better UX
        uiViewModel.setZoom(newZoom, true, centerX, centerY)
      }
    }

    container.addEventListener('pointerdown', handlePointerDown)
    container.addEventListener('pointermove', handlePointerMove)
    container.addEventListener('pointerup', handlePointerUp)
    container.addEventListener('pointerleave', handlePointerUp)
    container.addEventListener('wheel', handleWheel, { passive: false })

    return () => {
      container.removeEventListener('pointerdown', handlePointerDown)
      container.removeEventListener('pointermove', handlePointerMove)
      container.removeEventListener('pointerup', handlePointerUp)
      container.removeEventListener('pointerleave', handlePointerUp)
      container.removeEventListener('wheel', handleWheel)
      // Cancel any pending gesture operations
      if (gestureIdRef.current) {
        gestureBatchManager.cancelGesture(gestureIdRef.current)
      }
    }
  }, [containerRef, historyViewModel, layersViewModel, uiViewModel, appState])
}
