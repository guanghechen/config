import type { ListItem, Node } from '@yozora/ast'
import { TaskStatus } from '@yozora/ast'
import React from 'react'
import { NodesRenderer } from '../NodesRenderer'
import { isBlockNode } from '../util'

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
    const status = (this.props.status as TaskStatus) ?? null

    let firstBlockNodeIndex: number = childNodes.length
    for (let i = 0; i < childNodes.length; i++) {
      if (isBlockNode(childNodes[i])) {
        firstBlockNodeIndex = i
        break
      }
    }

    if (status) {
      return (
        <li className="yozora-list-item relative p-0 m-0 yozora-list-item--task">
          <div className="p-0 leading-[1.8] flex items-start hyphens-auto break-normal anywhere [&>:last-child]:mb-0">
            <span className="yozora-list-item__checkbox mr-2 middle">
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
            {firstBlockNodeIndex > 0 && (
              <NodesRenderer nodes={childNodes} endIndex={firstBlockNodeIndex} />
            )}
          </div>
          {firstBlockNodeIndex < childNodes.length && (
            <NodesRenderer nodes={childNodes} startIndex={firstBlockNodeIndex} />
          )}
        </li>
      )
    }

    return (
      <li className="yozora-list-item relative p-0 m-0">
        {firstBlockNodeIndex > 0 && (
          <div className="p-0 leading-[1.8] hyphens-auto break-normal anywhere [&>:last-child]:mb-0">
            <NodesRenderer nodes={childNodes} endIndex={firstBlockNodeIndex} />
          </div>
        )}
        {firstBlockNodeIndex < childNodes.length && (
          <NodesRenderer nodes={childNodes} startIndex={firstBlockNodeIndex} />
        )}
      </li>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<ListItem>): boolean {
    const props = this.props
    return props.children !== nextProps.children || props.status !== nextProps.status
  }
}
