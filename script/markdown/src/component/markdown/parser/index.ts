import type { Association, Paragraph, Root } from '@yozora/ast';
import { ParagraphType, RootType, TextType } from '@yozora/ast';
import Parser from '@yozora/parser';
import AdmonitionTokenizer from '@yozora/tokenizer-admonition';
import InlineMathTokenizer from '@yozora/tokenizer-inline-math';
import MathTokenizer from '@yozora/tokenizer-math';

interface IParseOptions {
  /**
   * Whether it is necessary to reserve the position in the Node produced.
   */
  readonly shouldReservePosition?: boolean;
  /**
   * Preset definition meta data list.
   */
  readonly presetDefinitions?: Association[];
  /**
   * Preset footnote definition meta data list.
   */
  readonly presetFootnoteDefinitions?: Association[];
  /**
   * Format url.
   * @param url
   * @returns
   */
  readonly formatUrl?: (url: string) => string;
}

const parser = new Parser({
  defaultParseOptions: {
    shouldReservePosition: false,
  },
})
  .useTokenizer(new AdmonitionTokenizer())
  .useTokenizer(new MathTokenizer())
  .useTokenizer(new InlineMathTokenizer({ backtickRequired: false }));

export const countChar = (text: string, char: string): number => {
  let count: number = 0;
  for (const c of text) {
    if (char === c) count += 1;
  }
  return count;
};

export const parseMarkdown = (text: string, options?: IParseOptions): Root => {
  try {
    const ast: Root = parser.parse(text, options);
    return ast;
  } catch (error) {
    console.error('[Failed to parse markdown]', text, error);

    const ast = {
      type: RootType,
      children: [
        {
          type: ParagraphType,
          children: [
            {
              type: TextType,
              value: text,
            },
          ],
        },
      ],
    };
    return ast as any as Root;
  }
};

export const hasHighlightContent = (content: string): boolean => {
  const data: Root = parser.parse(content);
  if (data.children.length === 0) return false;
  for (const node of data.children) {
    if (node.type !== ParagraphType) return true;

    const paragraph = node as Paragraph;
    if (paragraph.children.some((v) => v.type !== TextType)) return true;
  }
  return false;
};
