import type { IGraphEdge } from './edge'
import type { IGraphNode } from './node'

export interface IGraphData {
  readonly nodes: IGraphNode[]
  readonly edges: IGraphEdge[]
}

export interface IGraphLayoutAlgorithm {
  calculateLayout(nodes: IGraphNode[], edges: IGraphEdge[]): IGraphNode[]
}

export interface IGraphLayoutConfig {
  readonly nodeSpacing: number
  readonly levelSpacing: number
  readonly padding: number
}

export interface ITransform {
  readonly x: number
  readonly y: number
  readonly scale: number
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
