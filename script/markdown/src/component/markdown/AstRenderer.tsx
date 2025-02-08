import type { Root } from '@yozora/ast'
import React from 'react'
import { NodesRenderer } from './NodesRenderer'

export interface IAstRendererProps {
  readonly index: number
  readonly ast: Root
}

export const AstRenderer: React.FC<IAstRendererProps> = props => {
  const { ast } = props
  return <NodesRenderer nodes={ast.children} />
}
