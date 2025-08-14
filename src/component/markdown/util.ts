import type { Node, Root } from '@yozora/ast'
import {
  AdmonitionType,
  BlockquoteType,
  BreakType,
  CodeType,
  DefinitionType,
  DeleteType,
  EcmaImportType,
  EmphasisType,
  FootnoteType,
  HeadingType,
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
} from '@yozora/ast'
import { collectTexts } from '@yozora/ast-util'
import { parseMarkdown } from './parser'

export function extractLiteralTexts(texts: string | string[]): string {
  const asts: Root[] = Array.isArray(texts)
    ? texts.map(t => parseMarkdown(t))
    : [parseMarkdown(texts)]
  if (asts.length === 0) return ''

  const root: Root = asts[0]
  for (let index = 1; index < asts.length; ++index) {
    root.children.push(...asts[index].children)
  }

  return collectTexts(root.children).join('')
}

const BLOCK_TYPES = new Set([
  AdmonitionType,
  BlockquoteType,
  CodeType,
  DefinitionType,
  EcmaImportType,
  MathType,
  HeadingType,
  ListType,
  ListItemType,
  ParagraphType,
  TableType,
])

const INLINE_TYPES = new Set([
  BreakType,
  DeleteType,
  EmphasisType,
  FootnoteType,
  ImageReferenceType,
  ImageType,
  InlineCodeType,
  InlineMathType,
  LinkReferenceType,
  LinkType,
  StrongType,
])

export function isBlockNode(node: Node): boolean {
  return BLOCK_TYPES.has(node.type)
}

export function isInlineNode(node: Node): boolean {
  return INLINE_TYPES.has(node.type)
}
