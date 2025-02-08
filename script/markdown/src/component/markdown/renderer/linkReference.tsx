import { useComputed } from '@guanghechen/react-viewmodel'
import type { Definition, LinkReference } from '@yozora/ast'
import React from 'react'
import { isLocalUrl, resolveLocalMarkdownLink } from '@/util/url'
import { astClasses, useNodeRendererContext } from '../context'
import { LinkRendererInner } from './inner/LinkRendererInner'

/**
 * Render `link-reference`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#linkReference
 * @see https://www.npmjs.com/package/@yozora/tokenizer-link-reference
 */
export const LinkReferenceRenderer: React.FC<LinkReference> = props => {
  const { viewmodel } = useNodeRendererContext()
  const definitionMap: Readonly<Record<string, Definition>> = useComputed(viewmodel.definitionMap$)
  const definition = definitionMap[props.identifier]
  const title: string | undefined = definition?.title
  const url: string = definition?.url ?? ''

  const src: string = isLocalUrl(url)
    ? resolveLocalMarkdownLink(url, viewmodel.filepath$.getSnapshot())
    : url
  const target: React.HTMLAttributeAnchorTarget | undefined = src === url ? '_blank' : undefined

  return (
    <LinkRendererInner
      target={target}
      title={title}
      url={src}
      childNodes={props.children}
      className={astClasses.linkReference}
    />
  )
}
