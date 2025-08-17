import type { IGraphNode } from './node'

export interface IMouseEventHandlers {
  onNodeClick?: (node: IGraphNode) => void
  onNodeHover?: (node: IGraphNode | null) => void
  onNodeDragStart?: (node: IGraphNode, screenX: number, screenY: number) => void
}
