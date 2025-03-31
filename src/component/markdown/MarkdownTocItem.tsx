import type { IHeadingTocNode } from '@yozora/ast-util'
import cn from 'clsx'
import React from 'react'
import { NodesRenderer } from './NodesRenderer'

interface IProps {
  readonly item: IHeadingTocNode
  readonly depth: number
  readonly activatedIdentifier: string | null
}

export const MarkdownTocItem: React.FC<IProps> = props => {
  const { item, depth, activatedIdentifier } = props
  const [expanded, setExpanded] = React.useState<boolean>(true)
  const hasChildren: boolean = item.children && item.children.length > 0

  const onToggle = React.useCallback(() => {
    if (hasChildren) {
      setExpanded(prev => !prev)
    }
  }, [hasChildren])

  const onClick = React.useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault()
      let identifier: string = decodeURIComponent(item.identifier)
      identifier = encodeURIComponent(item.identifier)
      const element = document.getElementById(identifier)
      element?.scrollIntoView({ behavior: 'smooth' })
    },
    [item.identifier],
  )

  return (
    <div
      className={cn('toc-item', {
        '': activatedIdentifier === item.identifier,
      })}
    >
      <div
        className={cn(
          'flex items-center py-1 text-sm hover:text-indigo-500 dark:hover:text-indigo-400 cursor-pointer transition-colors',
          depth === 0 ? 'font-medium' : 'font-normal',
        )}
        style={{ paddingLeft: `${depth * 16}px` }}
      >
        {hasChildren && (
          <button
            onClick={onToggle}
            className="mr-1 flex h-5 w-5 items-center justify-center rounded text-gray-500 transition-colors hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
          >
            <svg
              className={cn('w-3 h-3 transition-transform', expanded ? 'transform rotate-90' : '')}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </button>
        )}
        {!hasChildren && <div className="w-5" />}
        <a href={`#${item.identifier}`} onClick={onClick} className="truncate hover:underline">
          <NodesRenderer nodes={item.contents} />
        </a>
      </div>
      {hasChildren && expanded && (
        <div className="toc-children">
          {item.children?.map(child => (
            <MarkdownTocItem
              key={child.identifier}
              item={child}
              depth={depth + 1}
              activatedIdentifier={activatedIdentifier}
            />
          ))}
        </div>
      )}
    </div>
  )
}
MarkdownTocItem.displayName = 'MarkdownTocItem'
