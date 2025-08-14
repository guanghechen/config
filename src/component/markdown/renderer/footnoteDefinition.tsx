import type { FootnoteDefinition } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import { useFootnoteHighlighting } from '../hook/useFootnoteHighlighting'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render footnote definition
 *
 * @see https://www.npmjs.com/package/@yozora/ast#footnote
 * @see https://www.npmjs.com/package/@yozora/ast#footnoteReference
 * @see https://www.npmjs.com/package/@yozora/ast#footnoteDefinition
 * @see https://www.npmjs.com/package/@yozora/tokenizer-footnote
 * @see https://www.npmjs.com/package/@yozora/tokenizer-footnote-reference
 * @see https://www.npmjs.com/package/@yozora/tokenizer-footnote-definition
 */
export const FootnoteDefinitionRenderer: React.FC<FootnoteDefinition> = props => {
  const { identifier, label = identifier, children } = props
  const refid: string = 'footnote-reference-' + identifier
  const defid: string = 'footnote-definition-' + identifier

  const ref = React.useRef<HTMLDivElement | null>(null)
  const highlighting = useFootnoteHighlighting(ref, defid)

  return (
    <div
      ref={ref}
      className="yozora-footnote-definition flex items-start justify-start w-full p-0 m-0"
    >
      <p id={defid} className="inline-block flex-initial flex-shrink-0 select-none">
        <a
          href={'#' + refid}
          className={cn(
            'inline-block px-1 text-[10px] tracking-[1px] text-fuchsia-500 no-underline hover:text-fuchsia-600 active:text-fuchsia-700',
            highlighting && 'bg-fuchsia-300 rounded-md animate-pulse px-1 font-bold text-black',
          )}
        >
          <span>&uarr;&nbsp;[{label}]</span>
        </a>
        <span>:&nbsp;</span>
      </p>
      <div className="m-0 inline-block flex-1 overflow-x-auto p-0">
        <NodesRenderer nodes={children} />
      </div>
    </div>
  )
}
FootnoteDefinitionRenderer.displayName = 'YozoraFootnoteDefinition'
