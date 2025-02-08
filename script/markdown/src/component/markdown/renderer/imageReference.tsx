import { useComputed } from '@guanghechen/react-viewmodel'
import type { Definition, ImageReference } from '@yozora/ast'
import React from 'react'
import { isLocalUrl, resolveLocalResourceSrc } from '@/util/url'
import type { INodeRenderer } from '../context'
import { astClasses, useNodeRendererContext } from '../context'
import { ImageRendererInner } from './inner/ImageRendererInner'

/**
 * Render `imageReference`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#imageReference
 * @see https://www.npmjs.com/package/@yozora/tokenizer-image-reference
 */
export const ImageReferenceRenderer: INodeRenderer<ImageReference> = props => {
  const { viewmodel } = useNodeRendererContext()
  const definitionMap: Readonly<Record<string, Definition>> = useComputed(viewmodel.definitionMap$)
  const { alt, srcSet, sizes, loading } = props as ImageReference &
    React.ImgHTMLAttributes<HTMLElement>

  const definition = definitionMap[props.identifier]
  const title: string | undefined = definition?.title
  const url: string = definition?.url ?? ''

  const src: string = isLocalUrl(url)
    ? resolveLocalResourceSrc(url, viewmodel.filepath$.getSnapshot())
    : url

  return (
    <ImageRendererInner
      alt={alt}
      src={src || ''}
      title={title}
      srcSet={srcSet}
      sizes={sizes}
      loading={loading}
      className={astClasses.imageReference}
    />
  )
}
