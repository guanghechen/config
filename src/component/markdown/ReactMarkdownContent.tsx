import type { Root } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import { useMarkdownViewmodel } from './context'
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

  const viewmodel = useMarkdownViewmodel()
  const ast: Root = React.useMemo<Root>(
    () => viewmodel.parseMarkdown(content),
    [viewmodel, content],
  )

  return (
    <Tag className={cn('yozora-root', className)} style={style}>
      <NodesRenderer nodes={ast.children} />
    </Tag>
  )
}
ReactMarkdownContent.displayName = 'ReactMarkdownContent'
