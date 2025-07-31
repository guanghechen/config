import type { Node } from '@yozora/ast'
import React from 'react'
import { useMarkdownRendererMap } from './context'
import type { INodeRenderer } from './types'
import './style.css'

export interface IProps {
  /**
   * Ast nodes.
   */
  readonly nodes: Node[]
}

export const NodesRenderer: React.FC<IProps> = props => {
  const { nodes } = props
  const rendererMap = useMarkdownRendererMap()

  return (
    <React.Fragment>
      {nodes.map((node, index) => {
        const key = `${node.type}-${index}`
        const Renderer: INodeRenderer = rendererMap[node.type] ?? rendererMap._fallback
        return <Renderer key={key} {...node} />
      })}
    </React.Fragment>
  )
}
