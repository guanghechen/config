import type { ThematicBreak } from '@yozora/ast'
import React from 'react'

/**
 * Render `thematicBreak`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#thematicBreak
 * @see https://www.npmjs.com/package/@yozora/tokenizer-thematic-break
 */
export class ThematicBreakRenderer extends React.Component<ThematicBreak> {
  public static displayName = 'YozoraThematicBreak'

  public override shouldComponentUpdate(): boolean {
    return false
  }

  public override render(): React.ReactElement {
    return (
      <hr className="yozora-thematic-break my-4 box-content block h-0 w-full border-0 border-b border-gray-300 p-0 outline-none" />
    )
  }
}
