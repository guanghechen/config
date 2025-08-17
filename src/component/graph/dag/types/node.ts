export interface IGraphNode {
  readonly id: string
  readonly data: unknown
  readonly parents: string[]
  readonly position?: { x: number; y: number }
  readonly size?: { width: number; height: number }
  readonly isManuallyPositioned?: boolean
}

export interface IGraphNodeStyle {
  readonly fill: string
  readonly stroke: string
  readonly strokeWidth: number
  readonly radius: number
  readonly fontSize: number
  readonly fontFamily: string
  readonly textColor: string
}

export interface IGraphNodeBounds {
  readonly x: number
  readonly y: number
  readonly width: number
  readonly height: number
}

export interface IGraphNodeRenderer {
  render(
    ctx: CanvasRenderingContext2D,
    node: IGraphNode,
    style: IGraphNodeStyle,
    isHovered: boolean,
    isSelected: boolean,
  ): void
  getNodeBounds(node: IGraphNode): { x: number; y: number; width: number; height: number }
}
