import type { Blockquote } from '@yozora/ast'
import React from 'react'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render `blockquote`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#blockquote
 * @see https://www.npmjs.com/package/@yozora/tokenizer-blockquote
 */
export class BlockquoteRenderer extends React.Component<Blockquote> {
  public static displayName = 'YozoraBlockquote'

  public override render(): React.ReactElement {
    const childNodes = this.props.children
    return (
      <blockquote className="yozora-blockquote relative box-border rounded-lg mb-6 shadow-sm overflow-hidden border-l-4 transition-all hover:shadow-md dark:shadow-md/20 dark:hover:shadow-lg/20 border-sky-400 dark:border-sky-500 p-0.5">
        <div className="absolute inset-0 opacity-5 dark:opacity-10 bg-gradient-to-br from-sky-400 to-sky-600" />
        <div className="yozora-blockquote__content relative z-10 py-4 px-5 bg-sky-50 dark:bg-sky-900/20 text-sky-800 dark:text-sky-200">
          <NodesRenderer nodes={childNodes} />
        </div>
      </blockquote>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<Blockquote>): boolean {
    const props = this.props
    return props.children !== nextProps.children
  }
}
