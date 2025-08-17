import { useEventCallback } from '@guanghechen/react-hooks'
import cn from 'clsx'
import React from 'react'
import { Json } from '@/component/json'
import { GraphToolbar } from './component/GraphToolbar'
import { NodeTooltip } from './component/NodeTooltip'
import { useCanvasInteraction } from './hook/useCanvasInteraction'
import { useDragAndDrop } from './hook/useDragAndDrop'
import { useGraphLayout } from './hook/useGraphLayout'
import { useGraphRenderer } from './hook/useGraphRenderer'
import { useMouseEvents } from './hook/useMouseEvents'
import type { IGraphData, IGraphEdgeRenderer, IGraphNode, IGraphNodeRenderer } from './types'

interface IProps {
  readonly data: IGraphData
  readonly nodeRenderer?: IGraphNodeRenderer
  readonly edgeRenderer?: IGraphEdgeRenderer
  readonly theme?: 'light' | 'dark'
  readonly showToolbar?: boolean
  readonly onNodeClick?: (node: IGraphNode) => void
  readonly onNodeHover?: (node: IGraphNode | null) => void
  readonly onNodeReplace?: (sourceNode: IGraphNode, targetNode: IGraphNode) => void
  readonly onNodePositionChange?: (nodeId: string, newPosition: { x: number; y: number }) => void
}

export const DagGraph: React.FC<IProps> = props => {
  const {
    data,
    nodeRenderer,
    edgeRenderer,
    theme = 'light',
    showToolbar = true,
    onNodeClick,
    onNodeHover,
    onNodeReplace,
    onNodePositionChange,
  } = props
  const canvasRef = React.useRef<HTMLCanvasElement>(null)
  const containerRef = React.useRef<HTMLDivElement>(null)

  const [hoveredNode, setHoveredNode] = React.useState<IGraphNode | null>(null)
  const [selectedNode, setSelectedNode] = React.useState<IGraphNode | null>(null)
  const [tooltipPosition, setTooltipPosition] = React.useState({ x: 0, y: 0 })
  const [canvasSize, setCanvasSize] = React.useState({ width: 0, height: 0 })

  const {
    transform,
    handleWheel,
    handleMouseDown,
    handleMouseMove,
    handleMouseUp,
    screenToWorld,
    worldToScreen,
    zoomIn,
    zoomOut,
    resetTransform,
    fitToView,
    setNodeDragging,
  } = useCanvasInteraction(canvasRef)
  const { layoutNodes, clearCache, markNodeAsManuallyPositioned } = useGraphLayout(data)
  const { renderGraph } = useGraphRenderer(canvasRef, theme)

  const positionedNodes = layoutNodes()

  const { dragDropState, handleDragStart, handleDragMove, handleDragEnd } = useDragAndDrop({
    nodes: positionedNodes,
    onNodeReplace,
    onNodePositionChange: (nodeId: string, newPosition: { x: number; y: number }) => {
      // Mark the node as manually positioned
      markNodeAsManuallyPositioned(nodeId, newPosition)
      // Also call the original callback if provided
      onNodePositionChange?.(nodeId, newPosition)
    },
    hitTestNode: (worldX: number, worldY: number) => {
      for (const node of positionedNodes) {
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
    screenToWorld,
    worldToScreen,
  })

  const { handleCanvasMouseMove, handleCanvasClick, handleCanvasMouseDown } = useMouseEvents(
    positionedNodes,
    {
      onNodeClick: node => {
        setSelectedNode(node)
        onNodeClick?.(node)
      },
      onNodeHover: node => {
        setHoveredNode(node)
        onNodeHover?.(node)
      },
      onNodeDragStart: (node, screenX, screenY) => {
        setNodeDragging(true)
        handleDragStart(node, screenX, screenY)
      },
    },
    screenToWorld,
  )

  const handleMouseMoveInternal = useEventCallback((event: MouseEvent) => {
    const canvas = canvasRef.current
    if (!canvas) return

    const rect = canvas.getBoundingClientRect()
    const mouseX = event.clientX - rect.left
    const mouseY = event.clientY - rect.top

    setTooltipPosition({ x: mouseX, y: mouseY })

    if (dragDropState.isDragging) {
      handleDragMove(mouseX, mouseY)
    } else {
      handleCanvasMouseMove(event, rect)
    }

    handleMouseMove(event)
  })

  const handleMouseDownInternal = useEventCallback((event: MouseEvent) => {
    const canvas = canvasRef.current
    if (!canvas) return

    const rect = canvas.getBoundingClientRect()
    const mouseX = event.clientX - rect.left
    const mouseY = event.clientY - rect.top

    handleCanvasMouseDown(event, rect, { x: mouseX, y: mouseY })
    handleMouseDown(event)
  })

  const handleMouseUpInternal = useEventCallback((event: MouseEvent) => {
    const canvas = canvasRef.current
    if (!canvas) return

    const rect = canvas.getBoundingClientRect()
    const mouseX = event.clientX - rect.left
    const mouseY = event.clientY - rect.top

    if (dragDropState.isDragging) {
      handleDragEnd(mouseX, mouseY)
      setNodeDragging(false)
    } else {
      handleCanvasClick(event, rect, { x: mouseX, y: mouseY })
    }

    handleMouseUp()
  })

  React.useEffect(() => {
    const updateCanvasSize = (): void => {
      const container = containerRef.current
      if (!container) return

      const rect = container.getBoundingClientRect()
      const detailPaneWidth = selectedNode ? 320 : 0
      const newWidth = rect.width - detailPaneWidth
      const newHeight = rect.height

      setCanvasSize({ width: newWidth, height: newHeight })
    }

    // Delay initial sizing to ensure container is fully rendered
    const timeoutId = setTimeout(updateCanvasSize, 0)

    // Handle resize
    const resizeObserver = new ResizeObserver(updateCanvasSize)
    if (containerRef.current) {
      resizeObserver.observe(containerRef.current)
    }

    // Handle window resize as backup
    const handleWindowResize = (): void => updateCanvasSize()
    window.addEventListener('resize', handleWindowResize)

    return () => {
      clearTimeout(timeoutId)
      resizeObserver.disconnect()
      window.removeEventListener('resize', handleWindowResize)
    }
  }, [selectedNode])

  React.useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    canvas.width = canvasSize.width
    canvas.height = canvasSize.height

    renderGraph(
      positionedNodes,
      data.edges,
      transform,
      {
        hoveredNode,
        selectedNode,
        nodeStyle: {
          fill: theme === 'dark' ? '#374151' : '#f9fafb',
          stroke: theme === 'dark' ? '#6b7280' : '#d1d5db',
          strokeWidth: 2,
          radius: 8,
          fontSize: 12,
          fontFamily: 'system-ui, -apple-system, sans-serif',
          textColor: theme === 'dark' ? '#f3f4f6' : '#1f2937',
        },
        edgeStyle: {
          stroke: theme === 'dark' ? '#6b7280' : '#9ca3af',
          strokeWidth: 2,
          arrowSize: 8,
          animated: false,
        },
      },
      nodeRenderer,
      edgeRenderer,
    )
  }, [
    data,
    positionedNodes,
    canvasSize.width,
    canvasSize.height,
    theme,
    transform,
    hoveredNode,
    selectedNode,
    renderGraph,
    nodeRenderer,
    edgeRenderer,
  ])

  React.useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    canvas.addEventListener('wheel', handleWheel)
    canvas.addEventListener('mousedown', handleMouseDownInternal)
    canvas.addEventListener('mousemove', handleMouseMoveInternal)
    canvas.addEventListener('mouseup', handleMouseUpInternal)

    return () => {
      canvas.removeEventListener('wheel', handleWheel)
      canvas.removeEventListener('mousedown', handleMouseDownInternal)
      canvas.removeEventListener('mousemove', handleMouseMoveInternal)
      canvas.removeEventListener('mouseup', handleMouseUpInternal)
    }
  }, [handleWheel, handleMouseDownInternal, handleMouseMoveInternal, handleMouseUpInternal])

  const handleReLayout = useEventCallback(() => {
    clearCache()
  })

  const handleFitToView = useEventCallback(() => {
    fitToView(positionedNodes)
  })

  return (
    <div ref={containerRef} className="relative w-full h-full flex">
      <div className="flex-1 relative">
        <canvas
          ref={canvasRef}
          width={canvasSize.width}
          height={canvasSize.height}
          className="cursor-grab active:cursor-grabbing"
        />

        <NodeTooltip node={hoveredNode} position={tooltipPosition} visible={!!hoveredNode} />

        {dragDropState.isDragging && dragDropState.currentPosition && (
          <div
            className={cn(
              'absolute pointer-events-none z-10 border-2 border-dashed rounded px-2 py-1 text-xs font-mono transition-colors',
              {
                'bg-blue-500/20 border-blue-500 text-blue-700 dark:text-blue-300':
                  dragDropState.dragMode === 'positioning',
                'bg-orange-500/20 border-orange-500 text-orange-700 dark:text-orange-300':
                  dragDropState.dragMode === 'replacement' && dragDropState.dropTargetNode,
                'bg-gray-500/20 border-gray-500 text-gray-700 dark:text-gray-300':
                  dragDropState.dragMode === 'replacement' && !dragDropState.dropTargetNode,
              },
            )}
            style={{
              left: dragDropState.currentPosition.x + 10,
              top: dragDropState.currentPosition.y - 10,
              transform: 'translate(-50%, -100%)',
            }}
          >
            {dragDropState.dragMode === 'positioning' && 'Moving node'}
            {dragDropState.dragMode === 'replacement' &&
              dragDropState.dropTargetNode &&
              `Drop to replace: ${dragDropState.dropTargetNode.id.slice(0, 8)}...`}
            {dragDropState.dragMode === 'replacement' &&
              !dragDropState.dropTargetNode &&
              'Drag over node to replace'}
          </div>
        )}

        {showToolbar && (
          <div className="absolute left-4 bottom-4 z-10">
            <GraphToolbar
              transform={transform}
              onZoomIn={zoomIn}
              onZoomOut={zoomOut}
              onZoomReset={resetTransform}
              onFitToView={handleFitToView}
              onReLayout={handleReLayout}
              theme={theme}
            />
          </div>
        )}
      </div>

      {selectedNode && (
        <div className="w-80 bg-white dark:bg-gray-900 border-l border-gray-200 dark:border-gray-600 flex flex-col">
          <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-600">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white">Node Details</h3>
            <button
              onClick={() => setSelectedNode(null)}
              className="text-gray-400 hover:text-gray-600 dark:text-gray-400 dark:hover:text-gray-200 transition-colors"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>

          <div className="flex-1 overflow-y-auto p-4 space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">
                UUID
              </label>
              <div className="font-mono text-sm bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-gray-100 p-2 rounded border dark:border-gray-700">
                {selectedNode.id}
              </div>
            </div>

            {selectedNode.parents.length > 0 && (
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">
                  Parent Nodes
                </label>
                <div className="space-y-1">
                  {selectedNode.parents.map(parentId => (
                    <div
                      key={parentId}
                      className="font-mono text-sm bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-gray-100 p-2 rounded border dark:border-gray-700"
                    >
                      {parentId}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {selectedNode.position && (
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">
                  Position
                </label>
                <div className="font-mono text-sm bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-gray-100 p-2 rounded border dark:border-gray-700">
                  x: {selectedNode.position.x.toFixed(2)}, y: {selectedNode.position.y.toFixed(2)}
                </div>
              </div>
            )}

            {!!selectedNode.data && (
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-2">
                  Data Content
                </label>
                <div className="bg-gray-50 dark:bg-gray-800 p-3 rounded border dark:border-gray-700 overflow-x-auto">
                  <Json json={selectedNode.data} initialCollapsed="expanded" />
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

DagGraph.displayName = 'DagGraph'
