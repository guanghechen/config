import type { FootnoteDefinition } from '@yozora/ast'
import React from 'react'
import { useMarkdownFootnoteDefinitionMap } from './context'
import { FootnoteDefinitionRenderer } from './renderer/footnoteDefinition'

interface IProps {
  /**
   * If true, then the footnote definitions wont be render.
   */
  dontNeedFootnoteDefinitions?: boolean
}

export const FootnoteDefinitions: React.FC<IProps> = props => {
  const { dontNeedFootnoteDefinitions = false } = props
  const footnoteDefinitionMap: Readonly<Record<string, FootnoteDefinition>> =
    useMarkdownFootnoteDefinitionMap()
  const children = React.useMemo<React.ReactNode>(() => {
    const footnoteDefinitions: ReadonlyArray<FootnoteDefinition> =
      Object.values(footnoteDefinitionMap)
    if (footnoteDefinitions.length <= 0) return null

    return footnoteDefinitions.map(item => (
      <li key={item.identifier}>
        <FootnoteDefinitionRenderer {...item} />
      </li>
    ))
  }, [footnoteDefinitionMap])

  if (dontNeedFootnoteDefinitions || children === null) return null

  return (
    <div className="yozora-footnote-definitions mt-8 mb-4 text-sm">
      <div className="m-0 mb-4 border-b border-gray-300 p-0 italic">
        <a href="#footnote-definitions" title="footnote definitions" rel="noopener, noreferrer">
          <span id="footnote-definitions">footnote-definitions</span>
        </a>
      </div>
      <ul className="m-0 list-none p-0">{children}</ul>
    </div>
  )
}
