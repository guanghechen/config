import { useEventCallback } from '@guanghechen/react-hooks'
import React, { type RefObject } from 'react'
import type { IGraphNode, ITransform } from '../types'

interface IState {
  isDragging: boolean
  dragStart: { x: number; y: number } | null
  draggedNode: IGraphNode | null
  isPanning: boolean
  isNodeDragging: boolean
}

export const useCanvasInteraction = (
  canvasRef: RefObject<HTMLCanvasElement | null>,
): {
  transform: ITransform
  interactionState: IState
  screenToWorld: (x: number, y: number) => { x: number; y: number }
  worldToScreen: (x: number, y: number) => { x: number; y: number }
  handleWheel: (event: WheelEvent) => void
  handleMouseDown: (event: MouseEvent) => void
  handleMouseMove: (event: MouseEvent) => void
  handleMouseUp: () => void
  resetTransform: () => void
  zoomIn: () => void
  zoomOut: () => void
  fitToView: (nodes: IGraphNode[]) => void
  setTransform: (transform: ITransform) => void
  setNodeDragging: (isNodeDragging: boolean) => void
} => {
  const [transform, setTransform] = React.useState<ITransform>({ x: 0, y: 0, scale: 1 })
  const [interactionState, setInteractionState] = React.useState<IState>({
    isDragging: false,
    dragStart: null,
    draggedNode: null,
    isPanning: false,
    isNodeDragging: false,
  })

  const lastMousePos = React.useRef<{ x: number; y: number } | null>(null)

  const screenToWorld = React.useCallback(
    (screenX: number, screenY: number) => {
      return {
        x: (screenX - transform.x) / transform.scale,
        y: (screenY - transform.y) / transform.scale,
      }
    },
    [transform],
  )

  const worldToScreen = React.useCallback(
    (worldX: number, worldY: number) => {
      return {
        x: worldX * transform.scale + transform.x,
        y: worldY * transform.scale + transform.y,
      }
    },
    [transform],
  )

  const handleWheel = useEventCallback((event: WheelEvent) => {
    event.preventDefault()
    const canvas = canvasRef.current
    if (!canvas) return

    const rect = canvas.getBoundingClientRect()
    const mouseX = event.clientX - rect.left
    const mouseY = event.clientY - rect.top

    const scaleFactor = event.deltaY > 0 ? 0.9 : 1.1
    const newScale = Math.max(0.1, Math.min(5, transform.scale * scaleFactor))

    const newX = mouseX - (mouseX - transform.x) * (newScale / transform.scale)
    const newY = mouseY - (mouseY - transform.y) * (newScale / transform.scale)

    setTransform({ x: newX, y: newY, scale: newScale })
  })

  const handleMouseDown = useEventCallback((event: MouseEvent) => {
    const canvas = canvasRef.current
    if (!canvas) return

    const rect = canvas.getBoundingClientRect()
    const mouseX = event.clientX - rect.left
    const mouseY = event.clientY - rect.top

    lastMousePos.current = { x: mouseX, y: mouseY }

    setInteractionState(prev => ({
      ...prev,
      isDragging: true,
      dragStart: { x: mouseX, y: mouseY },
      isPanning: !prev.isNodeDragging, // Only enable panning if not dragging a node
    }))
  })

  const handleMouseMove = useEventCallback((event: MouseEvent) => {
    const canvas = canvasRef.current
    if (!canvas || !lastMousePos.current) return

    const rect = canvas.getBoundingClientRect()
    const mouseX = event.clientX - rect.left
    const mouseY = event.clientY - rect.top

    if (interactionState.isDragging && interactionState.isPanning) {
      const deltaX = mouseX - lastMousePos.current.x
      const deltaY = mouseY - lastMousePos.current.y

      setTransform(prev => ({
        ...prev,
        x: prev.x + deltaX,
        y: prev.y + deltaY,
      }))
    }

    lastMousePos.current = { x: mouseX, y: mouseY }
  })

  const handleMouseUp = useEventCallback(() => {
    setInteractionState({
      isDragging: false,
      dragStart: null,
      draggedNode: null,
      isPanning: false,
      isNodeDragging: false,
    })
    lastMousePos.current = null
  })

  const resetTransform = useEventCallback(() => {
    setTransform({ x: 0, y: 0, scale: 1 })
  })

  const zoomIn = useEventCallback(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const centerX = canvas.width / 2
    const centerY = canvas.height / 2
    const scaleFactor = 1.2
    const newScale = Math.min(5, transform.scale * scaleFactor)

    const newX = centerX - (centerX - transform.x) * (newScale / transform.scale)
    const newY = centerY - (centerY - transform.y) * (newScale / transform.scale)

    setTransform({ x: newX, y: newY, scale: newScale })
  })

  const zoomOut = useEventCallback(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const centerX = canvas.width / 2
    const centerY = canvas.height / 2
    const scaleFactor = 0.8
    const newScale = Math.max(0.1, transform.scale * scaleFactor)

    const newX = centerX - (centerX - transform.x) * (newScale / transform.scale)
    const newY = centerY - (centerY - transform.y) * (newScale / transform.scale)

    setTransform({ x: newX, y: newY, scale: newScale })
  })

  const fitToView = useEventCallback((nodes: IGraphNode[]) => {
    const canvas = canvasRef.current
    if (!canvas || nodes.length === 0) return

    const positions = nodes.filter(node => node.position).map(node => node.position!)

    if (positions.length === 0) return

    const minX = Math.min(...positions.map(p => p.x)) - 60
    const maxX = Math.max(...positions.map(p => p.x)) + 60
    const minY = Math.min(...positions.map(p => p.y)) - 40
    const maxY = Math.max(...positions.map(p => p.y)) + 40

    const graphWidth = maxX - minX
    const graphHeight = maxY - minY

    const scaleX = canvas.width / graphWidth
    const scaleY = canvas.height / graphHeight
    const scale = Math.min(scaleX, scaleY, 2) * 0.9

    const centerX = (minX + maxX) / 2
    const centerY = (minY + maxY) / 2

    const x = canvas.width / 2 - centerX * scale
    const y = canvas.height / 2 - centerY * scale

    setTransform({ x, y, scale })
  })

  const setNodeDragging = useEventCallback((isNodeDragging: boolean) => {
    setInteractionState(prev => ({
      ...prev,
      isNodeDragging,
    }))
  })

  return {
    transform,
    interactionState,
    screenToWorld,
    worldToScreen,
    handleWheel,
    handleMouseDown,
    handleMouseMove,
    handleMouseUp,
    resetTransform,
    zoomIn,
    zoomOut,
    fitToView,
    setTransform,
    setNodeDragging,
  }
}
