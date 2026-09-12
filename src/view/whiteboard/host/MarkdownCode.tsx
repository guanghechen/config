import type { Code } from '@yozora/ast'
import React from 'react'
import { CodeRenderer } from '@/container/markdown/renderer/code'

// Diagrams are visible by default on the board; explicit code metadata keeps its existing meaning.
export const MarkdownCode: React.FC<Code> = props => (
  <CodeRenderer {...props} meta={props.lang === 'mermaid' && !props.meta ? 'embed' : props.meta} />
)
