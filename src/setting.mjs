import { existsSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { PLATFORM, XDG_CONFIG_NODE_SETTING } from '#env'
import { Reporter } from '#stl/reporter'

/**
 * @typedef {'nix' | 'nix-remote' | 'osx' | 'win'} IEdition
 */

/**
 * @typedef {'latest' | 'nightly' | 'manual'} IAppEdition
 */

/**
 * @typedef {Object} ISettingData
 * @property {string} theme - Current theme name
 * @property {IEdition} edition - Global edition
 * @property {IAppEdition} tmux_edition - Tmux edition
 * @property {IAppEdition} nvim_edition - Neovim edition
 * @property {number} node_edition - Preferred Node.js major version
 */

/**
 * @typedef {Object} ISettingProps
 * @property {string} filepath
 * @property {Reporter} reporter
 */

/** @type {Set<IEdition>} */
const VALID_EDITIONS = new Set(['nix', 'nix-remote', 'osx', 'win'])

/** @type {Set<IAppEdition>} */
const VALID_APP_EDITIONS = new Set(['latest', 'nightly', 'manual'])

const DEFAULT_NODE_VERSION = 24

export class Setting {
  /** @type {string} */
  #filepath
  /** @type {Reporter} */
  #reporter

  /** @param {ISettingProps} props */
  constructor(props) {
    this.#filepath = props.filepath
    this.#reporter = props.reporter
  }

  /** @returns {ISettingData} */
  #defaults() {
    /** @type {ISettingData} */
    const result = {
      edition: 'nix',
      theme: 'vsc-dark-modern',
      tmux_edition: 'latest',
      nvim_edition: 'latest',
      node_edition: DEFAULT_NODE_VERSION,
    }
    switch (PLATFORM) {
      case 'osx':
        result.edition = 'osx'
        result.nvim_edition = 'manual'
        break
      case 'win':
        result.edition = 'win'
        break
      case 'wsl':
        result.edition = 'nix'
        result.nvim_edition = 'manual'
        break
      case 'nix':
        result.edition = 'nix'
        result.nvim_edition = 'manual'
        break
      default:
        break
    }
    return result
  }

  /**
   * @param {unknown} data
   * @returns {ISettingData}
   */
  #normalize(data) {
    const result = this.#defaults()
    if (!data || typeof data !== 'object') return result

    const obj = /** @type {Record<string, unknown>} */ (data)

    if (
      typeof obj.edition === 'string' &&
      VALID_EDITIONS.has(/** @type {IEdition} */ (obj.edition))
    ) {
      result.edition = /** @type {IEdition} */ (obj.edition)
    }
    if (typeof obj.theme === 'string' && obj.theme.trim()) {
      result.theme = obj.theme.trim()
    }
    if (
      typeof obj.tmux_edition === 'string' &&
      VALID_APP_EDITIONS.has(/** @type {IAppEdition} */ (obj.tmux_edition))
    ) {
      result.tmux_edition = /** @type {IAppEdition} */ (obj.tmux_edition)
    }
    if (
      typeof obj.nvim_edition === 'string' &&
      VALID_APP_EDITIONS.has(/** @type {IAppEdition} */ (obj.nvim_edition))
    ) {
      result.nvim_edition = /** @type {IAppEdition} */ (obj.nvim_edition)
    }
    if (typeof obj.node_edition === 'number' && obj.node_edition > 0) {
      result.node_edition = obj.node_edition
    }

    return result
  }

  /** @returns {Promise<ISettingData>} */
  async load() {
    if (!existsSync(this.#filepath)) return this.#defaults()
    try {
      const content = await fs.readFile(this.#filepath, 'utf8')
      return this.#normalize(JSON.parse(content))
    } catch {
      this.#reporter.error('Failed to load', this.#filepath)
      return this.#defaults()
    }
  }

  /**
   * @param {Partial<ISettingData>} patch
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
    if (patch.tmux_edition !== undefined && VALID_APP_EDITIONS.has(patch.tmux_edition)) {
      data.tmux_edition = patch.tmux_edition
    }
    if (patch.nvim_edition !== undefined && VALID_APP_EDITIONS.has(patch.nvim_edition)) {
      data.nvim_edition = patch.nvim_edition
    }
    if (patch.node_edition !== undefined && patch.node_edition > 0) {
      data.node_edition = patch.node_edition
    }

    await fs.writeFile(this.#filepath, JSON.stringify(data, null, 2) + '\n', 'utf8')
  }

  /**
   * @template {keyof ISettingData} K
   * @param {K} key
   * @returns {Promise<ISettingData[K]>}
   */
  async get(key) {
    const data = await this.load()
    return data[key]
  }

  /**
   * @template {keyof ISettingData} K
   * @param {K} key
   * @param {ISettingData[K]} value
   * @returns {Promise<boolean>}
   */
  async set(key, value) {
    switch (key) {
      case 'edition':
        if (!VALID_EDITIONS.has(/** @type {IEdition} */ (value))) return false
        break
      case 'theme':
        if (typeof value !== 'string' || !value.trim()) return false
        break
      case 'tmux_edition':
      case 'nvim_edition':
        if (!VALID_APP_EDITIONS.has(/** @type {IAppEdition} */ (value))) return false
        break
      case 'node_edition':
        if (typeof value !== 'number' || value <= 0) return false
        break
      default:
        return false
    }
    await this.save({ [key]: value })
    return true
  }
}

// CLI entry
const selfPath = fileURLToPath(import.meta.url)
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(selfPath)) {
  const reporter = new Reporter({ prefix: 'setting' })
  const setting = new Setting({ filepath: XDG_CONFIG_NODE_SETTING, reporter })
  const args = process.argv.slice(2)

  /** @param {string} flag */
  const getArg = flag => {
    const i = args.indexOf(flag)
    if (i !== -1 && args[i + 1]) return args[i + 1]
    const match = args.find(a => a.startsWith(`${flag}=`))
    return match ? match.slice(flag.length + 1) : undefined
  }

  const edition = /** @type {IEdition | undefined} */ (getArg('--set-edition'))
  const theme = getArg('--set-theme')
  const tmux_edition = /** @type {IAppEdition | undefined} */ (getArg('--set-tmux-edition'))
  const nvim_edition = /** @type {IAppEdition | undefined} */ (getArg('--set-nvim-edition'))

  if (edition || theme || tmux_edition || nvim_edition) {
    await setting.save({ edition, theme, tmux_edition, nvim_edition })
  }

  if (args.includes('--print-edition')) {
    const data = await setting.load()
    process.stdout.write(`${data.edition}\n`)
  }
  if (args.includes('--print-theme')) {
    const data = await setting.load()
    process.stdout.write(`${data.theme}\n`)
  }
  if (args.includes('--print')) {
    const data = await setting.load()
    process.stdout.write(JSON.stringify(data, null, 2) + '\n')
  }
}
