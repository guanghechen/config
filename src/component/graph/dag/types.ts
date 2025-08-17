export interface IGraphNode {
  readonly id: string
  readonly data: unknown
  readonly parents: string[]
  readonly position?: { x: number; y: number }
  readonly size?: { width: number; height: number }
}

export interface IGraphEdge {
  readonly id: string
  readonly source: string
  readonly target: string
  readonly style?: IEdgeStyle
}

export interface IGraphData {
  readonly nodes: IGraphNode[]
  readonly edges: IGraphEdge[]
}

export interface INodeStyle {
  readonly fill: string
  readonly stroke: string
  readonly strokeWidth: number
  readonly radius: number
  readonly fontSize: number
  readonly fontFamily: string
  readonly textColor: string
}

export interface IEdgeStyle {
  readonly stroke: string
  readonly strokeWidth: number
  readonly strokeDasharray?: string
  readonly animated?: boolean
  readonly arrowSize: number
}

export interface ITransform {
  readonly x: number
  readonly y: number
  readonly scale: number
}

export interface IDAGGraphProps {
  readonly data: IGraphData
  readonly width: number
  readonly height: number
  readonly nodeRenderer?: INodeRenderer
  readonly edgeRenderer?: IEdgeRenderer
  readonly onNodeClick?: (node: IGraphNode) => void
  readonly onNodeHover?: (node: IGraphNode | null) => void
  readonly onNodeReplace?: (sourceNode: IGraphNode, targetNode: IGraphNode) => void
  readonly onNodePositionChange?: (nodeId: string, newPosition: { x: number; y: number }) => void
  readonly theme?: 'light' | 'dark'
  readonly showToolbar?: boolean
}

export interface INodeRenderer {
  render(
    ctx: CanvasRenderingContext2D,
    node: IGraphNode,
    style: INodeStyle,
    isHovered: boolean,
    isSelected: boolean,
  ): void
  getNodeBounds(node: IGraphNode): { x: number; y: number; width: number; height: number }
}

export interface IEdgeRenderer {
  render(
    ctx: CanvasRenderingContext2D,
    edge: IGraphEdge,
    sourceNode: IGraphNode,
    targetNode: IGraphNode,
    style: IEdgeStyle,
  ): void
}

export interface IDragDropState {
  readonly isDragging: boolean
  readonly draggedNode: IGraphNode | null
  readonly dropTargetNode: IGraphNode | null
  readonly dragStartPosition: { x: number; y: number } | null
  readonly currentPosition: { x: number; y: number } | null
  readonly dragMode: 'positioning' | 'replacement' | null
  readonly dragOffset: { x: number; y: number } | null
}

export interface IToolbarProps {
  readonly transform: ITransform
  readonly onZoomIn: () => void
  readonly onZoomOut: () => void
  readonly onZoomReset: () => void
  readonly onFitToView: () => void
  readonly onReLayout: () => void
  readonly theme?: 'light' | 'dark'
}
