import type { ListItem, Node } from '@yozora/ast'
import { TaskStatus } from '@yozora/ast'
import cn from 'clsx'
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
    const status = 'status' in this.props ? (this.props.status as TaskStatus) : null

    return (
      <li className={cn('yozora-list-item relative p-0 m-0', status && 'yozora-list-item--task')}>
        {status && (
          <span className="yozora-list-item__checkbox mr-2">
            {status === TaskStatus.DONE ? (
              <input title="task status" type="checkbox" checked={true} readOnly={true} />
            ) : status === TaskStatus.DOING ? (
              <input
                title="task status"
                type="checkbox"
                className="checkbox-doing"
                checked={true}
                readOnly={true}
              />
            ) : (
              <input
                title="task status"
                type="checkbox"
                readOnly={true}
                onClick={e => e.preventDefault()}
              />
            )}
          </span>
        )}
        <NodesRenderer nodes={childNodes} />
      </li>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<ListItem>): boolean {
    const props = this.props
    return props.children !== nextProps.children || props.status !== nextProps.status
  }
}
