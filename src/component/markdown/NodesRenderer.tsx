import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Node } from '@yozora/ast'
import React from 'react'
import { useMarkdownTopViewmodel } from './context/top'
import type { INodeRenderer, INodeRendererMap } from './types'
import './style.css'

export interface IProps {
  /**
   * Ast nodes.
   */
  readonly nodes: Node[]
  /**
   * The start index of the nodes to render.
   */
  readonly startIndex?: number
  /**
   * The end index of the nodes to render.
   */
  readonly endIndex?: number
}

export const NodesRenderer: React.FC<IProps> = props => {
  const { nodes } = props
  const startIndex: number = Math.max(0, props.startIndex ?? 0)
  const endIndex: number = Math.min(nodes.length, props.endIndex ?? nodes.length)

  const viewmodel = useMarkdownTopViewmodel()
  const rendererMap: Readonly<INodeRendererMap> = useStateValue(viewmodel.rendererMap$)
  const elements: React.ReactElement[] = []
  for (let index = startIndex; index < endIndex; index++) {
    const node: Node = nodes[index]
    const key = `${node.type}-${index - startIndex}`
    const Renderer: INodeRenderer = rendererMap[node.type] ?? rendererMap._fallback
    const element = <Renderer key={key} {...node} />
    elements.push(element)
  }

  return <React.Fragment>{elements}</React.Fragment>
}
