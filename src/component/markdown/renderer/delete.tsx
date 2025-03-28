import type { Delete, Node } from '@yozora/ast'
import React from 'react'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render `delete`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#delete
 * @see https://www.npmjs.com/package/@yozora/tokenizer-delete
 */
export class DeleteRenderer extends React.Component<Delete> {
  public static displayName = 'YozoraDelete'

  public override shouldComponentUpdate(nextProps: Readonly<Delete>): boolean {
    const props = this.props
    return props.children !== nextProps.children
  }

  public override render(): React.ReactElement {
    const childNodes: Node[] = this.props.children
    return (
      <del className="yozora-delete mx-1 italic text-slate-400 line-through">
        <NodesRenderer nodes={childNodes} />
      </del>
    )
  }
}
