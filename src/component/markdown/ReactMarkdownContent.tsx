import type { Root } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import { MarkdownContentProvider } from './context/content'
import { useMarkdownTopViewmodel } from './context/top'
import { NodesRenderer } from './NodesRenderer'

interface IProps {
  readonly Tag?: React.ElementType
  /**
   * Markdown content.
   */
  readonly content: string
  /**
   * Root css class of the component.
   */
  readonly className?: string
  /**
   * Root css style.
   */
  readonly style?: React.CSSProperties
}

export const ReactMarkdownContent: React.FC<IProps> = props => {
  const { Tag = 'div', content, className, style } = props

  const top = useMarkdownTopViewmodel()
  const ast: Root = React.useMemo<Root>(() => top.parseMarkdown(content), [top, content])

  return (
    <MarkdownContentProvider ast={ast}>
      <Tag className={cn('yozora-root', className)} style={style}>
        <NodesRenderer nodes={ast.children} />
      </Tag>
    </MarkdownContentProvider>
  )
}
ReactMarkdownContent.displayName = 'ReactMarkdownContent'
