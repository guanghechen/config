import type { Association, Root } from '@yozora/ast'
import { ParagraphType, RootType, TextType } from '@yozora/ast'
import Parser from '@yozora/parser'

interface IParseOptions {
  /**
   * Whether it is necessary to reserve the position in the Node produced.
   */
  readonly shouldReservePosition?: boolean
  /**
   * Preset definition meta data list.
   */
  readonly presetDefinitions?: Association[]
  /**
   * Preset footnote definition meta data list.
   */
  readonly presetFootnoteDefinitions?: Association[]
  /**
   * Format url.
   * @param url
   * @returns
   */
  readonly formatUrl?: (url: string) => string
}

const parser = new Parser({
  defaultParseOptions: {
    shouldReservePosition: false,
  },
})

export const parseMarkdown = (text: string, options?: IParseOptions): Root => {
  try {
    const ast: Root = parser.parse(text, options)
    return ast
  } catch (error) {
    console.error('[Failed to parse markdown]', text, error)

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
    }
    return ast as any as Root
  }
}
