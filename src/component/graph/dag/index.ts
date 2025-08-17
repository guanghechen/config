// Main exports for DAG graph component
import type { ITextTransformedNode } from '@/shared/transform/types'
import type { IGraphData, IGraphEdge, IGraphNode } from './types'

export { DAGGraph } from './DAGGraph'
export { GraphToolbar } from './component'
export type {
  IDAGGraphProps,
  IGraphNode,
  IGraphEdge,
  IGraphData,
  INodeStyle,
  IEdgeStyle,
  ITransform,
  INodeRenderer,
  IEdgeRenderer,
  IDragDropState,
  IToolbarProps,
} from './types'

export const transformNodesToGraphData = (nodes: ITextTransformedNode[]): IGraphData => {
  const graphNodes: IGraphNode[] = nodes.map(node => ({
    id: node.uuid,
    data: node.data,
    parents: node.parents,
  }))

  const graphEdges: IGraphEdge[] = []

  nodes.forEach(node => {
    node.parents.forEach(parentId => {
      graphEdges.push({
        id: `${parentId}-${node.uuid}`,
        source: parentId,
        target: node.uuid,
      })
    })
  })

  return { nodes: graphNodes, edges: graphEdges }
}
