import type { Edge, Node, Position } from '@xyflow/react'
import dagre from 'dagre'
import type { IReactFlowNodeData } from './adaptor'

const nodeWidth = 150
const nodeHeight = 60

export const getLayoutedElements = (
  nodes: Array<Node<IReactFlowNodeData>>,
  edges: Edge[],
  direction = 'TB',
): { nodes: Array<Node<IReactFlowNodeData>>; edges: Edge[] } => {
  const dagreGraph = new dagre.graphlib.Graph()
  dagreGraph.setDefaultEdgeLabel(() => ({}))

  const isHorizontal = direction === 'LR'
  dagreGraph.setGraph({ rankdir: direction, nodesep: 50, ranksep: 100 })

  nodes.forEach(node => {
    dagreGraph.setNode(node.id, { width: nodeWidth, height: nodeHeight })
  })

  edges.forEach(edge => {
    dagreGraph.setEdge(edge.source, edge.target)
  })

  dagre.layout(dagreGraph)

  const newNodes = nodes.map(node => {
    const nodeWithPosition = dagreGraph.node(node.id)
    const newNode = {
      ...node,
      targetPosition: isHorizontal ? ('left' as Position) : ('top' as Position),
      sourcePosition: isHorizontal ? ('right' as Position) : ('bottom' as Position),
      position: {
        x: nodeWithPosition.x - nodeWidth / 2,
        y: nodeWithPosition.y - nodeHeight / 2,
      },
    }

    return newNode
  })

  return { nodes: newNodes, edges }
}
