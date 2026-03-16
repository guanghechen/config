import type {
  ICanvasEdgeRuntimeState,
  ICanvasGraph,
  ICanvasGraphIndex,
  ICanvasGraphRuntimeState,
  ICanvasNodeRuntimeState,
  ICanvasPortRuntimeState,
  IWhiteboardDocument,
  IWhiteboardDocumentData,
} from '@/feature/whiteboard/model'

const createGraphIndex = (data: IWhiteboardDocumentData['graph']): ICanvasGraphIndex => {
  const edgeIdsByPortId: Record<string, string[]> = {}
  const edgeIdsByNodeId: Record<string, string[]> = {}

  for (const edgeId of Object.keys(data.edgesById)) {
    const edge = data.edgesById[edgeId]

    edgeIdsByPortId[edge.from.portId] = [...(edgeIdsByPortId[edge.from.portId] ?? []), edge.id]
    edgeIdsByPortId[edge.to.portId] = [...(edgeIdsByPortId[edge.to.portId] ?? []), edge.id]

    edgeIdsByNodeId[edge.from.nodeId] = [...(edgeIdsByNodeId[edge.from.nodeId] ?? []), edge.id]
    edgeIdsByNodeId[edge.to.nodeId] = [...(edgeIdsByNodeId[edge.to.nodeId] ?? []), edge.id]
  }

  return {
    edgeIdsByPortId,
    edgeIdsByNodeId,
  }
}

const inferNextNodeIndex = (nodesById: IWhiteboardDocumentData['graph']['nodesById']): number => {
  const nodeIndexes = Object.values(nodesById).map(node => node.nodeIndex)
  const maxNodeIndex = nodeIndexes.length > 0 ? Math.max(...nodeIndexes) : 0
  return maxNodeIndex + 1
}

const createGraphRuntimeState = (
  data: IWhiteboardDocumentData['graph'],
): ICanvasGraphRuntimeState => {
  const nodeRuntimeById: Record<string, ICanvasNodeRuntimeState> = {}
  const portRuntimeById: Record<string, ICanvasPortRuntimeState> = {}
  const edgeRuntimeById: Record<string, ICanvasEdgeRuntimeState> = {}

  for (const nodeId of Object.keys(data.nodesById)) {
    nodeRuntimeById[nodeId] = {
      selected: false,
      hovered: false,
    }
  }

  for (const portId of Object.keys(data.portsById)) {
    portRuntimeById[portId] = {
      connectionCount: 0,
    }
  }

  for (const edgeId of Object.keys(data.edgesById)) {
    edgeRuntimeById[edgeId] = {
      selected: false,
      hovered: false,
      validationIssues: [],
    }
  }

  return {
    selectedNodeIds: [],
    selectedEdgeIds: [],
    nodeRuntimeById,
    portRuntimeById,
    edgeRuntimeById,
    nextNodeIndex: inferNextNodeIndex(data.nodesById),
  }
}

export const hydrateDocument = (data: IWhiteboardDocumentData): IWhiteboardDocument => {
  const graph: ICanvasGraph = {
    data: data.graph,
    index: createGraphIndex(data.graph),
    runtime: createGraphRuntimeState(data.graph),
  }

  return {
    data,
    graph,
  }
}
