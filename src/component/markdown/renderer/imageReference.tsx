import type { ImageReference } from '@yozora/ast'
import React from 'react'
import type { INodeRenderer } from '../context'
import { astClasses, useMarkdownDefinitionMap } from '../context'
import { ImageRendererInner } from './inner/ImageRendererInner'

/**
 * Render `imageReference`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#imageReference
 * @see https://www.npmjs.com/package/@yozora/tokenizer-image-reference
 */
export const ImageReferenceRenderer: INodeRenderer<ImageReference> = props => {
  const definitionMap = useMarkdownDefinitionMap()
  const { alt, srcSet, sizes, loading } = props as ImageReference &
    React.ImgHTMLAttributes<HTMLElement>

  const definition = definitionMap[props.identifier]
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
      className={astClasses.imageReference}
    />
  )
}
ImageReferenceRenderer.displayName = 'YozoraImageReference'
