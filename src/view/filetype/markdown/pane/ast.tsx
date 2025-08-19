import type { Root } from '@yozora/ast'
import React from 'react'
import { Json } from '@/component/json'
import { useMarkdownAst } from '@/component/markdown'

export const AstPane: React.FC = () => {
  const ast: Root = useMarkdownAst()
  return (
    <div className="flex-auto basis-0">
      <Json json={ast} />
    </div>
  )
}

AstPane.displayName = 'MarkdownViewAstPane'
