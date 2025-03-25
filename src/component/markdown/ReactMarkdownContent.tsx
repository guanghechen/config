import { css, cx } from '@emotion/css'
import type { Root } from '@yozora/ast'
import React from 'react'
import { astClasses, useMarkdownDarken, useMarkdownViewmodel } from './context'
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
  const darken: boolean = useMarkdownDarken()
  const cls: string = cx(rootCls, darken && astClasses.rootDarken, className)

  const ast: Root = React.useMemo<Root>(
    () => viewmodel.parseMarkdown(content),
    [viewmodel, content],
  )

  return (
    <Tag className={cls} style={style}>
      <NodesRenderer nodes={ast.children} />
    </Tag>
  )
}
ReactMarkdownContent.displayName = 'ReactMarkdownContent'

const rootCls = cx(
  astClasses.root,
  css({
    wordBreak: 'break-all',
    userSelect: 'unset',
    fontFamily: "'Maple Mono NF CN', 'Roboto Mono', monospace, sans-serif",
    [astClasses.listItem]: {
      [`> ${astClasses.list}`]: {
        marginLeft: '1.2em',
      },
    },
    '> :last-child': {
      marginBottom: 0,
    },
  }),
)
