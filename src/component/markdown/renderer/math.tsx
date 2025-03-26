import type { Math } from '@yozora/ast'
import { MathJaxNode } from '@yozora/react-mathjax'
import cn from 'clsx'
import React from 'react'
import { astClasses } from '../context'

/**
 * Render yozora `math`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#math
 * @see https://www.npmjs.com/package/@yozora/tokenizer-math
 */
export class MathRenderer extends React.Component<Math> {
  public static displayName = 'YozoraMath'

  public override shouldComponentUpdate(nextProps: Readonly<Math>): boolean {
    const props = this.props
    return props.value !== nextProps.value
  }

  public override render(): React.ReactElement {
    return (
      <MathJaxNode
        className={cn(astClasses.math, 'text-blue-300')}
        inline={false}
        formula={this.props.value}
      />
    )
  }
}
