import { useEventCallback } from '@guanghechen/react-hooks'
import React from 'react'
import { HierarchicalLayout } from '../layout/HierarchicalLayout'
import type { IGraphData, IGraphLayoutConfig, IGraphNode } from '../types'

interface ILayoutCache {
  data: IGraphData | null
  result: IGraphNode[]
  customPositions: Map<string, { x: number; y: number }>
}

export const useGraphLayout = (
  data: IGraphData,
  config?: Partial<IGraphLayoutConfig>,
): {
  layoutNodes: () => IGraphNode[]
  updateLayoutConfig: (newConfig: Partial<IGraphLayoutConfig>) => void
  clearCache: () => void
  markNodeAsManuallyPositioned: (nodeId: string, position: { x: number; y: number }) => void
} => {
  const layoutEngine = React.useMemo(() => new HierarchicalLayout(config), [config])
  const cache = React.useRef<ILayoutCache>({ data: null, result: [], customPositions: new Map() })

  const layoutNodes = React.useCallback((): IGraphNode[] => {
    if (!data.nodes.length) return []

    // Apply custom positions to nodes before calculating layout
    const nodesWithCustomPositions = data.nodes.map(node => {
      const customPosition = cache.current.customPositions.get(node.id)
      if (customPosition) {
        return {
          ...node,
          position: customPosition,
          isManuallyPositioned: true,
        }
      }
      return node
    })

    const dataKey = JSON.stringify({
      nodes: nodesWithCustomPositions.map(n => ({
        id: n.id,
        parents: n.parents,
        isManuallyPositioned: n.isManuallyPositioned,
        position: n.position,
      })),
      edges: data.edges.map(e => ({ source: e.source, target: e.target })),
      customPositions: Array.from(cache.current.customPositions.entries()),
    })

    const cachedDataKey = cache.current.data
      ? JSON.stringify({
          nodes: cache.current.data.nodes.map(n => ({
            id: n.id,
            parents: n.parents,
            isManuallyPositioned: n.isManuallyPositioned,
            position: n.position,
          })),
          edges: cache.current.data.edges.map(e => ({ source: e.source, target: e.target })),
          customPositions: Array.from(cache.current.customPositions.entries()),
        })
      : null

    if (dataKey === cachedDataKey) {
      return cache.current.result
    }

    const layoutResult = layoutEngine.calculateLayout(nodesWithCustomPositions, data.edges)

    cache.current = {
      data: { nodes: nodesWithCustomPositions, edges: data.edges },
      result: layoutResult,
      customPositions: cache.current.customPositions,
    }

    return layoutResult
  }, [data, layoutEngine])

  const updateLayoutConfig = React.useCallback(
    (newConfig: Partial<IGraphLayoutConfig>) => {
      layoutEngine.updateConfig(newConfig)
      cache.current = { data: null, result: [], customPositions: cache.current.customPositions }
    },
    [layoutEngine],
  )

  const clearCache = useEventCallback(() => {
    cache.current = { data: null, result: [], customPositions: new Map() }
  })

  const markNodeAsManuallyPositioned = useEventCallback(
    (nodeId: string, position: { x: number; y: number }) => {
      cache.current.customPositions.set(nodeId, position)
      // Clear cached data to force re-layout
      cache.current.data = null
      cache.current.result = []
    }
  )

  return {
    layoutNodes,
    updateLayoutConfig,
    clearCache,
    markNodeAsManuallyPositioned,
  }
}
