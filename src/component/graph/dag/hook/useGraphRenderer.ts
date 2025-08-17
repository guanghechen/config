/* eslint-disable no-param-reassign */
import React, { useCallback } from 'react'
import { DefaultEdgeRenderer } from '../layout/DefaultEdgeRenderer'
import { DefaultNodeRenderer } from '../layout/DefaultNodeRenderer'
import type {
  IGraphEdgeRenderer,
  IGraphEdgeStyle,
  IGraphEdge,
  IGraphNode,
  IGraphNodeRenderer,
  IGraphNodeStyle,
  ITransform,
} from '../types'

interface IRenderConfig {
  nodeStyle: IGraphNodeStyle
  edgeStyle: IGraphEdgeStyle
  hoveredNode: IGraphNode | null
  selectedNode: IGraphNode | null
}

export const useGraphRenderer = (
  canvasRef: React.RefObject<HTMLCanvasElement | null>,
  theme: 'light' | 'dark',
): {
  renderGraph: (
    nodes: IGraphNode[],
    edges: IGraphEdge[],
    transform: ITransform,
    config?: Partial<IRenderConfig>,
    customNodeRenderer?: IGraphNodeRenderer,
    customEdgeRenderer?: IGraphEdgeRenderer,
  ) => void
  startRenderLoop: (renderFn: () => void) => void
  stopRenderLoop: () => void
  getDefaultStyles: () => { nodeStyle: IGraphNodeStyle; edgeStyle: IGraphEdgeStyle }
} => {
  const animationFrameRef = React.useRef<number | null>(null)
  const defaultNodeRenderer = React.useRef(new DefaultNodeRenderer())
  const defaultEdgeRenderer = React.useRef(new DefaultEdgeRenderer())

  const getDefaultStyles = React.useCallback((): {
    nodeStyle: IGraphNodeStyle
    edgeStyle: IGraphEdgeStyle
  } => {
    const isDark = theme === 'dark'

    return {
      nodeStyle: {
        fill: isDark ? '#374151' : '#f9fafb',
        stroke: isDark ? '#6b7280' : '#d1d5db',
        strokeWidth: 2,
        radius: 8,
        fontSize: 12,
        fontFamily: 'system-ui, -apple-system, sans-serif',
        textColor: isDark ? '#f3f4f6' : '#1f2937',
      },
      edgeStyle: {
        stroke: isDark ? '#6b7280' : '#9ca3af',
        strokeWidth: 2,
        arrowSize: 8,
        animated: false,
      },
    }
  }, [theme])

  const clearCanvas = React.useCallback(
    (ctx: CanvasRenderingContext2D, width: number, height: number) => {
      ctx.clearRect(0, 0, width, height)

      const isDark = theme === 'dark'
      const backgroundColor = isDark ? '#1f2937' : '#ffffff'
      ctx.save()
      ctx.fillStyle = backgroundColor
      ctx.fillRect(0, 0, width, height)
      ctx.restore()
    },
    [theme],
  )

  const applyTransform = useCallback((ctx: CanvasRenderingContext2D, transform: ITransform) => {
    ctx.setTransform(transform.scale, 0, 0, transform.scale, transform.x, transform.y)
  }, [])

  const renderGraph = useCallback(
    (
      nodes: IGraphNode[],
      edges: IGraphEdge[],
      transform: ITransform,
      config?: Partial<IRenderConfig>,
      customNodeRenderer?: IGraphNodeRenderer,
      customEdgeRenderer?: IGraphEdgeRenderer,
    ) => {
      const canvas = canvasRef.current
      if (!canvas) return

      const ctx = canvas.getContext('2d')
      if (!ctx) return

      const defaultStyles = getDefaultStyles()
      const renderConfig: IRenderConfig = {
        nodeStyle: defaultStyles.nodeStyle,
        edgeStyle: defaultStyles.edgeStyle,
        hoveredNode: null,
        selectedNode: null,
        ...config,
      }

      const nodeRenderer = customNodeRenderer || defaultNodeRenderer.current
      const edgeRenderer = customEdgeRenderer || defaultEdgeRenderer.current

      clearCanvas(ctx, canvas.width, canvas.height)

      ctx.save()
      applyTransform(ctx, transform)

      edges.forEach(edge => {
        const sourceNode = nodes.find(n => n.id === edge.source)
        const targetNode = nodes.find(n => n.id === edge.target)

        if (sourceNode && targetNode) {
          const edgeStyle = edge.style || renderConfig.edgeStyle
          edgeRenderer.render(ctx, edge, sourceNode, targetNode, edgeStyle)
        }
      })

      nodes.forEach(node => {
        const isHovered = renderConfig.hoveredNode?.id === node.id
        const isSelected = renderConfig.selectedNode?.id === node.id

        nodeRenderer.render(ctx, node, renderConfig.nodeStyle, isHovered, isSelected)
      })

      ctx.restore()
    },
    [canvasRef, getDefaultStyles, clearCanvas, applyTransform],
  )

  const startRenderLoop = useCallback((renderFn: () => void) => {
    const animate = (): void => {
      renderFn()
      animationFrameRef.current = requestAnimationFrame(animate)
    }

    animationFrameRef.current = requestAnimationFrame(animate)
  }, [])

  const stopRenderLoop = useCallback(() => {
    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current)
      animationFrameRef.current = null
    }
  }, [])

  return {
    renderGraph,
    startRenderLoop,
    stopRenderLoop,
    getDefaultStyles,
  }
}
