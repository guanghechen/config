import type { ICanvasNodeData, IWhiteboardDocumentData } from '@/feature/whiteboard/model'
import type { ICommand } from '../types'

const withUpdatedNodes = (
  data: IWhiteboardDocumentData,
  nodeIds: ReadonlyArray<string>,
  mutator: (node: ICanvasNodeData, index: number) => ICanvasNodeData,
): IWhiteboardDocumentData => {
  if (nodeIds.length === 0) return data

  const nodeSet = new Set(nodeIds)
  const sortedNodes = Object.values(data.graph.nodesById)
    .filter(node => nodeSet.has(node.id))
    .sort((a, b) => {
      if (a.zIndex !== b.zIndex) return a.zIndex - b.zIndex
      return a.nodeIndex - b.nodeIndex
    })

  if (sortedNodes.length === 0) return data

  const nextNodesById: Record<string, ICanvasNodeData> = { ...data.graph.nodesById }
  sortedNodes.forEach((node, index) => {
    nextNodesById[node.id] = {
      ...mutator(node, index),
      updatedAt: Date.now(),
    }
  })

  return {
    ...data,
    graph: {
      ...data.graph,
      nodesById: nextNodesById,
    },
  }
}

export const createBringToFrontCommand = (nodeIds: ReadonlyArray<string>): ICommand => {
  return {
    type: 'BRING_TO_FRONT',
    label: 'Bring to front',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      const maxZ = Math.max(0, ...Object.values(data.graph.nodesById).map(node => node.zIndex))
      return withUpdatedNodes(data, nodeIds, (_node, index) => ({
        ..._node,
        zIndex: maxZ + 1 + index,
      }))
    },
  }
}

export const createSendToBackCommand = (nodeIds: ReadonlyArray<string>): ICommand => {
  return {
    type: 'SEND_TO_BACK',
    label: 'Send to back',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      const minZ = Math.min(0, ...Object.values(data.graph.nodesById).map(node => node.zIndex))
      return withUpdatedNodes(data, nodeIds, (_node, index) => ({
        ..._node,
        zIndex: minZ - (nodeIds.length - index),
      }))
    },
  }
}

export const createBringForwardCommand = (nodeIds: ReadonlyArray<string>): ICommand => {
  return {
    type: 'BRING_FORWARD',
    label: 'Bring forward',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      return withUpdatedNodes(data, nodeIds, node => ({
        ...node,
        zIndex: node.zIndex + 1,
      }))
    },
  }
}

export const createSendBackwardCommand = (nodeIds: ReadonlyArray<string>): ICommand => {
  return {
    type: 'SEND_BACKWARD',
    label: 'Send backward',
    apply(data: IWhiteboardDocumentData): IWhiteboardDocumentData {
      return withUpdatedNodes(data, nodeIds, node => ({
        ...node,
        zIndex: node.zIndex - 1,
      }))
    },
  }
}
