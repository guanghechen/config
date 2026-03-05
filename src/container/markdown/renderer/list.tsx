import type { List } from '@yozora/ast'
import React from 'react'
import { NodesRenderer } from '../NodesRenderer'

function resolveListStyleType(orderType: List['orderType']): React.CSSProperties['listStyleType'] {
  switch (orderType) {
    case 'A':
      return 'upper-alpha'
    case 'a':
      return 'lower-alpha'
    case 'I':
      return 'upper-roman'
    case 'i':
      return 'lower-roman'
    case '1':
    default:
      return 'decimal'
  }
}

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
      const listStyleType = resolveListStyleType(orderType)

      return (
        <ol
          className="yozora-list yozora-list-order list-outside p-0 m-0 mb-4 pl-4"
          style={{ listStyleType }}
          type={orderType}
          start={start}
        >
          <NodesRenderer nodes={children} />
        </ol>
      )
    }

    return (
      <ul className="yozora-list yozora-list-bullet list-outside list-disc p-0 m-0 mb-4 pl-4">
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
