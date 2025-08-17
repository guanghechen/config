import type { IGraphEdge, IGraphNode } from '../types'

export interface ILayoutAlgorithm {
  calculateLayout(nodes: IGraphNode[], edges: IGraphEdge[]): IGraphNode[]
}

export interface ILayoutConfig {
  readonly nodeSpacing: number
  readonly levelSpacing: number
  readonly padding: number
}
