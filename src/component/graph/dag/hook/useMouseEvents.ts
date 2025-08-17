import { useEventCallback } from '@guanghechen/react-hooks'
import React from 'react'
import type { IGraphNode } from '../types'

interface IMouseEventHandlers {
  onNodeClick?: (node: IGraphNode) => void
  onNodeHover?: (node: IGraphNode | null) => void
  onNodeDragStart?: (node: IGraphNode, screenX: number, screenY: number) => void
}

interface IHitTestResult {
  node: IGraphNode | null
  isHit: boolean
}

interface IMouseEventsReturn {
  hoveredNode: IGraphNode | null
  handleCanvasMouseMove: (event: MouseEvent, canvasRect: DOMRect) => void
  handleCanvasClick: (
    event: MouseEvent,
    canvasRect: DOMRect,
    dragStart: { x: number; y: number } | null,
  ) => void
  handleCanvasMouseDown: (
    event: MouseEvent,
    canvasRect: DOMRect,
    dragStart: { x: number; y: number },
  ) => void
  handleKeyDown: (event: KeyboardEvent) => void
  hitTestNode: (worldX: number, worldY: number) => IHitTestResult
}

export const useMouseEvents = (
  nodes: IGraphNode[],
  handlers: IMouseEventHandlers,
  screenToWorld: (x: number, y: number) => { x: number; y: number },
): IMouseEventsReturn => {
  const hoveredNode = React.useRef<IGraphNode | null>(null)
  const clickThreshold = 5
  const dragThreshold = 10

  const hitTestNode = React.useCallback(
    (worldX: number, worldY: number): IHitTestResult => {
      for (const node of nodes) {
        if (!node.position) continue

        const nodeSize = node.size || { width: 120, height: 60 }
        const bounds = {
          x: node.position.x - nodeSize.width / 2,
          y: node.position.y - nodeSize.height / 2,
          width: nodeSize.width,
          height: nodeSize.height,
        }

        if (
          worldX >= bounds.x &&
          worldX <= bounds.x + bounds.width &&
          worldY >= bounds.y &&
          worldY <= bounds.y + bounds.height
        ) {
          return { node, isHit: true }
        }
      }

      return { node: null, isHit: false }
    },
    [nodes],
  )

  const handleCanvasMouseMove = useEventCallback(
    (event: MouseEvent, canvasRect: DOMRect) => {
      const mouseX = event.clientX - canvasRect.left
      const mouseY = event.clientY - canvasRect.top
      const worldPos = screenToWorld(mouseX, mouseY)

      const hitResult = hitTestNode(worldPos.x, worldPos.y)

      if (hitResult.node !== hoveredNode.current) {
        hoveredNode.current = hitResult.node
        handlers.onNodeHover?.(hitResult.node)
      }
    }
  )

  const handleCanvasClick = useEventCallback(
    (event: MouseEvent, canvasRect: DOMRect, dragStart: { x: number; y: number } | null) => {
      if (!dragStart) return

      const mouseX = event.clientX - canvasRect.left
      const mouseY = event.clientY - canvasRect.top

      const dragDistance = Math.sqrt(
        Math.pow(mouseX - dragStart.x, 2) + Math.pow(mouseY - dragStart.y, 2),
      )

      if (dragDistance < clickThreshold) {
        const worldPos = screenToWorld(mouseX, mouseY)
        const hitResult = hitTestNode(worldPos.x, worldPos.y)

        if (hitResult.node) {
          handlers.onNodeClick?.(hitResult.node)
        }
      }
    }
  )

  const handleCanvasMouseDown = useEventCallback(
    (event: MouseEvent, canvasRect: DOMRect, dragStart: { x: number; y: number }) => {
      const mouseX = event.clientX - canvasRect.left
      const mouseY = event.clientY - canvasRect.top
      const worldPos = screenToWorld(mouseX, mouseY)
      const hitResult = hitTestNode(worldPos.x, worldPos.y)

      if (hitResult.node) {
        setTimeout(() => {
          const currentDragDistance = Math.sqrt(
            Math.pow(mouseX - dragStart.x, 2) + Math.pow(mouseY - dragStart.y, 2),
          )

          if (currentDragDistance >= dragThreshold) {
            handlers.onNodeDragStart?.(hitResult.node!, mouseX, mouseY)
          }
        }, 150)
      }
    }
  )

  const handleKeyDown = useEventCallback(
    (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        hoveredNode.current = null
        handlers.onNodeHover?.(null)
      }
    }
  )

  return {
    hoveredNode: hoveredNode.current,
    handleCanvasMouseMove,
    handleCanvasClick,
    handleCanvasMouseDown,
    handleKeyDown,
    hitTestNode,
  }
}
