#!/usr/bin/env node

import { randomUUID } from 'node:crypto'
import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

export const CONFIG_DIVIDER = '#'.repeat(100)
const DEFAULT_THEME_FILENAME = 'vsc-dark-modern.json'

const THEME_COLOR_KEYS = [
  'panel_bg',
  'surface_dim',
  'surface0',
  'surface1',
  'overlay0',
  'overlay1',
  'text',
  'subtext0',
  'accent',
  'mauve',
  'green',
  'yellow',
  'red',
  'blue',
  'teal',
  'peach',
]

/**
 * @param {string} suffix
 * @returns {string}
 */
function withLeadingBlankLine(suffix) {
  if (!suffix) return '\n\n'

  const newline = suffix.startsWith('\r\n') ? '\r\n' : '\n'
  if (suffix.startsWith(newline + newline)) return suffix
  if (suffix.startsWith(newline)) return newline + suffix
  return newline + newline + suffix
}

/**
 * @param {unknown} value
 * @returns {value is Record<string, unknown>}
 */
function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

/**
 * @param {Record<string, unknown>} value
 * @param {string[]} expected
 * @param {string} label
 */
function validateKeys(value, expected, label) {
  const actual = Object.keys(value).sort()
  const sortedExpected = [...expected].sort()
  if (
    actual.length !== sortedExpected.length ||
    actual.some((key, index) => key !== sortedExpected[index])
  ) {
    throw new TypeError(`${label} must contain exactly: ${sortedExpected.join(', ')}`)
  }
}

/**
 * @param {unknown} value
 * @returns {string}
 */
export function renderTheme(value) {
  if (!isRecord(value)) throw new TypeError('theme/local.json must contain an object')
  validateKeys(value, ['name', 'custom'], 'theme/local.json')

  const { name, custom } = value
  if (typeof name !== 'string' || !name.trim()) {
    throw new TypeError('theme/local.json name must be a non-empty string')
  }
  if (!isRecord(custom)) throw new TypeError('theme/local.json custom must contain an object')
  validateKeys(custom, THEME_COLOR_KEYS, 'theme/local.json custom')

  const lines = ['[theme]', `name = ${JSON.stringify(name)}`, '', '[theme.custom]']
  for (const key of THEME_COLOR_KEYS) {
    const color = custom[key]
    if (typeof color !== 'string' || !color.trim()) {
      throw new TypeError(`theme/local.json custom.${key} must be a non-empty string`)
    }
    lines.push(`${key} = ${JSON.stringify(color)}`)
  }
  return lines.join('\n')
}

/**
 * Zero dividers means the whole existing file is the manual tail. One divider
 * is the legacy shared/theme format, which has no manual tail. Two or more
 * dividers preserve everything after the second divider.
 *
 * @param {string} current
 * @returns {string}
 */
function extractManualTail(current) {
  const dividerPattern = new RegExp(`(?:^|\\n)${CONFIG_DIVIDER}(?=\\r?\\n|$)`, 'g')
  const dividerEnds = [...current.matchAll(dividerPattern)].map(match => match.index + match[0].length)
  if (dividerEnds.length === 0) return current
  if (dividerEnds.length === 1) return ''
  return current.slice(dividerEnds[1])
}

/**
 * config.shared.toml owns the first section, the selected theme owns the
 * second, and the content after the second divider is preserved as the manual
 * tail.
 *
 * @param {string} shared
 * @param {string} theme
 * @param {string} current
 * @returns {string}
 */
export function renderConfig(shared, theme, current) {
  const manualTail = extractManualTail(current)
  return [
    shared.trimEnd(),
    CONFIG_DIVIDER,
    theme.trim(),
    CONFIG_DIVIDER,
  ].join('\n\n') + withLeadingBlankLine(manualTail)
}

/**
 * @param {string} filepath
 * @returns {Promise<string | null>}
 */
async function readFileIfExists(filepath) {
  try {
    return await fs.readFile(filepath, 'utf8')
  } catch (error) {
    if (error && typeof error === 'object' && 'code' in error && error.code === 'ENOENT') {
      return null
    }
    throw error
  }
}

/**
 * Use the machine-local theme when selected; otherwise use the repository
 * default preset next to it.
 *
 * @param {string} themePath
 * @returns {Promise<string>}
 */
async function readTheme(themePath) {
  const localTheme = await readFileIfExists(themePath)
  if (localTheme !== null) return localTheme

  return fs.readFile(path.join(path.dirname(themePath), DEFAULT_THEME_FILENAME), 'utf8')
}

/**
 * Replace config.toml atomically so a failed write cannot truncate its manual tail.
 *
 * @param {string} filepath
 * @param {string} content
 * @returns {Promise<void>}
 */
export async function writeFileAtomically(filepath, content) {
  const temporaryPath = path.join(
    path.dirname(filepath),
    `.${path.basename(filepath)}.${process.pid}.${randomUUID()}.tmp`,
  )
  let ownsTemporaryFile = false

  try {
    await fs.writeFile(temporaryPath, content, { encoding: 'utf8', flag: 'wx' })
    ownsTemporaryFile = true
    await fs.rename(temporaryPath, filepath)
  } catch (error) {
    const temporaryPathBelongsToAnotherWriter =
      !ownsTemporaryFile &&
      error &&
      typeof error === 'object' &&
      'code' in error &&
      error.code === 'EEXIST'

    if (!temporaryPathBelongsToAnotherWriter) {
      try {
        await fs.unlink(temporaryPath)
      } catch (cleanupError) {
        const temporaryFileDoesNotExist =
          cleanupError &&
          typeof cleanupError === 'object' &&
          'code' in cleanupError &&
          cleanupError.code === 'ENOENT'
        if (!temporaryFileDoesNotExist) {
          throw new AggregateError(
            [error, cleanupError],
            `Failed to replace ${filepath} and clean up ${temporaryPath}`,
          )
        }
      }
    }
    throw error
  }
}

/**
 * @param {string} sharedPath
 * @param {string} themePath
 * @param {string} configPath
 * @returns {Promise<boolean>}
 */
export async function syncConfig(sharedPath, themePath, configPath) {
  const [shared, themeJson, existingConfig] = await Promise.all([
    fs.readFile(sharedPath, 'utf8'),
    readTheme(themePath),
    readFileIfExists(configPath),
  ])
  const theme = renderTheme(JSON.parse(themeJson))
  const current = existingConfig ?? ''
  const next = renderConfig(shared, theme, current)
  if (next === current) return false

  await writeFileAtomically(configPath, next)
  return true
}

const scriptPath = fileURLToPath(import.meta.url)

if (process.argv[1] && path.resolve(process.argv[1]) === scriptPath) {
  const configDir = path.resolve(path.dirname(scriptPath), '..')
  const changed = await syncConfig(
    path.join(configDir, 'config.shared.toml'),
    path.join(configDir, 'theme', 'local.json'),
    path.join(configDir, 'config.toml'),
  )
  console.log(changed ? 'Synced config.toml.' : 'config.toml is already up to date.')
}
