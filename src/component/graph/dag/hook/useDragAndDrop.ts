import { useEventCallback } from '@guanghechen/react-hooks'
import React from 'react'
import type { IDragDropState, IGraphNode } from '../types'

interface IProps {
  readonly nodes: IGraphNode[]
  readonly onNodeReplace?: (sourceNode: IGraphNode, targetNode: IGraphNode) => void
  readonly onNodePositionChange?: (nodeId: string, newPosition: { x: number; y: number }) => void
  readonly hitTestNode: (
    worldX: number,
    worldY: number,
  ) => { node: IGraphNode | null; isHit: boolean }
  readonly screenToWorld: (x: number, y: number) => { x: number; y: number }
  readonly worldToScreen: (x: number, y: number) => { x: number; y: number }
}

interface IResult {
  readonly dragDropState: IDragDropState
  readonly handleDragStart: (node: IGraphNode, screenX: number, screenY: number) => void
  readonly handleDragMove: (screenX: number, screenY: number) => void
  readonly handleDragEnd: (screenX: number, screenY: number) => void
  readonly resetDragState: () => void
}

export const useDragAndDrop = (props: IProps): IResult => {
  const { hitTestNode, screenToWorld, worldToScreen, onNodeReplace, onNodePositionChange } = props
  const [dragDropState, setDragDropState] = React.useState<IDragDropState>({
    isDragging: false,
    draggedNode: null,
    dropTargetNode: null,
    dragStartPosition: null,
    currentPosition: null,
    dragMode: null,
    dragOffset: null,
  })

  const REPLACEMENT_THRESHOLD = 30 // Distance in screen pixels to trigger replacement mode

  const handleDragStart = useEventCallback(
    (node: IGraphNode, screenX: number, screenY: number) => {
      if (!node.position) return

      // Calculate offset from mouse to node center for accurate positioning
      const screenNodePos = worldToScreen(node.position.x, node.position.y)
      const dragOffset = {
        x: screenNodePos.x - screenX,
        y: screenNodePos.y - screenY,
      }

      setDragDropState({
        isDragging: true,
        draggedNode: node,
        dropTargetNode: null,
        dragStartPosition: { x: screenX, y: screenY },
        currentPosition: { x: screenX, y: screenY },
        dragMode: 'positioning', // Start with positioning mode
        dragOffset,
      })
    }
  )

  const handleDragMove = useEventCallback(
    (screenX: number, screenY: number) => {
      if (!dragDropState.isDragging || !dragDropState.draggedNode) return

      const worldPos = screenToWorld(screenX, screenY)
      const hitResult = hitTestNode(worldPos.x, worldPos.y)

      // Check if we're hovering over another node (excluding self)
      const potentialTarget =
        hitResult.node && hitResult.node.id !== dragDropState.draggedNode.id ? hitResult.node : null

      // Determine drag mode based on proximity to other nodes
      let newDragMode: 'positioning' | 'replacement' = 'positioning'
      let dropTargetNode: IGraphNode | null = null

      if (potentialTarget && potentialTarget.position) {
        // Calculate distance to target node center
        const targetScreenPos = worldToScreen(
          potentialTarget.position.x,
          potentialTarget.position.y,
        )
        const distance = Math.sqrt(
          Math.pow(screenX - targetScreenPos.x, 2) + Math.pow(screenY - targetScreenPos.y, 2),
        )

        if (distance <= REPLACEMENT_THRESHOLD) {
          newDragMode = 'replacement'
          dropTargetNode = potentialTarget
        }
      }

      setDragDropState(prev => ({
        ...prev,
        currentPosition: { x: screenX, y: screenY },
        dropTargetNode,
        dragMode: newDragMode,
      }))
    }
  )

  const handleDragEnd = useEventCallback(
    (screenX: number, screenY: number) => {
      if (!dragDropState.isDragging || !dragDropState.draggedNode) {
        setDragDropState({
          isDragging: false,
          draggedNode: null,
          dropTargetNode: null,
          dragStartPosition: null,
          currentPosition: null,
          dragMode: null,
          dragOffset: null,
        })
        return
      }

      if (dragDropState.dragMode === 'replacement' && dragDropState.dropTargetNode) {
        // Handle node replacement
        onNodeReplace?.(dragDropState.draggedNode, dragDropState.dropTargetNode)
      } else if (dragDropState.dragMode === 'positioning' && dragDropState.dragOffset) {
        // Handle node repositioning
        const newWorldPos = screenToWorld(
          screenX + dragDropState.dragOffset.x,
          screenY + dragDropState.dragOffset.y,
        )
        onNodePositionChange?.(dragDropState.draggedNode.id, newWorldPos)
      }

      setDragDropState({
        isDragging: false,
        draggedNode: null,
        dropTargetNode: null,
        dragStartPosition: null,
        currentPosition: null,
        dragMode: null,
        dragOffset: null,
      })
    }
  )

  const resetDragState = useEventCallback(() => {
    setDragDropState({
      isDragging: false,
      draggedNode: null,
      dropTargetNode: null,
      dragStartPosition: null,
      currentPosition: null,
      dragMode: null,
      dragOffset: null,
    })
  })

  return {
    dragDropState,
    handleDragStart,
    handleDragMove,
    handleDragEnd,
    resetDragState,
  }
}
