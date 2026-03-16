import { IdFactory } from '@/feature/whiteboard/model'
import type {
  ICanvasNodeData,
  ICanvasNodeDimension,
  ICanvasNodeStatus,
  ICanvasNodeStyle,
  ICanvasNodeTransform,
  ICanvasPortData,
  IWhiteboardDocumentData,
} from '@/feature/whiteboard/model'
import type { ICommand } from '../types'

export interface ICreateNodeInput {
  readonly id?: string
  readonly type: string
  readonly x: number
  readonly y: number
  readonly width?: number
  readonly height?: number
  readonly zIndex?: number
  readonly payload?: Record<string, unknown>
}

const DEFAULT_NODE_STYLE: ICanvasNodeStyle = {
  strokeColor: '#334155',
  fillColor: '#f8fafc',
  strokeWidth: 2,
  strokeStyle: 'solid',
  roughness: 0,
  opacity: 1,
  cornerRadius: 8,
}

const DEFAULT_NODE_STATUS: ICanvasNodeStatus = {
  locked: false,
  visibility: 'visible',
}

const DEFAULT_NODE_TRANSFORM: ICanvasNodeTransform = {
  rotation: 0,
  scaleX: 1,
  scaleY: 1,
}

const createNodeDimension = (input: ICreateNodeInput): ICanvasNodeDimension => {
  return {
    x: input.x,
    y: input.y,
    width: input.width ?? 220,
    height: input.height ?? 120,
  }
}

const getNextNodeIndex = (doc: IWhiteboardDocumentData): number => {
  const values = Object.values(doc.graph.nodesById)
  if (values.length === 0) return 1
  return Math.max(...values.map(node => node.nodeIndex)) + 1
}

const cloneNodeWithDimension = (
  node: ICanvasNodeData,
  dimension: Partial<ICanvasNodeDimension>,
): ICanvasNodeData => {
  return {
    ...node,
    dimension: {
      ...node.dimension,
      ...dimension,
    },
  }
}

const inferPortTypes = (
  nodeType: string,
): { accepts: ReadonlyArray<string>; emits: ReadonlyArray<string> } => {
  if (nodeType === 'node.markdown') {
    return {
      accepts: ['markdown', 'text'],
      emits: ['markdown', 'text'],
    }
  }

  if (nodeType === 'node.text') {
    return {
      accepts: ['text'],
      emits: ['text'],
    }
  }

  if (nodeType === 'node.image') {
    return {
      accepts: ['image'],
      emits: ['image'],
    }
  }

  if (nodeType.startsWith('shape.')) {
    return {
      accepts: ['shape'],
      emits: ['shape'],
    }
  }

  return {
    accepts: ['shape', 'text', 'markdown'],
    emits: ['shape', 'text', 'markdown'],
  }
}

const createDefaultPorts = (nodeId: string, nodeType: string): ReadonlyArray<ICanvasPortData> => {
  const portTypes = inferPortTypes(nodeType)

  const inputPort: ICanvasPortData = {
    id: IdFactory.createPortId(),
    nodeId,
    name: 'input',
    direction: 'input',
    placement: 'left',
    offsetRatio: 0.5,
    maxConnections: null,
    accepts: portTypes.accepts,
    emits: [],
  }

  const outputPort: ICanvasPortData = {
    id: IdFactory.createPortId(),
    nodeId,
    name: 'output',
    direction: 'output',
    placement: 'right',
    offsetRatio: 0.5,
    maxConnections: null,
    accepts: [],
    emits: portTypes.emits,
  }

  return [inputPort, outputPort]
}

export const createCreateNodeCommand = (input: ICreateNodeInput): ICommand => {
  return {
    type: 'CREATE_NODE',
    label: 'Create node',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      const nodeId = input.id ?? IdFactory.createNodeId()
      const node: ICanvasNodeData = {
        id: nodeId,
        type: input.type,
        nodeIndex: getNextNodeIndex(data),
        dimension: createNodeDimension(input),
        transform: DEFAULT_NODE_TRANSFORM,
        zIndex: input.zIndex ?? 0,
        status: DEFAULT_NODE_STATUS,
        style: DEFAULT_NODE_STYLE,
        payload: input.payload ?? {},
        portIds: [],
        createdAt: Date.now(),
        updatedAt: Date.now(),
      }

      const ports = createDefaultPorts(nodeId, input.type)

      return {
        ...data,
        graph: {
          ...data.graph,
          nodesById: {
            ...data.graph.nodesById,
            [node.id]: {
              ...node,
              portIds: ports.map(port => port.id),
            },
          },
          portsById: {
            ...data.graph.portsById,
            ...Object.fromEntries(ports.map(port => [port.id, port])),
          },
        },
      }
    },
  }
}

export const moveNodeByDelta = (
  data: IWhiteboardDocumentData,
  nodeId: string,
  deltaX: number,
  deltaY: number,
): IWhiteboardDocumentData => {
  const node = data.graph.nodesById[nodeId]
  if (!node) return data

  const nextNode = cloneNodeWithDimension(node, {
    x: node.dimension.x + deltaX,
    y: node.dimension.y + deltaY,
  })

  return {
    ...data,
    graph: {
      ...data.graph,
      nodesById: {
        ...data.graph.nodesById,
        [node.id]: {
          ...nextNode,
          updatedAt: Date.now(),
        },
      },
    },
  }
}

export const moveNodeTo = (
  data: IWhiteboardDocumentData,
  nodeId: string,
  x: number,
  y: number,
): IWhiteboardDocumentData => {
  const node = data.graph.nodesById[nodeId]
  if (!node) return data

  const nextNode = cloneNodeWithDimension(node, { x, y })

  return {
    ...data,
    graph: {
      ...data.graph,
      nodesById: {
        ...data.graph.nodesById,
        [node.id]: {
          ...nextNode,
          updatedAt: Date.now(),
        },
      },
    },
  }
}

export const moveNodesByDelta = (
  data: IWhiteboardDocumentData,
  nodeIds: ReadonlyArray<string>,
  deltaX: number,
  deltaY: number,
): IWhiteboardDocumentData => {
  if (nodeIds.length === 0) return data

  const nodeIdSet = new Set(nodeIds)
  let changed = false
  const nextNodesById: Record<string, ICanvasNodeData> = { ...data.graph.nodesById }

  for (const node of Object.values(data.graph.nodesById)) {
    if (!nodeIdSet.has(node.id)) continue

    const movedNode = cloneNodeWithDimension(node, {
      x: node.dimension.x + deltaX,
      y: node.dimension.y + deltaY,
    })
    nextNodesById[node.id] = {
      ...movedNode,
      updatedAt: Date.now(),
    }
    changed = true
  }

  if (!changed) return data

  return {
    ...data,
    graph: {
      ...data.graph,
      nodesById: nextNodesById,
    },
  }
}

export const resizeNodeTo = (
  data: IWhiteboardDocumentData,
  nodeId: string,
  width: number,
  height: number,
): IWhiteboardDocumentData => {
  const node = data.graph.nodesById[nodeId]
  if (!node) return data

  const clampedWidth = Math.max(64, width)
  const clampedHeight = Math.max(48, height)
  if (node.dimension.width === clampedWidth && node.dimension.height === clampedHeight) {
    return data
  }

  const resizedNode = cloneNodeWithDimension(node, {
    width: clampedWidth,
    height: clampedHeight,
  })

  return {
    ...data,
    graph: {
      ...data.graph,
      nodesById: {
        ...data.graph.nodesById,
        [node.id]: {
          ...resizedNode,
          updatedAt: Date.now(),
        },
      },
    },
  }
}

export const createUpdateNodePayloadCommand = (
  nodeId: string,
  payloadPatch: Record<string, unknown>,
): ICommand => {
  return {
    type: 'UPDATE_NODE_PAYLOAD',
    label: 'Update node payload',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      const node = data.graph.nodesById[nodeId]
      if (!node) return data

      return {
        ...data,
        graph: {
          ...data.graph,
          nodesById: {
            ...data.graph.nodesById,
            [node.id]: {
              ...node,
              payload: {
                ...node.payload,
                ...payloadPatch,
              },
              updatedAt: Date.now(),
            },
          },
        },
      }
    },
  }
}

export const createDeleteNodesCommand = (nodeIds: ReadonlyArray<string>): ICommand => {
  return {
    type: 'DELETE_NODES',
    label: 'Delete nodes',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      if (nodeIds.length === 0) return data

      const nodeSet = new Set(nodeIds)
      const nextNodesById: Record<string, ICanvasNodeData> = {}
      const removedPortIds = new Set<string>()

      for (const node of Object.values(data.graph.nodesById)) {
        if (nodeSet.has(node.id)) {
          for (const portId of node.portIds) {
            removedPortIds.add(portId)
          }
          continue
        }

        nextNodesById[node.id] = node
      }

      const nextPortsById: Record<string, (typeof data.graph.portsById)[string]> = {}
      for (const port of Object.values(data.graph.portsById)) {
        if (removedPortIds.has(port.id)) continue
        if (nodeSet.has(port.nodeId)) continue
        nextPortsById[port.id] = port
      }

      const nextEdgesById: Record<string, (typeof data.graph.edgesById)[string]> = {}
      for (const edge of Object.values(data.graph.edgesById)) {
        if (nodeSet.has(edge.from.nodeId) || nodeSet.has(edge.to.nodeId)) continue
        if (removedPortIds.has(edge.from.portId) || removedPortIds.has(edge.to.portId)) continue
        nextEdgesById[edge.id] = edge
      }

      return {
        ...data,
        graph: {
          ...data.graph,
          nodesById: nextNodesById,
          portsById: nextPortsById,
          edgesById: nextEdgesById,
          edgeOrder: data.graph.edgeOrder.filter(edgeId => edgeId in nextEdgesById),
        },
      }
    },
  }
}
