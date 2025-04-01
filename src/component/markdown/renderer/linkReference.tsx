import { isEqual } from '@guanghechen/equal'
import type { LinkReference } from '@yozora/ast'
import React from 'react'
import { useMarkdownDefinitionMap } from '../context'
import { NodesRenderer } from '../NodesRenderer'

/**
 * Render `link-reference`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#linkReference
 * @see https://www.npmjs.com/package/@yozora/tokenizer-link-reference
 */
export const LinkReferenceRenderer: React.FC<LinkReference> = React.memo(
  props => {
    const { identifier, children: childNodes } = props
    const definitionMap = useMarkdownDefinitionMap()
    const definition = definitionMap[identifier]
    const title: string | undefined = definition?.title
    const url: string = definition?.url ?? ''
    const target: React.HTMLAttributeAnchorTarget | undefined = url.startsWith('/')
      ? undefined
      : '_blank'

    return (
      <a
        className="yozora-link-reference py-0.5 px-0 text-sky-600 dark:text-sky-400 italic no-underline hover:text-sky-700 dark:hover:text-sky-300 hover:underline active:text-sky-800 dark:active:text-sky-500 visited:text-purple-600 dark:visited:text-purple-400"
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
      prevProps.identifier === nextProps.identifier &&
      isEqual(prevProps.children, nextProps.children)
    )
  },
)
LinkReferenceRenderer.displayName = 'YozoraLinkReference'
