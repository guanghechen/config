import type { Edge, Node } from '@xyflow/react'
import type { ITextTransformedNode } from '@/shared/types'

export interface IReactFlowNodeData extends Record<string, unknown> {
  readonly uuid: string
  readonly data: unknown
  readonly parents: string[]
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
      title: node.title,
      index: node.index,
      chainPaths,
    },
  }))

  const reactFlowEdges: Edge[] = []
  nodes.forEach(node => {
    node.parents.forEach(parentId => {
      // Check if parentId has @v: prefix
      const isVirtualEdge = parentId.startsWith('@v:')
      const actualParentId = isVirtualEdge ? parentId.slice(3) : parentId

      reactFlowEdges.push({
        id: `${actualParentId}-${node.uuid}`,
        source: actualParentId,
        target: node.uuid,
        type: isVirtualEdge ? 'virtual' : 'smoothstep',
      })
    })
  })

  return { nodes: reactFlowNodes, edges: reactFlowEdges }
}
