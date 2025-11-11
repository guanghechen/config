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

  public override render(): React.ReactElement {
    const childNodes: Node[] = this.props.children
    return (
      <del className="yozora-delete mx-1 italic">
        <span aria-hidden="true" className="yozora-delete__blade" />
        <span className="yozora-delete__content">
          <NodesRenderer nodes={childNodes} />
        </span>
      </del>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<Delete>): boolean {
    const props = this.props
    return props.children !== nextProps.children
  }
}
