import React from 'react';
import { extractLiteralTexts } from './util';

export interface IReactMarkdownLiteralProps {
  text: string | string[];
  className?: string;
}

export const ReactMarkdownLiteral: React.FC<IReactMarkdownLiteralProps> = (
  props,
) => {
  const { text, className } = props;
  const literalTexts = React.useMemo(() => extractLiteralTexts(text), [text]);
  return <p className={className}>{literalTexts}</p>;
};
