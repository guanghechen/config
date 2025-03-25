import type { Link } from '@yozora/ast'
import React from 'react'
import { astClasses } from '../context'
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
  const target: React.HTMLAttributeAnchorTarget | undefined = url.startsWith('/')
    ? undefined
    : '_blank'

  return (
    <LinkRendererInner
      target={target}
      title={title}
      url={url}
      childNodes={childNodes}
      className={astClasses.link}
    />
  )
}
LinkRenderer.displayName = 'YozoraLink'
