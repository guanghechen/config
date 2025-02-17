import { existsSync, statSync, utimesSync } from "node:fs";

/**
 * @param {string} hex  the hex color
 * @return {string} the rgb color
 */
export function hex2rgb(hex) {
  const [_, r, g, b] = /^#(\w\w)(\w\w)(\w\w)$/.exec(hex)
  const rr = Number.parseInt(r, 16)
  const gg = Number.parseInt(g, 16)
  const bb = Number.parseInt(b, 16)
  return `rgb(${rr}, ${gg}, ${bb})`;
}

/**
 * @param {string} hex    the hex color
 * @param {number} alpha  the alpha value
 * @return {string} the rgb color
 */
export function hex2rgba(hex, alpha) {
  const [_, r, g, b] = /^#(\w\w)(\w\w)(\w\w)$/.exec(hex)
  const rr = Number.parseInt(r, 16)
  const gg = Number.parseInt(g, 16)
  const bb = Number.parseInt(b, 16)
  return `rgba(${rr}, ${gg}, ${bb}, ${alpha})`;
}

/**
 * @param {string|null|undefined} filepath
 * @return {boolean}
 */
export function is_directory(filepath) {
  return !!filepath && existsSync(filepath) && statSync(filepath).isDirectory();
}

/**
 * @param {string|null|undefined} filepath
 * @return {boolean}
 */
export function is_file(filepath) {
  return !!filepath && existsSync(filepath) && statSync(filepath).isFile();
}

export async function touch(filepath) {
  if (existsSync(filepath)) {
    try {
      const now = new Date();
      utimesSync(filepath, now, now);
    } catch (error) {
      console.error("[touch] Error touching file:", { filepath, error });
    }
  }
}

