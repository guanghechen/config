#!/usr/bin/env node

import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

export const CONFIG_DIVIDER = '#'.repeat(100)

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
 * config.shared.toml owns the prefix; content after the divider is preserved.
 *
 * @param {string} shared
 * @param {string} current
 * @returns {string}
 */
export function renderConfig(shared, current) {
  const dividerPattern = new RegExp(`(?:^|\\n)${CONFIG_DIVIDER}(?=\\r?\\n|$)`)
  const dividerMatch = dividerPattern.exec(current)
  const suffix = dividerMatch ? current.slice(dividerMatch.index + dividerMatch[0].length) : ''

  return `${shared.trimEnd()}\n\n${CONFIG_DIVIDER}${withLeadingBlankLine(suffix)}`
}

/**
 * @param {string} filepath
 * @returns {Promise<string>}
 */
async function readExistingConfig(filepath) {
  try {
    return await fs.readFile(filepath, 'utf8')
  } catch (error) {
    if (error && typeof error === 'object' && 'code' in error && error.code === 'ENOENT') {
      return ''
    }
    throw error
  }
}

/**
 * @param {string} sharedPath
 * @param {string} configPath
 * @returns {Promise<boolean>}
 */
export async function syncConfig(sharedPath, configPath) {
  const [shared, current] = await Promise.all([
    fs.readFile(sharedPath, 'utf8'),
    readExistingConfig(configPath),
  ])
  const next = renderConfig(shared, current)
  if (next === current) return false

  await fs.writeFile(configPath, next, 'utf8')
  return true
}

const scriptPath = fileURLToPath(import.meta.url)

if (process.argv[1] && path.resolve(process.argv[1]) === scriptPath) {
  const configDir = path.resolve(path.dirname(scriptPath), '..')
  const changed = await syncConfig(
    path.join(configDir, 'config.shared.toml'),
    path.join(configDir, 'config.toml'),
  )
  console.log(changed ? 'Synced config.toml.' : 'config.toml is already up to date.')
}
