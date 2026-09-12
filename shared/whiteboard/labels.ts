import type { ITextStyle } from './text.ts'
import { textLineHeight, textSize, wrapText } from './text.ts'

export const LABEL_FONT_SIZE = 20
export const LABEL_LINE_HEIGHT = 26
export const LABEL_FONT = `${LABEL_FONT_SIZE}px ui-monospace, "Maple Mono NF CN", monospace`

// Monospace cells keep label wrapping and hit bounds consistent without a DOM/canvas dependency.
function characterWidth(character: string, size: number): number {
  return character.codePointAt(0)! > 0xff ? size : size * 0.6
}

export function wrapLabel(text: string, width: number, height: number, style: ITextStyle = {}) {
  if (!text.trim()) return { lines: [], width: 0, height: 0 }
  const size = textSize(style, 'label')
  return wrapText(text, width, height, textLineHeight(style, 'label'), value =>
    Array.from(value).reduce((sum, character) => sum + characterWidth(character, size), 0),
  )
}
