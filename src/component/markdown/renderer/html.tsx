import type { Html } from '@yozora/ast'
import React from 'react'

/**
 * Render `html` as text with styling to indicate it's HTML content.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#html
 * @see https://www.npmjs.com/package/@yozora/tokenizer-html
 */
export class HtmlRenderer extends React.Component<Html> {
  public override shouldComponentUpdate(nextProperties: Readonly<Html>): boolean {
    const properties = this.props
    return properties.value !== nextProperties.value
  }

  public override render(): React.ReactElement {
    return (
      <div className="yozora-html box-border mb-5 border border-gray-300 rounded bg-gray-100 overflow-hidden">
        <div className="px-2 py-0.5 bg-gray-300 text-gray-600 text-xs font-bold inline-block">
          HTML
        </div>
        <pre className="m-2 p-2 overflow-x-auto font-mono text-sm leading-relaxed whitespace-pre-wrap break-all">
          {this.props.value}
        </pre>
      </div>
    )
  }
}
