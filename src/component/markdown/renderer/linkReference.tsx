import type { LinkReference } from '@yozora/ast'
import React from 'react'
import { astClasses, useMarkdownDefinitionMap } from '../context'
import { LinkRendererInner } from './inner/LinkRendererInner'

/**
 * Render `link-reference`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#linkReference
 * @see https://www.npmjs.com/package/@yozora/tokenizer-link-reference
 */
export const LinkReferenceRenderer: React.FC<LinkReference> = props => {
  const definitionMap = useMarkdownDefinitionMap()
  const definition = definitionMap[props.identifier]
  const title: string | undefined = definition?.title
  const url: string = definition?.url ?? ''
  const target: React.HTMLAttributeAnchorTarget | undefined = url.startsWith('/')
    ? undefined
    : '_blank'

  return (
    <LinkRendererInner
      target={target}
      title={title}
      url={url}
      childNodes={props.children}
      className={astClasses.linkReference}
    />
  )
}
LinkReferenceRenderer.displayName = 'YozoraLinkReference'
