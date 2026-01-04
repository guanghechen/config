import { MathJaxNode } from '@yozora/react-mathjax'
import React from 'react'

interface IProps {
  readonly code: string
}

class Math extends React.Component<IProps> {
  public static displayName = 'CodeRendererMath'

  public override render(): React.ReactElement {
    const { code } = this.props
    return (
      <MathJaxNode
        className="yozora-math"
        style={{ color: 'var(--color-math)' }}
        inline={false}
        formula={code}
      />
    )
  }

  public override shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props = this.props
    return props.code !== nextProps.code
  }
}

export default Math
