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

/**
 * @param {string} filepath
 * @param {import('@guanghechen/stl/reporter').Reporter} reporter
 */
export async function touch(filepath, reporter) {
  if (fs.existsSync(filepath)) {
    try {
      const now = new Date()
      fs.utimesSync(filepath, now, now)
    } catch (error) {
      reporter.error('Error touching file:', { filepath, error })
    }
  }
}
