import { existsSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { XDG_CONFIG_NODE_SETTING } from './path.mjs'
import { PLATFORM } from './platform.mjs'

/**
 * @typedef {'nix' | 'nix-remote' | 'osx' | 'win'} IEdition
 */

/**
 * @typedef {Object} ISettingsData
 * @property {string} theme
 * @property {IEdition} edition
 */

/** @type {Set<IEdition>} */
const VALID_EDITIONS = new Set(['nix', 'nix-remote', 'osx', 'win'])

class Settings {
  /** @type {string} */
  #filepath

  constructor(filepath) {
    this.#filepath = filepath
  }

  /** @returns {ISettingsData} */
  #defaults() {
    const fallback = PLATFORM === 'wsl' ? 'nix' : PLATFORM
    return {
      edition: VALID_EDITIONS.has(fallback) ? fallback : 'nix',
      theme: 'gruvbox-dark',
    }
  }

  /**
   * @param {unknown} data
   * @returns {ISettingsData}
   */
  #normalize(data) {
    const result = this.#defaults()
    if (!data || typeof data !== 'object') return result
    if (typeof data.edition === 'string' && VALID_EDITIONS.has(data.edition)) {
      result.edition = data.edition
    }
    if (typeof data.theme === 'string' && data.theme.trim()) {
      result.theme = data.theme.trim()
    }
    return result
  }

  /** @returns {Promise<ISettingsData>} */
  async load() {
    if (!existsSync(this.#filepath)) return this.#defaults()
    try {
      const content = await fs.readFile(this.#filepath, 'utf8')
      return this.#normalize(JSON.parse(content))
    } catch {
      console.error('\x1b[31m[Settings.load]\x1b[0m Failed to load', this.#filepath)
      return this.#defaults()
    }
  }

  /**
   * @param {Partial<ISettingsData>} patch
   * @returns {Promise<void>}
   */
  async save(patch) {
    const data = await this.load()
    if (patch.edition !== undefined && VALID_EDITIONS.has(patch.edition)) {
      data.edition = patch.edition
    }
    if (patch.theme !== undefined && patch.theme.trim()) {
      data.theme = patch.theme.trim()
    }
    await fs.writeFile(this.#filepath, JSON.stringify(data, null, 2), 'utf8')
  }
}

/**
 * @typedef {Object} ISettings
 * @property {() => Promise<ISettingsData>} load
 * @property {(patch: Partial<ISettingsData>) => Promise<void>} save
 */

/** @type {ISettings} */
export const settings = new Settings(XDG_CONFIG_NODE_SETTING)

// CLI entry
const selfPath = fileURLToPath(import.meta.url)
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(selfPath)) {
  const args = process.argv.slice(2)

  const getArg = flag => {
    const i = args.indexOf(flag)
    if (i !== -1 && args[i + 1]) return args[i + 1]
    const match = args.find(a => a.startsWith(`${flag}=`))
    return match ? match.slice(flag.length + 1) : null
  }

  const edition = getArg('--sync-edition')
  const theme = getArg('--sync-theme')

  if (edition || theme) await settings.save({ edition, theme })

  if (args.includes('--print-edition')) {
    const data = await settings.load()
    process.stdout.write(`${data.edition}\n`)
  }
  if (args.includes('--print-theme')) {
    const data = await settings.load()
    process.stdout.write(`${data.theme}\n`)
  }
}
