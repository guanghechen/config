import type { IGraphNode } from './node'

export interface IGraphEdge {
  readonly id: string
  readonly source: string
  readonly target: string
  readonly style?: IGraphEdgeStyle
}

export interface IGraphEdgeStyle {
  readonly stroke: string
  readonly strokeWidth: number
  readonly strokeDasharray?: string
  readonly animated?: boolean
  readonly arrowSize: number
}

export interface IGraphEdgeRenderer {
  render(
    ctx: CanvasRenderingContext2D,
    edge: IGraphEdge,
    sourceNode: IGraphNode,
    targetNode: IGraphNode,
    style: IGraphEdgeStyle,
  ): void
}
