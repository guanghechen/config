import type {
  ICanvasEdgeData,
  ICanvasGraphData,
  ICanvasNodeData,
  ICanvasPortData,
  IWhiteboardDocumentData,
} from './data'

export type IValidationSeverity = 'warn' | 'error'

export interface IValidationIssue {
  readonly code: string
  readonly severity: IValidationSeverity
  readonly message: string
}

export interface ICanvasNodeRuntimeState {
  readonly selected: boolean
  readonly hovered: boolean
}

export interface ICanvasPortRuntimeState {
  readonly connectionCount: number
}

export interface ICanvasEdgeRuntimeState {
  readonly selected: boolean
  readonly hovered: boolean
  readonly validationIssues: ReadonlyArray<IValidationIssue>
}

export interface ICanvasGraphIndex {
  readonly edgeIdsByPortId: Readonly<Record<string, ReadonlyArray<string>>>
  readonly edgeIdsByNodeId: Readonly<Record<string, ReadonlyArray<string>>>
}

export interface ICanvasGraphRuntimeState {
  readonly selectedNodeIds: ReadonlyArray<string>
  readonly selectedEdgeIds: ReadonlyArray<string>
  readonly nodeRuntimeById: Readonly<Record<string, ICanvasNodeRuntimeState>>
  readonly portRuntimeById: Readonly<Record<string, ICanvasPortRuntimeState>>
  readonly edgeRuntimeById: Readonly<Record<string, ICanvasEdgeRuntimeState>>
  readonly nextNodeIndex: number
}

export interface ICanvasNode {
  readonly data: ICanvasNodeData
  readonly runtime: ICanvasNodeRuntimeState
}

export interface ICanvasPort {
  readonly data: ICanvasPortData
  readonly runtime: ICanvasPortRuntimeState
}

export interface ICanvasEdge {
  readonly data: ICanvasEdgeData
  readonly runtime: ICanvasEdgeRuntimeState
}

export interface ICanvasGraph {
  readonly data: ICanvasGraphData
  readonly index: ICanvasGraphIndex
  readonly runtime: ICanvasGraphRuntimeState
}

export interface IWhiteboardDocument {
  readonly data: IWhiteboardDocumentData
  readonly graph: ICanvasGraph
}
