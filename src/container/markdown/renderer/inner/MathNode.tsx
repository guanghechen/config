import React from 'react'
import {
  MathError,
  MathJaxContextType,
  MathJaxNode,
  MathJaxNodeWithoutContext,
} from '@yozora/react-mathjax'

const MathFailure: React.FC<React.ComponentProps<typeof MathError>> = props => {
  const Tag = props.inline ? 'span' : 'div'
  return (
    <Tag role="alert">
      <MathError {...props} />
    </Tag>
  )
}

// Keep render failures identifiable by accessibility clients and whiteboard exports.
export const MathNode: React.FC<React.ComponentProps<typeof MathJaxNode>> = props => {
  const { MathJax, language } = React.useContext(MathJaxContextType)
  return MathJax ? (
    <MathJaxNodeWithoutContext
      {...props}
      formula={props.formula.trim()}
      inline={props.inline ?? false}
      MathJax={MathJax}
      language={language}
      MathErrorRenderer={MathFailure}
    />
  ) : (
    <MathJaxNode {...props} />
  )
}
