import type { ImageReference } from '@yozora/ast'
import React from 'react'
import { useMarkdownDefinitionMap } from '../context'
import type { INodeRenderer } from '../types'
import { ImageRendererInner } from './inner/ImageRendererInner'

/**
 * Render `imageReference`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#imageReference
 * @see https://www.npmjs.com/package/@yozora/tokenizer-image-reference
 */
export const ImageReferenceRenderer: INodeRenderer<ImageReference> = props => {
  const definitionMap = useMarkdownDefinitionMap()
  const { identifier, alt, srcSet, sizes, loading } = props as ImageReference &
    React.ImgHTMLAttributes<HTMLElement>

  const definition = definitionMap[identifier]
  const title: string | undefined = definition?.title
  const url: string = definition?.url ?? ''

  return (
    <ImageRendererInner
      alt={alt}
      src={url || ''}
      title={title}
      srcSet={srcSet}
      sizes={sizes}
      loading={loading}
      className="yozora-image-reference"
    />
  )
}
ImageReferenceRenderer.displayName = 'YozoraImageReference'
