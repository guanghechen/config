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
      <del className="yozora-delete mx-1 rounded px-1 italic text-gray-600 line-through decoration-gray-400 dark:text-gray-200 dark:decoration-gray-500">
        <NodesRenderer nodes={childNodes} />
      </del>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<Delete>): boolean {
    const props = this.props
    return props.children !== nextProps.children
  }
}
