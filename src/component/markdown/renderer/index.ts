import type { Node } from '@yozora/ast'
import {
  AdmonitionType,
  BlockquoteType,
  BreakType,
  CodeType,
  DefinitionType,
  DeleteType,
  EmphasisType,
  FootnoteDefinitionType,
  FootnoteReferenceType,
  FootnoteType,
  HeadingType,
  HtmlType,
  ImageReferenceType,
  ImageType,
  InlineCodeType,
  InlineMathType,
  LinkReferenceType,
  LinkType,
  ListItemType,
  ListType,
  MathType,
  ParagraphType,
  StrongType,
  TableType,
  TextType,
  ThematicBreakType,
} from '@yozora/ast'
import type { INodeRendererMap } from '../context'
import { AdmonitionRenderer } from './admonition'
import { BlockquoteRenderer } from './blockquote'
import { BreakRenderer } from './break'
import { CodeRenderer } from './code'
import { DeleteRenderer } from './delete'
import { EmphasisRenderer } from './emphasis'
import { FootnoteReferenceRenderer } from './footnoteReference'
import { HeadingRenderer } from './heading'
import { ImageRenderer } from './image'
import { ImageReferenceRenderer } from './imageReference'
import { InlineCodeRenderer } from './inlineCode'
import { InlineMathRenderer } from './inlineMath'
import { LinkRenderer } from './link'
import { LinkReferenceRenderer } from './linkReference'
import { ListRenderer } from './list'
import { ListItemRenderer } from './listItem'
import { MathRenderer } from './math'
import { ParagraphRenderer } from './paragraph'
import { StrongRenderer } from './strong'
import { TableRenderer } from './table'
import { TextRenderer } from './text'
import { ThematicBreakRenderer } from './thematicBreak'

export function buildNodeRendererMap(
  customizedRendererMap?: Readonly<Partial<INodeRendererMap>>,
): Readonly<INodeRendererMap> {
  if (customizedRendererMap == null) return defaultNodeRendererMap

  let hasChanged = false
  const result: INodeRendererMap = {} as unknown as INodeRendererMap
  for (const [key, value] of Object.entries(customizedRendererMap)) {
    if (value && value !== defaultNodeRendererMap[key]) {
      hasChanged = true
      result[key] = value
    }
  }

  return hasChanged ? { ...defaultNodeRendererMap, ...result } : defaultNodeRendererMap
}

// Default ast renderer map.
export const defaultNodeRendererMap: Readonly<INodeRendererMap> = {
  [AdmonitionType]: AdmonitionRenderer,
  [BlockquoteType]: BlockquoteRenderer,
  [BreakType]: BreakRenderer,
  [CodeType]: CodeRenderer,
  [DefinitionType]: () => null,
  [DeleteType]: DeleteRenderer,
  [EmphasisType]: EmphasisRenderer,
  [FootnoteDefinitionType]: () => null,
  [FootnoteType]: () => null,
  [FootnoteReferenceType]: FootnoteReferenceRenderer,
  [HeadingType]: HeadingRenderer,
  [HtmlType]: () => null,
  [ImageType]: ImageRenderer,
  [ImageReferenceType]: ImageReferenceRenderer,
  [InlineCodeType]: InlineCodeRenderer,
  [InlineMathType]: InlineMathRenderer,
  [LinkType]: LinkRenderer,
  [LinkReferenceType]: LinkReferenceRenderer,
  [ListType]: ListRenderer,
  [ListItemType]: ListItemRenderer,
  [MathType]: MathRenderer,
  [ParagraphType]: ParagraphRenderer,
  [StrongType]: StrongRenderer,
  [TableType]: TableRenderer,
  [TextType]: TextRenderer,
  [ThematicBreakType]: ThematicBreakRenderer,
  _fallback: function ReactMarkdownNodeFallback(node: Node) {
    console.warn(`Cannot find render for \`${node.type}\` type node:`, node)
    return null
  },
}
