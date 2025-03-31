import type { IHeadingTocNode } from '@yozora/ast-util'
import cn from 'clsx'
import React from 'react'
import { NodesRenderer } from './NodesRenderer'

interface IProps {
  readonly item: IHeadingTocNode
  readonly depth: number
  readonly activatedIdentifier: string | null
  readonly setAactivatedIdentifier: (identifier: string | null) => void
}

interface IState {
  readonly expanded: boolean
}

export class MarkdownTocItem extends React.Component<IProps, IState> {
  public static displayName: string = 'MarkdownTocItem'

  constructor(props: IProps) {
    super(props)

    const state: IState = { expanded: true }
    this.state = state
  }

  public override render(): React.ReactElement {
    const { item, depth, activatedIdentifier, setAactivatedIdentifier } = this.props
    const { expanded } = this.state
    const { onClick, onToggle } = this

    const hasChildren: boolean = item.children && item.children.length > 0

    return (
      <div className="toc-item">
        <div
          className={cn(
            'flex font-normal items-center py-1 text-sm hover:text-indigo-500 dark:hover:text-indigo-400 cursor-pointer transition-colors',
            {
              'font-medium': depth === 0,
              'text-indigo-600 dark:text-indigo-400 border-l-2 border-indigo-500 dark:border-indigo-400 -ml-[2px] pl-[14px]':
                activatedIdentifier === item.identifier,
            },
          )}
          style={{ paddingLeft: `${depth * 16}px` }}
        >
          {hasChildren && (
            <button
              onClick={onToggle}
              className="mr-1 flex h-5 w-5 items-center justify-center rounded text-gray-500 transition-colors hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
            >
              <svg
                className={cn(
                  'w-3 h-3 transition-transform',
                  expanded ? 'transform rotate-90' : '',
                )}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M9 5l7 7-7 7"
                />
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
                setAactivatedIdentifier={setAactivatedIdentifier}
              />
            ))}
          </div>
        )}
      </div>
    )
  }

  public override shouldComponentUpdate(
    nextProps: Readonly<IProps>,
    nextState: Readonly<IState>,
  ): boolean {
    const state: IState = this.state
    if (state.expanded !== nextState.expanded) return true

    const props: IProps = this.props
    return (
      props.item !== nextProps.item ||
      props.depth !== nextProps.depth ||
      props.activatedIdentifier !== nextProps.activatedIdentifier ||
      props.setAactivatedIdentifier !== nextProps.setAactivatedIdentifier
    )
  }

  protected readonly onClick = (e: React.MouseEvent): void => {
    e.preventDefault()

    const { item, setAactivatedIdentifier } = this.props
    setAactivatedIdentifier(item.identifier)

    let identifier: string = decodeURIComponent(item.identifier)
    identifier = encodeURIComponent(item.identifier)
    const element = document.getElementById(identifier)
    element?.scrollIntoView({ behavior: 'smooth' })
  }

  protected readonly onToggle = (): void => {
    const { item } = this.props
    const hasChildren: boolean = item.children && item.children.length > 0

    if (hasChildren) {
      const { expanded } = this.state
      this.setState({ expanded: !expanded })
    }
  }
}
