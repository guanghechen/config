import { isEqual } from '@guanghechen/equal'
import type { Link } from '@yozora/ast'
import React from 'react'
import { useMarkdownLinkClick, useMarkdownResolveLinkUrl } from '../context/top'
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
    const onLinkClick = useMarkdownLinkClick()
    const resolveLinkUrl = useMarkdownResolveLinkUrl()
    const resolvedUrl = resolveLinkUrl(url)
    const target: React.HTMLAttributeAnchorTarget | undefined =
      resolvedUrl.startsWith('/') || resolvedUrl.startsWith('#') ? undefined : '_blank'

    return (
      <a
        className="yozora-link py-0.5 px-0 text-blue-700 dark:text-blue-400 font-medium border-b border-blue-300 dark:border-blue-500/50 hover:text-blue-800 dark:hover:text-blue-300 hover:border-b-2 hover:border-blue-500 dark:hover:border-blue-400 active:text-blue-900 dark:active:text-blue-200 visited:text-violet-700 dark:visited:text-violet-400 visited:border-violet-300 dark:visited:border-violet-500/50"
        href={resolvedUrl}
        onClick={onLinkClick}
        title={title}
        rel={target ? 'noopener noreferrer' : undefined}
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
