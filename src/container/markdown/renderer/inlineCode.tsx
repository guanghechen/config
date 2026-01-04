import type { InlineCode } from '@yozora/ast'
import React from 'react'

/**
 * Render `inline-code`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#inlinecode
 * @see https://www.npmjs.com/package/@yozora/tokenizer-inline-code
 */
export class InlineCodeRenderer extends React.Component<InlineCode> {
  public static displayName = 'YozoraInlineCode'

  public override render(): React.ReactElement {
    return (
      <code className="yozora-inline-code m-0 rounded bg-slate-300/15 p-1 font-mono text-[min(1rem,18px)] font-medium leading-tight text-rose-500 dark:bg-slate-600/25 dark:text-rose-400">
        {this.props.value}
      </code>
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<InlineCode>): boolean {
    const props = this.props
    return props.value !== nextProps.value
  }
}
