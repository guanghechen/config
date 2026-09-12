import type { IElement, ILabelElement, INode, IStyle } from './model.ts'
import { resizeNodeBox } from './pose.ts'

export type ITextElement = ILabelElement | (INode & { readonly type: 'text' })
export type ITextKind = 'text' | 'label'
export interface ITextLayout {
  readonly lines: ReadonlyArray<string>
  readonly width: number
  readonly height: number
}
export type ITextStyle = Pick<IStyle, 'fontSize' | 'fontFamily' | 'fontWeight' | 'textAlign'>

export const TEXT_FONTS = {
  hand: '"Comic Sans MS", "Segoe Print", cursive',
  sans: 'Arial, Helvetica, sans-serif',
  mono: 'ui-monospace, "Maple Mono NF CN", monospace',
} as const

export function hasText(element: IElement): element is ITextElement {
  return element.type === 'text' || element.type === 'shape' || element.type === 'edge'
}
export function textContent(element: ITextElement): string {
  return element.type === 'text' ? element.text : (element.label ?? '')
}
export function textSize(style: ITextStyle, kind: ITextKind): number {
  return style.fontSize ?? (kind === 'text' ? 24 : 20)
}
export function textLineHeight(style: ITextStyle, kind: ITextKind): number {
  return Math.ceil(textSize(style, kind) * (kind === 'text' ? 4 / 3 : 1.3))
}
export function textFont(style: ITextStyle, kind: ITextKind): string {
  return `${style.fontWeight === 'bold' ? 'bold ' : ''}${textSize(style, kind)}px ${TEXT_FONTS[style.fontFamily ?? (kind === 'text' ? 'hand' : 'mono')]}`
}

const graphemes = new Intl.Segmenter(undefined, { granularity: 'grapheme' })

// Measure complete words to retain native shaping; only oversized words split at grapheme boundaries.
export function wrapText(
  text: string,
  width: number,
  height: number,
  lineHeight: number,
  measure: (text: string) => number,
): ITextLayout {
  const maxLines = Math.min(2000, Math.max(0, Math.floor(height / lineHeight)))
  const limit = Math.min(8192, width)
  if (!text || limit < 1 || !maxLines) return { lines: [], width: 0, height: 0 }
  const lines: string[] = []
  let line = '',
    overflow = false
  const flush = (): boolean => {
    lines.push(line.trimEnd())
    line = ''
    return lines.length >= maxLines
  }
  const content = text
    .replace(/\r\n?/g, '\n')
    .replaceAll('\t', '    ')
    .replace(/[^\S\n]+$/gm, '')
  outer: for (const match of content.matchAll(/\n|[^\S\n]+|[^\s]+/gu)) {
    const token = match[0]
    if (token === '\n') {
      if (flush()) {
        overflow = true
        break
      }
      continue
    }
    if (measure(line + token) <= limit) {
      line += token
      continue
    }
    if (line) {
      if (flush()) {
        overflow = true
        break
      }
      if (!token.trim()) continue
    }
    if (measure(token) <= limit) {
      line = token
      continue
    }
    const boundaries = graphemes.segment(token)
    const boundary = (index: number): number =>
      index >= token.length ? token.length : boundaries.containing(index)!.index
    let offset = 0
    while (offset < token.length) {
      let low = offset,
        high = boundary(Math.min(token.length, offset + 256))
      if (high === offset) high = offset + boundaries.containing(offset)!.segment.length
      while (measure(token.slice(offset, high)) <= limit) {
        low = high
        if (high === token.length) break
        high = boundary(Math.min(token.length, offset + (high - offset) * 2))
        if (high <= low) high = low + boundaries.containing(low)!.segment.length
      }
      while (high > low) {
        const middle = boundary(Math.floor((low + high) / 2))
        if (middle <= low) break
        if (measure(token.slice(offset, middle)) <= limit) low = middle
        else high = middle
      }
      if (low === offset) {
        if (!lines.length && measure('…') <= limit) lines.push('')
        overflow = true
        break outer
      }
      line = token.slice(offset, low)
      offset = low
      if (offset < token.length && flush()) {
        overflow = true
        break outer
      }
    }
  }
  if (!overflow && (line || !lines.length || content.endsWith('\n'))) lines.push(line.trimEnd())
  if (overflow && lines.length) {
    const last = Array.from(graphemes.segment(lines.at(-1)!), item => item.segment)
    while (last.length && measure(last.join('') + '…') > limit) last.pop()
    lines[lines.length - 1] = measure('…') <= limit ? last.join('') + '…' : ''
  }
  let widest = 0
  for (const value of lines) widest = Math.max(widest, measure(value))
  return { lines, width: Math.min(limit, widest), height: lines.length * lineHeight }
}

export function fitTextNode(node: INode, measure: (text: string) => number): INode {
  if ((node.type !== 'text' && node.type !== 'shape') || !node.autoSize) return node
  const content = textContent(node)
  if (node.type === 'shape' && !content.trim()) return node
  const kind = node.type === 'text' ? 'text' : 'label'
  const lineHeight = textLineHeight(node.style, kind)
  let intrinsic = 0
  for (const line of content.replace(/\r\n?/g, '\n').split('\n', 2001)) {
    intrinsic = Math.max(intrinsic, measure(line.replaceAll('\t', '    ').trimEnd()))
    if (intrinsic >= 800) {
      intrinsic = 800
      break
    }
  }
  const layout = wrapText(content, Math.max(1, Math.ceil(intrinsic)), 10000, lineHeight, measure)
  const scale =
    node.type === 'shape'
      ? node.shape === 'diamond'
        ? 0.5
        : node.shape === 'ellipse'
          ? Math.SQRT1_2
          : 1
      : 1
  const padding = node.type === 'text' ? 8 : 24
  const width = Math.max(16, Math.ceil((Math.ceil(intrinsic) + padding) / scale))
  const height = Math.max(16, Math.ceil(((layout.height || lineHeight) + padding) / scale))
  return resizeNodeBox(node, width, height)
}
