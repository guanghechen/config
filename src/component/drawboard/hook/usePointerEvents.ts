import { useEffect, useRef } from 'react'
import { v4 as uuidv4 } from 'uuid'
import { ToolMode } from '../context/types'
import type { DrawboardViewModel } from '../context/viewmodel'
import type { DrawboardElement } from '../types/elements'

export function usePointerEvents(
  containerRef: React.RefObject<HTMLDivElement | null>,
  viewmodel: DrawboardViewModel,
): void {
  const isDrawingRef = useRef(false)
  const currentElementRef = useRef<DrawboardElement | null>(null)
  const lastPointerRef = useRef({ x: 0, y: 0 })

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const getPointerPosition = (event: PointerEvent): { x: number; y: number } => {
      const rect = container.getBoundingClientRect()
      const viewData = viewmodel.viewData$.getSnapshot()
      return {
        x: (event.clientX - rect.left - viewData.offsetX) / viewData.zoom,
        y: (event.clientY - rect.top - viewData.offsetY) / viewData.zoom,
      }
    }

    const handlePointerDown = (event: PointerEvent): void => {
      event.preventDefault()
      isDrawingRef.current = true
      lastPointerRef.current = getPointerPosition(event)

      const appState = viewmodel.appState$.getSnapshot()
      const tool = appState.selectedTool

      if (tool === ToolMode.PAN) {
        container.style.cursor = 'grabbing'
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
        strokeColor: appState.currentItemStrokeColor,
        backgroundColor: appState.currentItemBackgroundColor,
        fillStyle: appState.currentItemFillStyle as any,
        strokeWidth: appState.currentItemStrokeWidth,
        strokeStyle: appState.currentItemStrokeStyle as any,
        roughness: appState.currentItemRoughness,
        opacity: appState.currentItemOpacity,
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
        viewmodel.addElement(currentElementRef.current)
      }
    }

    const handlePointerMove = (event: PointerEvent): void => {
      const current = getPointerPosition(event)
      const appState = viewmodel.appState$.getSnapshot()

      if (!isDrawingRef.current) return

      if (appState.selectedTool === ToolMode.PAN) {
        const deltaX =
          (current.x - lastPointerRef.current.x) * viewmodel.viewData$.getSnapshot().zoom
        const deltaY =
          (current.y - lastPointerRef.current.y) * viewmodel.viewData$.getSnapshot().zoom
        viewmodel.pan(deltaX, deltaY)
        lastPointerRef.current = current
        return
      }

      if (!currentElementRef.current) return

      const element = currentElementRef.current
      const deltaX = current.x - element.x
      const deltaY = current.y - element.y

      switch (element.type) {
        case 'rectangle':
        case 'circle':
          viewmodel.updateElement(element.id, {
            width: deltaX,
            height: deltaY,
          })
          break
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
          viewmodel.updateElement(element.id, {
            points: newPoints,
          })
          break
        }
      }
    }

    const handlePointerUp = (): void => {
      isDrawingRef.current = false
      currentElementRef.current = null
      container.style.cursor = 'default'
    }

    const handleWheel = (event: WheelEvent): void => {
      if (event.ctrlKey || event.metaKey) {
        event.preventDefault()
        const viewData = viewmodel.viewData$.getSnapshot()
        const zoomFactor = event.deltaY > 0 ? 0.9 : 1.1
        const newZoom = Math.max(0.1, Math.min(5, viewData.zoom * zoomFactor))
        viewmodel.setZoom(newZoom)
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
    }
  }, [containerRef, viewmodel])
}
