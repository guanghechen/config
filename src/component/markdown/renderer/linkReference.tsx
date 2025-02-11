import { useComputed } from '@guanghechen/react-viewmodel'
import type { Definition, LinkReference } from '@yozora/ast'
import React from 'react'
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
