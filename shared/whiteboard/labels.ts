export const LABEL_FONT_SIZE = 20
export const LABEL_LINE_HEIGHT = 26
export const LABEL_FONT = `${LABEL_FONT_SIZE}px ui-monospace, "Maple Mono NF CN", monospace`

// Monospace cells keep label wrapping and hit bounds consistent without a DOM/canvas dependency.
function characterWidth(character: string): number {
  return character.codePointAt(0)! > 0xff ? LABEL_FONT_SIZE : LABEL_FONT_SIZE * 0.6
}

export function wrapLabel(
  text: string,
  width: number,
  height: number,
): { lines: string[]; width: number; height: number } {
  const maxLines = Math.max(0, Math.floor(height / LABEL_LINE_HEIGHT))
  if (!maxLines || width < LABEL_FONT_SIZE || !text.trim())
    return { lines: [], width: 0, height: 0 }
  const lines: string[] = []
  let line = '',
    lineWidth = 0,
    overflow = false
  for (const character of text.replaceAll('\r', '')) {
    const advance = characterWidth(character)
    if (character === '\n' || lineWidth + advance > width) {
      lines.push(line)
      line = ''
      lineWidth = 0
      if (lines.length === maxLines) {
        overflow = true
        break
      }
      if (character === '\n') continue
    }
    line += character
    lineWidth += advance
  }
  if (!overflow) lines.push(line)
  else {
    const characters = Array.from(lines.at(-1)!)
    let used = characters.reduce((sum, character) => sum + characterWidth(character), 0)
    while (characters.length && used + LABEL_FONT_SIZE > width)
      used -= characterWidth(characters.pop()!)
    lines[lines.length - 1] = characters.join('') + '…'
  }
  return {
    lines,
    width: Math.min(
      width,
      Math.max(
        ...lines.map(value =>
          Array.from(value).reduce((sum, character) => sum + characterWidth(character), 0),
        ),
      ),
    ),
    height: lines.length * LABEL_LINE_HEIGHT,
  }
}
