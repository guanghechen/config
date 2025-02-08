import type { Image } from '@yozora/ast'
import React from 'react'
import { fetchFile } from '@/util/fetch'
import { isLocalUrl } from '@/util/url'
import type { INodeRenderer } from '../context'
import { astClasses, useNodeRendererContext } from '../context'
import { ImageRendererInner } from './inner/ImageRendererInner'

/**
 * Render `image`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#image
 * @see https://www.npmjs.com/package/@yozora/tokenizer-image
 */
export const ImageRenderer: INodeRenderer<Image> = props => {
  const { url, alt, title, srcSet, sizes, loading } = props as Image &
    React.ImgHTMLAttributes<HTMLElement>

  const { viewmodel } = useNodeRendererContext()
  const [src, setSrc] = React.useState<string | undefined>(isLocalUrl(url) ? url : '')
  React.useEffect(() => {
    let cancelled = false
    async function handle(): Promise<void> {
      if (isLocalUrl(url)) {
        const result = await fetchFile(url, viewmodel.filepath$.getSnapshot())
        if (cancelled) return
        if (result.url) setSrc(result.url)
      }
    }
    void handle()

    return () => {
      cancelled = true
    }
  }, [url])

  return (
    <ImageRendererInner
      alt={alt}
      src={src || ''}
      title={title}
      srcSet={srcSet}
      sizes={sizes}
      loading={loading}
      className={astClasses.image}
    />
  )
}
