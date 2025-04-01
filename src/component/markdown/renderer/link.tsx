import { isEqual } from '@guanghechen/equal'
import type { Link } from '@yozora/ast'
import React from 'react'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render `link`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#link
 * @see https://www.npmjs.com/package/@yozora/tokenizer-link
 * @see https://www.npmjs.com/package/@yozora/tokenizer-autolink
 * @see https://www.npmjs.com/package/@yozora/tokenizer-autolink-extension
 */
export const LinkRenderer: React.FC<Link> = React.memo(
  props => {
    const { title, url, children: childNodes } = props
    const target: React.HTMLAttributeAnchorTarget | undefined = url.startsWith('/')
      ? undefined
      : '_blank'

    return (
      <a
        className="yozora-link py-0.5 px-0 text-sky-600 dark:text-sky-400 italic no-underline hover:text-sky-700 dark:hover:text-sky-300 hover:underline active:text-sky-800 dark:active:text-sky-500 visited:text-purple-600 dark:visited:text-purple-400"
        href={url}
        title={title}
        rel="noopener, noreferrer"
        target={target}
      >
        <NodesRenderer nodes={childNodes} />
      </a>
    )
  },
  (prevProps, nextProps) => {
    return (
      prevProps.title === nextProps.title &&
      prevProps.url === nextProps.url &&
      isEqual(prevProps.children, nextProps.children)
    )
  },
)
LinkRenderer.displayName = 'YozoraLink'
