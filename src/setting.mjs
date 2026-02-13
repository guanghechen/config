import { existsSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  PLATFORM,
  XDG_CONFIG_NODE_SETTING_LOCAL,
  XDG_CONFIG_NODE_SETTING_LOCAL_PS1,
} from '#env'
import {
  parse as parseEnv,
  stringify as stringifyEnv,
  stringifyPs1 as stringifyEnvPs1,
} from '#stl/env'
import { Reporter } from '#stl/reporter'

/** @typedef {import('#stl/reporter').IReporter} IReporter */

/**
 * @typedef {'nix' | 'nix-remote' | 'osx' | 'win'} IEdition
 */

/**
 * @typedef {'latest' | 'nightly' | 'manual'} IAppEdition
 */

/**
 * @typedef {Object} ISettingData
 * @property {number} app_edition_node - Preferred Node.js major version
 * @property {IAppEdition} app_edition_nvim - Neovim edition
 * @property {IAppEdition} app_edition_tmux - Tmux edition
 * @property {string} app_python_env - Python conda environment name
 * @property {IEdition} edition - Global edition
 * @property {string} theme - Current theme name
 */

/**
 * @typedef {Object} ISettingProps
 * @property {IReporter} [reporter]
 */

/** @type {Set<IEdition>} */
const VALID_EDITIONS = new Set(['nix', 'nix-remote', 'osx', 'win'])

/** @type {Set<IAppEdition>} */
const VALID_APP_EDITIONS = new Set(['latest', 'nightly', 'manual'])

const ENV_KEY_PATTERN = /^[A-Z][A-Z0-9_]*$/

const DEFAULT_APP_EDITION_NODE = 24
const DEFAULT_APP_PYTHON_ENV = 'lemon'

/** @type {IReporter} */
const defaultReporter = new Reporter({ prefix: 'setting' })

export class Setting {
  /** @type {IReporter} */
  #reporter

  /** @param {ISettingProps} [props] */
  constructor(props) {
    this.#reporter = props?.reporter ?? defaultReporter
  }

  /** @returns {ISettingData} */
  #defaults() {
    /** @type {ISettingData} */
    const result = {
      app_edition_node: DEFAULT_APP_EDITION_NODE,
      app_edition_nvim: 'latest',
      app_edition_tmux: 'latest',
      app_python_env: DEFAULT_APP_PYTHON_ENV,
      edition: 'nix',
      theme: 'vsc-dark-modern',
    }
    switch (PLATFORM) {
      case 'osx':
        result.edition = 'osx'
        result.app_edition_nvim = 'manual'
        break
      case 'win':
        result.edition = 'win'
        break
      case 'wsl':
        result.edition = 'nix'
        result.app_edition_nvim = 'manual'
        break
      case 'nix':
        result.edition = 'nix'
        result.app_edition_nvim = 'manual'
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

    if (typeof obj.app_edition_node === 'number' && obj.app_edition_node > 0) {
      result.app_edition_node = obj.app_edition_node
    }
    if (
      typeof obj.app_edition_nvim === 'string' &&
      VALID_APP_EDITIONS.has(/** @type {IAppEdition} */ (obj.app_edition_nvim))
    ) {
      result.app_edition_nvim = /** @type {IAppEdition} */ (obj.app_edition_nvim)
    }
    if (
      typeof obj.app_edition_tmux === 'string' &&
      VALID_APP_EDITIONS.has(/** @type {IAppEdition} */ (obj.app_edition_tmux))
    ) {
      result.app_edition_tmux = /** @type {IAppEdition} */ (obj.app_edition_tmux)
    }
    if (typeof obj.app_python_env === 'string' && obj.app_python_env.trim()) {
      result.app_python_env = obj.app_python_env.trim()
    }
    if (
      typeof obj.edition === 'string' &&
      VALID_EDITIONS.has(/** @type {IEdition} */ (obj.edition))
    ) {
      result.edition = /** @type {IEdition} */ (obj.edition)
    }
    if (typeof obj.theme === 'string' && obj.theme.trim()) {
      result.theme = obj.theme.trim()
    }

    return result
  }

  /** @returns {Promise<ISettingData>} */
  async load() {
    if (!existsSync(XDG_CONFIG_NODE_SETTING_LOCAL)) return this.#defaults()
    try {
      const content = await fs.readFile(XDG_CONFIG_NODE_SETTING_LOCAL, 'utf8')
      const env = parseEnv(content)
      return this.#normalize({
        app_edition_node: env.GHC_APP_EDITION_NODE,
        app_edition_nvim: env.GHC_APP_EDITION_NVIM,
        app_edition_tmux: env.GHC_APP_EDITION_TMUX,
        app_python_env: env.GHC_APP_PYTHON_ENV,
        edition: env.GHC_EDITION,
        theme: env.GHC_THEME,
      })
    } catch {
      this.#reporter.error('Failed to load', XDG_CONFIG_NODE_SETTING_LOCAL)
      return this.#defaults()
    }
  }

  /**
   * @param {Partial<ISettingData>} patch
   * @returns {Promise<void>}
   */
  async save(patch) {
    const data = await this.load()

    if (patch.app_edition_node !== undefined && patch.app_edition_node > 0) {
      data.app_edition_node = patch.app_edition_node
    }
    if (patch.app_edition_nvim !== undefined && VALID_APP_EDITIONS.has(patch.app_edition_nvim)) {
      data.app_edition_nvim = patch.app_edition_nvim
    }
    if (patch.app_edition_tmux !== undefined && VALID_APP_EDITIONS.has(patch.app_edition_tmux)) {
      data.app_edition_tmux = patch.app_edition_tmux
    }
    if (patch.app_python_env !== undefined && patch.app_python_env.trim()) {
      data.app_python_env = patch.app_python_env.trim()
    }
    if (patch.edition !== undefined && VALID_EDITIONS.has(patch.edition)) {
      data.edition = patch.edition
    }
    if (patch.theme !== undefined && patch.theme.trim()) {
      data.theme = patch.theme.trim()
    }

    const envData = {
      GHC_APP_EDITION_NODE: data.app_edition_node,
      GHC_APP_EDITION_NVIM: data.app_edition_nvim,
      GHC_APP_EDITION_TMUX: data.app_edition_tmux,
      GHC_APP_PYTHON_ENV: data.app_python_env,
      GHC_EDITION: data.edition,
      GHC_THEME: data.theme,
    }

    for (const key of Object.keys(envData)) {
      if (!ENV_KEY_PATTERN.test(key)) {
        throw new Error(`Invalid env key "${key}": must match [A-Z][A-Z0-9_]*`)
      }
    }

    await Promise.all([
      fs.writeFile(XDG_CONFIG_NODE_SETTING_LOCAL, stringifyEnv(envData, { exportPrefix: true }), 'utf8'),
      fs.writeFile(XDG_CONFIG_NODE_SETTING_LOCAL_PS1, stringifyEnvPs1(envData), 'utf8'),
    ])
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
      case 'app_edition_node':
        if (typeof value !== 'number' || value <= 0) return false
        break
      case 'app_edition_nvim':
      case 'app_edition_tmux':
        if (!VALID_APP_EDITIONS.has(/** @type {IAppEdition} */ (value))) return false
        break
      case 'app_python_env':
      case 'theme':
        if (typeof value !== 'string' || !value.trim()) return false
        break
      case 'edition':
        if (!VALID_EDITIONS.has(/** @type {IEdition} */ (value))) return false
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
  const setting = new Setting({ reporter })
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
  const app_edition_tmux = /** @type {IAppEdition | undefined} */ (getArg('--set-tmux-edition'))
  const app_edition_nvim = /** @type {IAppEdition | undefined} */ (getArg('--set-nvim-edition'))

  if (edition || theme || app_edition_tmux || app_edition_nvim) {
    await setting.save({ edition, theme, app_edition_tmux, app_edition_nvim })
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
