import { css, cx } from '@emotion/css'
import type { Root } from '@yozora/ast'
import React from 'react'
import { astClasses, useMarkdownAst, useMarkdownDarken } from './context'
import { FootnoteDefinitions } from './FootnoteDefinitions'
import { NodesRenderer } from './NodesRenderer'

interface IProps {
  /**
   * Root css class of the component.
   */
  readonly className?: string
  /**
   * Root css style.
   */
  readonly style?: React.CSSProperties
}

export const ReactMarkdown: React.FC<IProps> = props => {
  const { className, style } = props
  const ast: Root = useMarkdownAst()
  const darken: boolean = useMarkdownDarken()
  const cls: string = cx(rootCls, darken && astClasses.rootDarken, className)

  return (
    <div className={cls} style={style}>
      <section>
        <main>
          <NodesRenderer nodes={ast.children} />
        </main>
        <footer>
          <FootnoteDefinitions dontNeedFootnoteDefinitions={false} />
        </footer>
      </section>
    </div>
  )
}
ReactMarkdown.displayName = 'ReactMarkdown'

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
