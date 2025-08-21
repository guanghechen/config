import type { Edge, Node } from '@xyflow/react'
import type { ITextTransformedNode } from '@/shared/types'

export interface IReactFlowNodeData {
  readonly uuid: string
  readonly data: unknown
  readonly parents: string[]
}

export const transformNodesToReactFlow = (
  nodes: ITextTransformedNode[],
): { nodes: Array<Node<IReactFlowNodeData>>; edges: Edge[] } => {
  const reactFlowNodes: Array<Node<IReactFlowNodeData>> = nodes.map((node, index) => ({
    id: node.uuid,
    type: 'custom',
    position: { x: index * 350, y: 0 }, // Initial positioning, layout will be calculated later
    data: {
      uuid: node.uuid,
      data: node.data,
      parents: node.parents,
    },
  }))

  const reactFlowEdges: Edge[] = []
  nodes.forEach(node => {
    node.parents.forEach(parentId => {
      reactFlowEdges.push({
        id: `${parentId}-${node.uuid}`,
        source: parentId,
        target: node.uuid,
        type: 'smoothstep',
      })
    })
  })

  return { nodes: reactFlowNodes, edges: reactFlowEdges }
}
