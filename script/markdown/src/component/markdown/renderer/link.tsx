import type { Link } from '@yozora/ast';
import React from 'react';
import { astClasses } from '../context';
import { LinkRendererInner } from './inner/LinkRendererInner';

/**
 * Render `link`.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#link
 * @see https://www.npmjs.com/package/@yozora/tokenizer-link
 * @see https://www.npmjs.com/package/@yozora/tokenizer-autolink
 * @see https://www.npmjs.com/package/@yozora/tokenizer-autolink-extension
 */
export const LinkRenderer: React.FC<Link> = (props) => {
  const { title, children: childNodes } = props;
  const url = props.url;

  return (
    <LinkRendererInner
      url={url}
      title={title}
      childNodes={childNodes}
      className={astClasses.link}
    />
  );
};
