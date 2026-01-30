import fs from 'node:fs'

/**
 * @param {string|null|undefined} filepath
 * @return {boolean}
 */
export function is_directory(filepath) {
  return !!filepath && fs.existsSync(filepath) && fs.statSync(filepath).isDirectory()
}

/**
 * @param {string|null|undefined} filepath
 * @return {boolean}
 */
export function is_file(filepath) {
  return !!filepath && fs.existsSync(filepath) && fs.statSync(filepath).isFile()
}

export async function touch(filepath) {
  if (fs.existsSync(filepath)) {
    try {
      const now = new Date()
      fs.utimesSync(filepath, now, now)
    } catch (error) {
      console.error('\x1b[31m[touch]\x1b[0m Error touching file:', { filepath, error })
    }
  }
}
