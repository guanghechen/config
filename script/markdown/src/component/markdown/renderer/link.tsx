import type { Link } from '@yozora/ast'
import React from 'react'
import { isLocalUrl, resolveLocalMarkdownLink } from '@/util/url'
import { astClasses, useNodeRendererContext } from '../context'
import { LinkRendererInner } from './inner/LinkRendererInner'

/**
 * Render `link`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#link
 * @see https://www.npmjs.com/package/@yozora/tokenizer-link
 * @see https://www.npmjs.com/package/@yozora/tokenizer-autolink
 * @see https://www.npmjs.com/package/@yozora/tokenizer-autolink-extension
 */
export const LinkRenderer: React.FC<Link> = props => {
  const { title, url, children: childNodes } = props
  const { viewmodel } = useNodeRendererContext()

  const src: string = isLocalUrl(url)
    ? resolveLocalMarkdownLink(url, viewmodel.filepath$.getSnapshot())
    : url
  const target: React.HTMLAttributeAnchorTarget | undefined = src === url ? '_blank' : undefined

  return (
    <LinkRendererInner
      target={target}
      title={title}
      url={src}
      childNodes={childNodes}
      className={astClasses.link}
    />
  )
}
