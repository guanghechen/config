import type { Root } from '@yozora/ast'
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
