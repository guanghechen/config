import { IdFactory } from '@/feature/whiteboard/model'
import type {
  ICanvasEdgeData,
  ICanvasNodeData,
  ICanvasPortData,
  IWhiteboardDocumentData,
} from '@/feature/whiteboard/model'
import type { ICommand } from '../types'

export interface IClipboardNodeBundle {
  readonly node: ICanvasNodeData
  readonly ports: ReadonlyArray<ICanvasPortData>
}

export interface IClipboardSnapshot {
  readonly nodes: ReadonlyArray<IClipboardNodeBundle>
  readonly edges: ReadonlyArray<ICanvasEdgeData>
}

const getNextNodeIndexStart = (data: IWhiteboardDocumentData): number => {
  const nodes = Object.values(data.graph.nodesById)
  if (nodes.length === 0) return 1
  return Math.max(...nodes.map(node => node.nodeIndex)) + 1
}

export const createClipboardSnapshotFromSelection = (
  data: IWhiteboardDocumentData,
  selectedNodeIds: ReadonlyArray<string>,
): IClipboardSnapshot => {
  const selectedNodeSet = new Set(selectedNodeIds)

  const nodes: IClipboardNodeBundle[] = selectedNodeIds
    .map(nodeId => data.graph.nodesById[nodeId])
    .filter((node): node is ICanvasNodeData => Boolean(node))
    .map(node => {
      const ports = node.portIds
        .map(portId => data.graph.portsById[portId])
        .filter((port): port is ICanvasPortData => Boolean(port))

      return { node, ports }
    })

  const selectedPortSet = new Set<string>(nodes.flatMap(item => item.ports.map(port => port.id)))
  const edges = Object.values(data.graph.edgesById).filter(edge => {
    return (
      selectedNodeSet.has(edge.from.nodeId) &&
      selectedNodeSet.has(edge.to.nodeId) &&
      selectedPortSet.has(edge.from.portId) &&
      selectedPortSet.has(edge.to.portId)
    )
  })

  return { nodes, edges }
}

export const createPasteClipboardCommand = (
  snapshot: IClipboardSnapshot,
  offsetX: number,
  offsetY: number,
): ICommand => {
  return {
    type: 'PASTE_CLIPBOARD',
    label: 'Paste nodes',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      if (snapshot.nodes.length === 0) return data

      const nodeIdMap = new Map<string, string>()
      const portIdMap = new Map<string, string>()
      const nextNodesById: Record<string, ICanvasNodeData> = { ...data.graph.nodesById }
      const nextPortsById: Record<string, ICanvasPortData> = { ...data.graph.portsById }
      const nextEdgesById: Record<string, ICanvasEdgeData> = { ...data.graph.edgesById }
      const nextEdgeOrder = [...data.graph.edgeOrder]

      let nextNodeIndex = getNextNodeIndexStart(data)
      const now = Date.now()

      for (const item of snapshot.nodes) {
        const newNodeId = IdFactory.createNodeId()
        nodeIdMap.set(item.node.id, newNodeId)

        const remappedPorts: ICanvasPortData[] = item.ports.map(port => {
          const newPortId = IdFactory.createPortId()
          portIdMap.set(port.id, newPortId)

          return {
            ...port,
            id: newPortId,
            nodeId: newNodeId,
          }
        })

        const newNode: ICanvasNodeData = {
          ...item.node,
          id: newNodeId,
          nodeIndex: nextNodeIndex,
          dimension: {
            ...item.node.dimension,
            x: item.node.dimension.x + offsetX,
            y: item.node.dimension.y + offsetY,
          },
          portIds: remappedPorts.map(port => port.id),
          createdAt: now,
          updatedAt: now,
        }

        nextNodesById[newNode.id] = newNode
        nextNodeIndex += 1

        for (const port of remappedPorts) {
          nextPortsById[port.id] = port
        }
      }

      for (const edge of snapshot.edges) {
        const fromNodeId = nodeIdMap.get(edge.from.nodeId)
        const toNodeId = nodeIdMap.get(edge.to.nodeId)
        const fromPortId = portIdMap.get(edge.from.portId)
        const toPortId = portIdMap.get(edge.to.portId)

        if (!fromNodeId || !toNodeId || !fromPortId || !toPortId) continue

        const newEdgeId = IdFactory.createEdgeId()
        const newEdge: ICanvasEdgeData = {
          ...edge,
          id: newEdgeId,
          from: {
            nodeId: fromNodeId,
            portId: fromPortId,
          },
          to: {
            nodeId: toNodeId,
            portId: toPortId,
          },
          createdAt: now,
          updatedAt: now,
        }

        nextEdgesById[newEdge.id] = newEdge
        nextEdgeOrder.push(newEdge.id)
      }

      return {
        ...data,
        graph: {
          ...data.graph,
          nodesById: nextNodesById,
          portsById: nextPortsById,
          edgesById: nextEdgesById,
          edgeOrder: nextEdgeOrder,
        },
      }
    },
  }
}
