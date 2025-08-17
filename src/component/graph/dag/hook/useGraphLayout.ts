import React from 'react'
import { HierarchicalLayout } from '../layout/HierarchicalLayout'
import type { ILayoutConfig } from '../layout/types'
import type { IGraphData, IGraphNode } from '../types'

interface ILayoutCache {
  data: IGraphData | null
  result: IGraphNode[]
}

export const useGraphLayout = (
  data: IGraphData,
  config?: Partial<ILayoutConfig>,
): {
  layoutNodes: () => IGraphNode[]
  updateLayoutConfig: (newConfig: Partial<ILayoutConfig>) => void
  clearCache: () => void
} => {
  const layoutEngine = React.useMemo(() => new HierarchicalLayout(config), [config])
  const cache = React.useRef<ILayoutCache>({ data: null, result: [] })

  const layoutNodes = React.useCallback((): IGraphNode[] => {
    if (!data.nodes.length) return []

    const dataKey = JSON.stringify({
      nodes: data.nodes.map(n => ({ id: n.id, parents: n.parents })),
      edges: data.edges.map(e => ({ source: e.source, target: e.target })),
    })

    const cachedDataKey = cache.current.data
      ? JSON.stringify({
          nodes: cache.current.data.nodes.map(n => ({ id: n.id, parents: n.parents })),
          edges: cache.current.data.edges.map(e => ({ source: e.source, target: e.target })),
        })
      : null

    if (dataKey === cachedDataKey) {
      return cache.current.result
    }

    const layoutResult = layoutEngine.calculateLayout(data.nodes, data.edges)

    cache.current = {
      data: { ...data },
      result: layoutResult,
    }

    return layoutResult
  }, [data, layoutEngine])

  const updateLayoutConfig = React.useCallback(
    (newConfig: Partial<ILayoutConfig>) => {
      layoutEngine.updateConfig(newConfig)
      cache.current = { data: null, result: [] }
    },
    [layoutEngine],
  )

  const clearCache = React.useCallback(() => {
    cache.current = { data: null, result: [] }
  }, [])

  return {
    layoutNodes,
    updateLayoutConfig,
    clearCache,
  }
}
