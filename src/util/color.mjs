/**
 * Convert hex color to closest ANSI 256 color code
 * @param {string} hex - Hex color string (e.g., "#89B4FA" or "89B4FA")
 * @return {number} ANSI 256 color code (0-255)
 */
export function hex2ansi256(hex) {
  const h = hex.replace(/^#/, '')
  const r = parseInt(h.slice(0, 2), 16)
  const g = parseInt(h.slice(2, 4), 16)
  const b = parseInt(h.slice(4, 6), 16)

  // Check grayscale (232-255)
  if (r === g && g === b) {
    if (r < 8) return 16
    if (r > 248) return 231
    return Math.round((r - 8) / 10) + 232
  }

  // Convert to 6x6x6 color cube (16-231)
  const ri = r < 48 ? 0 : r < 115 ? 1 : Math.min(5, Math.floor((r - 35) / 40))
  const gi = g < 48 ? 0 : g < 115 ? 1 : Math.min(5, Math.floor((g - 35) / 40))
  const bi = b < 48 ? 0 : b < 115 ? 1 : Math.min(5, Math.floor((b - 35) / 40))
  return 16 + 36 * ri + 6 * gi + bi
}

/**
 * @param {string} hex  the hex color
 * @return {string} the rgb color
 */
export function hex2rgb(hex) {
  const match = /^#(\w\w)(\w\w)(\w\w)$/.exec(hex)
  if (!match) return 'rgb(0, 0, 0)'
  const [, r, g, b] = match
  const rr = Number.parseInt(r, 16)
  const gg = Number.parseInt(g, 16)
  const bb = Number.parseInt(b, 16)
  return `rgb(${rr}, ${gg}, ${bb})`
}

/**
 * @param {string} hex    the hex color
 * @param {number} alpha  the alpha value
 * @return {string} the rgb color
 */
export function hex2rgba(hex, alpha) {
  const match = /^#(\w\w)(\w\w)(\w\w)$/.exec(hex)
  if (!match) return `rgba(0, 0, 0, ${alpha})`
  const [, r, g, b] = match
  const rr = Number.parseInt(r, 16)
  const gg = Number.parseInt(g, 16)
  const bb = Number.parseInt(b, 16)
  return `rgba(${rr}, ${gg}, ${bb}, ${alpha})`
}
