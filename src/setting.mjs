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
 * @typedef {Object} ISettingData
 * @property {string} theme - Current theme name
 * @property {IEdition} edition - Global edition
 * @property {IEdition} [tmux_edition] - Tmux-specific edition override
 * @property {IEdition} [nvim_edition] - Neovim-specific edition override
 */

/**
 * @typedef {Object} ISettingProps
 * @property {string} filepath
 * @property {Reporter} reporter
 */

/** @type {Set<IEdition>} */
const VALID_EDITIONS = new Set(['nix', 'nix-remote', 'osx', 'win'])

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
    const fallback = PLATFORM === 'wsl' ? 'nix' : PLATFORM
    return {
      edition: VALID_EDITIONS.has(/** @type {IEdition} */ (fallback)) ? /** @type {IEdition} */ (fallback) : 'nix',
      theme: 'gruvbox-dark',
    }
  }

  /**
   * @param {unknown} data
   * @returns {ISettingData}
   */
  #normalize(data) {
    const result = this.#defaults()
    if (!data || typeof data !== 'object') return result

    const obj = /** @type {Record<string, unknown>} */ (data)

    if (typeof obj.edition === 'string' && VALID_EDITIONS.has(/** @type {IEdition} */ (obj.edition))) {
      result.edition = /** @type {IEdition} */ (obj.edition)
    }
    if (typeof obj.theme === 'string' && obj.theme.trim()) {
      result.theme = obj.theme.trim()
    }
    if (typeof obj.tmux_edition === 'string' && VALID_EDITIONS.has(/** @type {IEdition} */ (obj.tmux_edition))) {
      result.tmux_edition = /** @type {IEdition} */ (obj.tmux_edition)
    }
    if (typeof obj.nvim_edition === 'string' && VALID_EDITIONS.has(/** @type {IEdition} */ (obj.nvim_edition))) {
      result.nvim_edition = /** @type {IEdition} */ (obj.nvim_edition)
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
    if (patch.tmux_edition !== undefined) {
      if (VALID_EDITIONS.has(patch.tmux_edition)) {
        data.tmux_edition = patch.tmux_edition
      } else {
        delete data.tmux_edition
      }
    }
    if (patch.nvim_edition !== undefined) {
      if (VALID_EDITIONS.has(patch.nvim_edition)) {
        data.nvim_edition = patch.nvim_edition
      } else {
        delete data.nvim_edition
      }
    }

    await fs.writeFile(this.#filepath, JSON.stringify(data, null, 2) + '\n', 'utf8')
  }

  /**
   * Get edition for a specific app, falling back to global edition.
   * @param {'tmux' | 'nvim'} app
   * @returns {Promise<IEdition>}
   */
  async getEdition(app) {
    const data = await this.load()
    const key = /** @type {keyof ISettingData} */ (`${app}_edition`)
    return /** @type {IEdition} */ (data[key]) ?? data.edition
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
  const tmux_edition = /** @type {IEdition | undefined} */ (getArg('--set-tmux-edition'))
  const nvim_edition = /** @type {IEdition | undefined} */ (getArg('--set-nvim-edition'))

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
