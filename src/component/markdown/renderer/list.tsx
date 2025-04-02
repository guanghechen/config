import type { List } from '@yozora/ast'
import React from 'react'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render `list`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#list
 * @see https://www.npmjs.com/package/@yozora/tokenizer-list
 */
export class ListRenderer extends React.Component<List> {
  public static displayName = 'YozoraList'

  public override render(): React.ReactElement {
    const { ordered, orderType, start, children } = this.props

    if (ordered) {
      return (
        <ol
          className="yozora-list yozora-list-order list-outside list-decimal p-0 m-0 mb-4 ml-8"
          type={orderType}
          start={start}
        >
          <NodesRenderer nodes={children} />
        </ol>
      )
    }

    return (
      <ul className="yozora-list yozora-list-bullet list-outside list-disc p-0 m-0 mb-4 ml-8">
        <NodesRenderer nodes={children} />
      </ul>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<List>): boolean {
    const props = this.props
    return (
      props.ordered !== nextProps.ordered ||
      props.orderType !== nextProps.orderType ||
      props.start !== nextProps.start ||
      props.children !== nextProps.children
    )
  }
}
