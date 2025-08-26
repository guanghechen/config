import type { FootnoteReference } from '@yozora/ast'
import cn from 'clsx'
import React from 'react'
import { useFootnoteHighlighting } from '../hook/useFootnoteHighlighting'

/**
 * Render yozora `footnoteReference`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#footnotereference
 * @see https://www.npmjs.com/package/@yozora/tokenizer-footnote
 * @see https://www.npmjs.com/package/@yozora/tokenizer-footnote-definition
 * @see https://www.npmjs.com/package/@yozora/tokenizer-footnote-reference
 */
export const FootnoteReferenceRenderer: React.FC<FootnoteReference> = props => {
  const { identifier, label } = props
  const refid: string = 'footnote-reference-' + identifier
  const defid: string = 'footnote-definition-' + identifier

  const ref = React.useRef<HTMLElement | null>(null)
  const highlighting = useFootnoteHighlighting(ref, refid)

  return (
    <sup
      ref={ref}
      id={refid}
      className={cn(
        'yozora-footnote-reference',
        highlighting &&
          'bg-fuchsia-300 rounded-md animate-pulse px-1 font-bold text-black dark:bg-fuchsia-600 dark:text-white',
      )}
    >
      <a
        href={'#' + defid}
        title={label}
        className="inline-block px-1 text-[10px] tracking-[1px] text-fuchsia-500 no-underline hover:text-fuchsia-600 active:text-fuchsia-700 dark:text-fuchsia-400 dark:hover:text-fuchsia-300 dark:active:text-fuchsia-200"
      >
        {label}
      </a>
    </sup>
  )
}
FootnoteReferenceRenderer.displayName = 'YozoraFootnoteReference'
