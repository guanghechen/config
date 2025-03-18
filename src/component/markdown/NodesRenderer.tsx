import equals from '@guanghechen/equal'
import type { Node } from '@yozora/ast'
import React from 'react'
import type { INodeRenderer } from './context'
import { useMarkdownRendererMap } from './context'

export interface INodesRendererProps {
  /**
   * Ast nodes.
   */
  readonly nodes: Node[]
}

export const NodesRenderer: React.FC<INodesRendererProps> = props => {
  const { nodes } = props
  const rendererMap = useMarkdownRendererMap()

  return (
    <React.Fragment>
      {nodes.map((node, index) => {
        const key = `${node.type}-${index}`
        const Renderer: INodeRenderer = rendererMap[node.type] ?? rendererMap._fallback
        return <NodeRenderer key={key} node={node} Renderer={Renderer} />
      })}
    </React.Fragment>
  )
}

interface IProps {
  readonly node: Node
  readonly Renderer: INodeRenderer
}

class NodeRenderer extends React.Component<IProps> {
  public override shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props = this.props
    return props.Renderer !== nextProps.Renderer || !equals(props.node, nextProps.node)
  }

  public override render(): React.ReactElement {
    const { node, Renderer } = this.props
    return React.createElement(Renderer, node)
  }
}
