import type { ListItem, Node } from '@yozora/ast'
import React from 'react'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render `listItem`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#listitem
 * @see https://www.npmjs.com/package/@yozora/tokenizer-list-item
 */
export class ListItemRenderer extends React.Component<ListItem> {
  public static displayName = 'YozoraListItem'

  public override render(): React.ReactElement {
    const childNodes: Node[] = this.props.children
    return (
      <li className="yozora-list-item relative p-0 m-0">
        <NodesRenderer nodes={childNodes} />
      </li>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<ListItem>): boolean {
    const props = this.props
    return props.children !== nextProps.children
  }
}
