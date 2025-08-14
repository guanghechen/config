import { isEqual } from '@guanghechen/equal'
import type { Heading, Node, Root } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import { MarkdownContentProvider } from './context/content'
import { FootnoteDefinitions } from './FootnoteDefinitions'
import { NodesRenderer } from './NodesRenderer'

interface IProps {
  /**
   * Markdown ast
   */
  readonly ast: Root
  /**
   * Whether to hide the first heading in the document
   */
  readonly dontShowFirstHeading: boolean
  /**
   * Root css class of the component.
   */
  readonly className?: string
  /**
   * Root css style.
   */
  readonly style?: React.CSSProperties
}

export class ReactMarkdown extends React.Component<IProps> {
  public override render(): React.ReactElement {
    const { ast, dontShowFirstHeading, className, style } = this.props
    const childNodes: Node[] =
      dontShowFirstHeading &&
      ast.children[0].type === 'heading' &&
      (ast.children[0] as Heading).depth === 1
        ? ast.children.slice(1)
        : ast.children

    return (
      <MarkdownContentProvider ast={ast}>
        <div className={cn('yozora-root', className)} style={style}>
          <section>
            <main>
              <NodesRenderer nodes={childNodes} />
            </main>
            <footer>
              <FootnoteDefinitions dontNeedFootnoteDefinitions={false} />
            </footer>
          </section>
        </div>
      </MarkdownContentProvider>
    )
  }

  public shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props: IProps = this.props
    return (
      props.className !== nextProps.className ||
      props.style !== nextProps.style ||
      props.dontShowFirstHeading !== nextProps.dontShowFirstHeading ||
      !isEqual(props.ast, nextProps.ast)
    )
  }
}
