import type { Edge, Node } from '@xyflow/react'
import type { ITextTransformedNode } from '@/shared/types'

export interface IReactFlowNodeData extends Record<string, unknown> {
  readonly uuid: string
  readonly data: unknown
  readonly parents: string[]
  readonly parents_virtual: string[]
  readonly title: string
  readonly index: number
  readonly chainPaths?: string[]
}

export const transformNodesToReactFlow = (
  nodes: ITextTransformedNode[],
  chainPaths?: string[],
): { nodes: Array<Node<IReactFlowNodeData>>; edges: Edge[] } => {
  const reactFlowNodes: Array<Node<IReactFlowNodeData>> = nodes.map((node, index) => ({
    id: node.uuid,
    type: 'custom',
    position: { x: index * 350, y: 0 }, // Initial positioning, layout will be calculated later
    data: {
      uuid: node.uuid,
      data: node.data,
      parents: node.parents,
      parents_virtual: node.parents_virtual,
      title: node.title,
      index: node.index,
      chainPaths,
    },
  }))

  const reactFlowEdges: Edge[] = []
  nodes.forEach(node => {
    // Add regular parent edges
    node.parents.forEach(parentId => {
      reactFlowEdges.push({
        id: `${parentId}-${node.uuid}`,
        source: parentId,
        target: node.uuid,
        type: 'smoothstep',
      })
    })

    // Add virtual parent edges
    node.parents_virtual.forEach(parentId => {
      reactFlowEdges.push({
        id: `virtual-${parentId}-${node.uuid}`,
        source: parentId,
        target: node.uuid,
        type: 'virtual',
      })
    })
  })

  return { nodes: reactFlowNodes, edges: reactFlowEdges }
}
