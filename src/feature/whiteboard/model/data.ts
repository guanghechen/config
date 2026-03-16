export interface IWhiteboardDocumentMeta {
  readonly title: string
  readonly description?: string
  readonly createdAt: number
  readonly updatedAt: number
}

export interface ICanvasViewport {
  readonly zoom: number
  readonly offsetX: number
  readonly offsetY: number
  readonly gridSize: number
  readonly showGrid: boolean
}

export interface IWhiteboardDocumentData {
  readonly id: string
  readonly kind: 'yoz.whiteboard'
  readonly schemaVersion: number
  readonly version: number
  readonly graph: ICanvasGraphData
  readonly meta: IWhiteboardDocumentMeta
}

export interface ICanvasGraphData {
  readonly viewport: ICanvasViewport
  readonly edgeOrder: ReadonlyArray<string>
  readonly nodesById: Readonly<Record<string, ICanvasNodeData>>
  readonly portsById: Readonly<Record<string, ICanvasPortData>>
  readonly edgesById: Readonly<Record<string, ICanvasEdgeData>>
}

export interface ICanvasNodeDimension {
  readonly x: number
  readonly y: number
  readonly width: number
  readonly height: number
}

export interface ICanvasNodeTransform {
  readonly rotation: number
  readonly scaleX: number
  readonly scaleY: number
}

export interface ICanvasNodeStatus {
  readonly locked: boolean
  readonly visibility: 'visible' | 'hidden'
}

export interface ICanvasNodeStyle {
  readonly strokeColor: string
  readonly fillColor: string
  readonly strokeWidth: number
  readonly strokeStyle: 'solid' | 'dashed' | 'dotted'
  readonly roughness: number
  readonly opacity: number
  readonly cornerRadius: number
}

export interface ICanvasNodeData {
  readonly id: string
  readonly type: string
  readonly nodeIndex: number
  readonly dimension: ICanvasNodeDimension
  readonly transform: ICanvasNodeTransform
  readonly zIndex: number
  readonly status: ICanvasNodeStatus
  readonly style: ICanvasNodeStyle
  readonly payload: Record<string, unknown>
  readonly portIds: ReadonlyArray<string>
  readonly createdAt: number
  readonly updatedAt: number
}

export type ICanvasPortDirection = 'input' | 'output' | 'bidirectional'
export type ICanvasPortPlacement = 'top' | 'right' | 'bottom' | 'left' | 'custom'

export interface ICanvasPortAnchor {
  readonly xRatio: number
  readonly yRatio: number
}

export interface ICanvasPortData {
  readonly id: string
  readonly nodeId: string
  readonly name: string
  readonly direction: ICanvasPortDirection
  readonly placement: ICanvasPortPlacement
  readonly offsetRatio?: number
  readonly anchor?: ICanvasPortAnchor
  readonly maxConnections: number | null
  readonly accepts: ReadonlyArray<string>
  readonly emits: ReadonlyArray<string>
  readonly required?: boolean
  readonly payload?: Record<string, unknown>
}

export type ICanvasEdgeRouting = 'straight' | 'bezier' | 'orthogonal'

export interface ICanvasEdgeEndpoint {
  readonly nodeId: string
  readonly portId: string
}

export interface ICanvasEdgeStyle {
  readonly strokeColor: string
  readonly strokeWidth: number
  readonly strokeStyle: 'solid' | 'dashed' | 'dotted'
  readonly startMarker: 'none' | 'arrow' | 'dot'
  readonly endMarker: 'none' | 'arrow' | 'dot'
}

export interface ICanvasEdgeData {
  readonly id: string
  readonly from: ICanvasEdgeEndpoint
  readonly to: ICanvasEdgeEndpoint
  readonly routing: ICanvasEdgeRouting
  readonly style: ICanvasEdgeStyle
  readonly label?: string
  readonly payload?: Record<string, unknown>
  readonly createdAt: number
  readonly updatedAt: number
}

export const WHITEBOARD_ZOOM = {
  MIN: 0.1,
  MAX: 30,
  STEP: 0.1,
} as const
