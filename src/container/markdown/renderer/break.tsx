import type { Break } from '@yozora/ast'
import React from 'react'

/**
 * Render `break`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#break
 * @see https://www.npmjs.com/package/@yozora/tokenizer-break
 */
export class BreakRenderer extends React.Component<Break> {
  public static displayName = 'YozoraBreak'

  public override render(): React.ReactElement {
    return <br className="yozora-break box-border" />
  }

  public override shouldComponentUpdate(): boolean {
    return false
  }
}
