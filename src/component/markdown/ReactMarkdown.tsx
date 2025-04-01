import type { Root } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import { useMarkdownAst } from './context'
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
  const { style, className } = props
  const ast: Root = useMarkdownAst()

  return (
    <div className={cn('yozora-root', className)} style={style}>
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
