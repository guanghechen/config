import type { Emphasis, Node } from '@yozora/ast'
import React from 'react'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render `emphasis`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#emphasis
 * @see https://www.npmjs.com/package/@yozora/tokenizer-emphasis
 */
export class EmphasisRenderer extends React.Component<Emphasis> {
  public static displayName = 'YozoraEmphasis'

  public override shouldComponentUpdate(nextProps: Readonly<Emphasis>): boolean {
    const props = this.props
    return props.children !== nextProps.children
  }

  public override render(): React.ReactElement {
    const childNodes: Node[] = this.props.children
    return (
      <em className="yozora-emphasis ml-1 mr-2 italic">
        <NodesRenderer nodes={childNodes} />
      </em>
    )
  }
}
