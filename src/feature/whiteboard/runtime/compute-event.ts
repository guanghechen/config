import type {
  ICanvasNodeDimension,
  ICanvasNodeStatus,
  ICanvasNodeTransform,
  ICanvasPortAnchor,
  ICanvasPortPlacement,
} from '@/feature/whiteboard/model'

export type IComputeEventType =
  | 'EDGE_DRAG_VALIDATE'
  | 'NODE_GEOMETRY_CHANGED'
  | 'PORT_CONFIG_CHANGED'
  | 'NODE_STATUS_CHANGED'
  | 'EDGE_CREATED_OR_REMOVED'
  | 'REVALIDATE_SCOPE'
  | 'REVALIDATE_ALL'
  | 'REBUILD_GRAPH_INDEX'
  | 'SYNC_RUNTIME_FLAGS'

export type IComputePriority = 'realtime' | 'high' | 'normal' | 'idle'

export type IComputeCoalesceStrategy = 'replace-latest' | 'merge-set' | 'drop-others-and-run-once'

export interface IComputeEventFrom {
  readonly source:
    | 'tool'
    | 'inspector'
    | 'shortcut'
    | 'command_bus'
    | 'storage_recovery'
    | 'importer'
    | 'system'
  readonly activeId?: string
  readonly commandId?: string
  readonly traceId: string
}

export interface IComputePayloadMap {
  readonly EDGE_DRAG_VALIDATE: {
    readonly fromNodeId: string
    readonly fromPortId: string
    readonly pointerCanvasX: number
    readonly pointerCanvasY: number
    readonly candidateToNodeId?: string
    readonly candidateToPortId?: string
  }
  readonly NODE_GEOMETRY_CHANGED: {
    readonly nodeId: string
    readonly dimension: ICanvasNodeDimension
    readonly transform: ICanvasNodeTransform
  }
  readonly PORT_CONFIG_CHANGED: {
    readonly nodeId: string
    readonly portId: string
    readonly placement: ICanvasPortPlacement
    readonly offsetRatio?: number
    readonly anchor?: ICanvasPortAnchor
    readonly accepts: ReadonlyArray<string>
    readonly emits: ReadonlyArray<string>
  }
  readonly NODE_STATUS_CHANGED: {
    readonly nodeId: string
    readonly status: ICanvasNodeStatus
  }
  readonly EDGE_CREATED_OR_REMOVED: {
    readonly edgeId: string
    readonly operation: 'create' | 'remove'
    readonly fromNodeId: string
    readonly toNodeId: string
  }
  readonly REVALIDATE_SCOPE: {
    readonly nodeIds?: ReadonlyArray<string>
    readonly edgeIds?: ReadonlyArray<string>
    readonly portIds?: ReadonlyArray<string>
    readonly reason: 'command' | 'queue-merge' | 'import'
  }
  readonly REVALIDATE_ALL: {
    readonly reason: 'load' | 'import' | 'recovery' | 'manual'
  }
  readonly REBUILD_GRAPH_INDEX: {
    readonly reason: 'load' | 'import' | 'integrity-check'
  }
  readonly SYNC_RUNTIME_FLAGS: {
    readonly nodeIds?: ReadonlyArray<string>
    readonly edgeIds?: ReadonlyArray<string>
    readonly reason: 'selection' | 'hover' | 'tool-switch'
  }
}

export type IComputePayload<TType extends IComputeEventType> = IComputePayloadMap[TType]

export interface IComputeEvent<TType extends IComputeEventType = IComputeEventType> {
  readonly id: string
  readonly type: TType
  readonly priority: IComputePriority
  readonly key: string
  readonly payload: IComputePayload<TType>
  readonly from: IComputeEventFrom
  readonly createdAt: number
}

export interface IComputeEventSpec<TPayload = unknown> {
  readonly key: (payload: TPayload, from: IComputeEventFrom) => string
  readonly coalesce: IComputeCoalesceStrategy
}

export type IComputeEventCatalog = {
  readonly [K in IComputeEventType]: IComputeEventSpec<IComputePayloadMap[K]>
}

export const COMPUTE_EVENT_CATALOG: IComputeEventCatalog = {
  EDGE_DRAG_VALIDATE: {
    key: (_payload: IComputePayloadMap['EDGE_DRAG_VALIDATE'], from: IComputeEventFrom): string =>
      `EDGE_DRAG_VALIDATE:${from.activeId ?? 'unknown'}`,
    coalesce: 'replace-latest',
  },
  NODE_GEOMETRY_CHANGED: {
    key: (payload: IComputePayloadMap['NODE_GEOMETRY_CHANGED']): string =>
      `NODE_GEOMETRY_CHANGED:${payload.nodeId}`,
    coalesce: 'replace-latest',
  },
  PORT_CONFIG_CHANGED: {
    key: (payload: IComputePayloadMap['PORT_CONFIG_CHANGED']): string =>
      `PORT_CONFIG_CHANGED:${payload.portId}`,
    coalesce: 'replace-latest',
  },
  NODE_STATUS_CHANGED: {
    key: (payload: IComputePayloadMap['NODE_STATUS_CHANGED']): string =>
      `NODE_STATUS_CHANGED:${payload.nodeId}`,
    coalesce: 'replace-latest',
  },
  EDGE_CREATED_OR_REMOVED: {
    key: (payload: IComputePayloadMap['EDGE_CREATED_OR_REMOVED']): string =>
      `EDGE_CREATED_OR_REMOVED:${payload.edgeId}`,
    coalesce: 'replace-latest',
  },
  REVALIDATE_SCOPE: {
    key: (): string => 'REVALIDATE_SCOPE',
    coalesce: 'merge-set',
  },
  REVALIDATE_ALL: {
    key: (): string => 'REVALIDATE_ALL',
    coalesce: 'drop-others-and-run-once',
  },
  REBUILD_GRAPH_INDEX: {
    key: (): string => 'REBUILD_GRAPH_INDEX',
    coalesce: 'drop-others-and-run-once',
  },
  SYNC_RUNTIME_FLAGS: {
    key: (): string => 'SYNC_RUNTIME_FLAGS',
    coalesce: 'replace-latest',
  },
}
