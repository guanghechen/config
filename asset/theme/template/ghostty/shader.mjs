import { randomUUID } from 'node:crypto'
import fs from 'node:fs/promises'
import path from 'node:path'
import { setTimeout as sleep } from 'node:timers/promises'

import { XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR } from '#env'

/**
 * Stores the Ghostty background shader selection in its active config and
 * derives the shader or wallpaper config from the appearance. Theme apply and
 * the shader CLI share this writer. Importing this module does not mutate state.
 */

const WALLPAPER_PATHS = {
  dark: path.join(XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR, 'Flowerlit-Prayers.png'),
  light: path.join(XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR, 'Barrett-Girl.jpg'),
}

export const GHOSTTY_SHADERS = Object.freeze([
  'off',
  'cubes',
  'fireworks-rockets',
  'gears-and-belts',
  'inside-the-matrix',
  'matrix-hallway',
  'mnoise',
  'neuro-noise',
  'sparks-from-fire',
  'starfield',
])

const LOCK_RETRY_MS = 25
const LOCK_TIMEOUT_MS = 5_000

/**
 * @typedef {'dark'|'light'} IAppearance
 * @typedef {Object} IShaderStatePaths
 * @property {string} localDir
 * @property {string} theme
 * @property {string} active
 * @property {string} appearance
 * @property {string} lock
 */

/** @param {string} home @return {IShaderStatePaths} */
function resolvePaths(home) {
  const localDir = path.join(home, 'local')
  return {
    localDir,
    theme: path.join(localDir, 'theme.conf'),
    active: path.join(localDir, 'shader.conf'),
    appearance: path.join(localDir, 'appearance'),
    lock: path.join(localDir, '.shader-state.lock'),
  }
}

/** @param {string} appearance @return {asserts appearance is IAppearance} */
function assertAppearance(appearance) {
  if (appearance !== 'dark' && appearance !== 'light') {
    throw new Error(`Invalid Ghostty appearance: ${appearance || '<empty>'}`)
  }
}

/** @param {unknown} error @param {string} code */
function hasErrorCode(error, code) {
  return error instanceof Error && 'code' in error && error.code === code
}

/** @param {string} filepath @return {Promise<string|undefined>} */
async function readOptionalFile(filepath) {
  try {
    return await fs.readFile(filepath, 'utf8')
  } catch (error) {
    if (hasErrorCode(error, 'ENOENT')) return undefined
    throw error
  }
}

/** @param {string} filepath */
async function unlinkIfExists(filepath) {
  try {
    await fs.unlink(filepath)
  } catch (error) {
    if (!hasErrorCode(error, 'ENOENT')) throw error
  }
}

/** @param {string} filepath @param {string} content */
async function replaceFileAtomic(filepath, content) {
  const temporary = `${filepath}.${randomUUID()}.tmp`
  const handle = await fs.open(temporary, 'wx')
  try {
    try {
      await handle.writeFile(content, 'utf8')
    } finally {
      await handle.close()
    }
    await fs.rename(temporary, filepath)
  } catch (error) {
    await unlinkIfExists(temporary)
    throw error
  }
}

/** @param {string} content @return {string} */
function parseShaderConfig(content) {
  const config = content.trim()
  if (config === 'background-image =' ||
    Object.values(WALLPAPER_PATHS).some(filepath => config === `background-image = ${filepath}`)) {
    return 'off'
  }

  const match = /^background-image =\ncustom-shader = \.\.\/shaders\/(?:dark|light)\/([a-z0-9-]+)\.glsl$/.exec(config)
  if (!match) throw new Error('Unrecognized Ghostty shader config; refusing to overwrite it')
  const shader = match[1]
  if (shader === 'off' || !GHOSTTY_SHADERS.includes(shader)) {
    throw new Error(`Unknown Ghostty shader in config: ${shader}`)
  }
  return shader
}

/** @param {string} shader @param {IAppearance} appearance */
function renderActiveConfig(shader, appearance) {
  if (shader === 'off') {
    return `background-image = ${WALLPAPER_PATHS[appearance]}\n`
  }
  return `background-image =\ncustom-shader = ../shaders/${appearance}/${shader}.glsl\n`
}

/** @param {IShaderStatePaths} paths @return {Promise<IAppearance>} */
async function requireAppearance(paths) {
  const content = await readOptionalFile(paths.appearance)
  if (content === undefined) {
    throw new Error("Cannot determine Ghostty appearance. Run 'ghc-theme apply' first.")
  }
  const appearance = content.trim()
  assertAppearance(appearance)
  return appearance
}

/** @param {string} home @param {IAppearance} appearance @param {string} shader */
async function validateBackgroundFile(home, appearance, shader) {
  const filepath = shader === 'off'
    ? WALLPAPER_PATHS[appearance]
    : path.join(home, 'shaders', appearance, `${shader}.glsl`)
  try {
    const stat = await fs.stat(filepath)
    if (stat.isFile()) return
  } catch (error) {
    if (!hasErrorCode(error, 'ENOENT')) throw error
  }
  throw new Error(`Cannot find ${shader === 'off' ? 'wallpaper' : 'shader'}: ${filepath}`)
}

/** @param {IShaderStatePaths} paths @return {Promise<string>} */
async function readShaderSelection(paths) {
  const content = await readOptionalFile(paths.active)
  return content === undefined ? 'off' : parseShaderConfig(content)
}

/**
 * Roll back completed replacements on ordinary failures. Snapshots stay in
 * memory; process termination can leave mixed state that needs a new apply.
 * @param {Array<[string, string]>} updates
 */
async function commitState(updates) {
  const snapshots = await Promise.all(updates.map(async ([filepath]) =>
    /** @type {[string, string|undefined]} */ ([filepath, await readOptionalFile(filepath)])))
  let completed = 0
  try {
    for (const [filepath, content] of updates) {
      await replaceFileAtomic(filepath, content)
      completed += 1
    }
  } catch (error) {
    const failures = [error]
    for (const [filepath, content] of snapshots.slice(0, completed).reverse()) {
      try {
        if (content === undefined) await unlinkIfExists(filepath)
        else await replaceFileAtomic(filepath, content)
      } catch (rollbackError) {
        failures.push(rollbackError)
      }
    }
    if (failures.length > 1) {
      throw new AggregateError(failures, 'Ghostty state update and rollback failed; reapply the theme to repair state')
    }
    throw error
  }
}

/**
 * Serialize theme and shader updates across processes. A leftover lock is never
 * reclaimed automatically; its PID is diagnostic, not an ownership lease.
 * @template T
 * @param {string} home
 * @param {(paths: IShaderStatePaths) => Promise<T>} task
 * @return {Promise<T>}
 */
async function withGhosttyShaderStateLock(home, task) {
  const paths = resolvePaths(home)
  await fs.mkdir(paths.localDir, { recursive: true })
  const deadline = Date.now() + LOCK_TIMEOUT_MS
  let lock
  while (!lock) {
    try {
      lock = await fs.open(paths.lock, 'wx')
    } catch (error) {
      if (!hasErrorCode(error, 'EEXIST')) throw error
      if (Date.now() >= deadline) {
        throw new Error(`Timed out waiting for Ghostty state lock: ${paths.lock}`)
      }
      await sleep(LOCK_RETRY_MS)
    }
  }

  try {
    await lock.writeFile(`${process.pid}\n`, 'utf8')
    return await task(paths)
  } finally {
    await lock.close()
    await unlinkIfExists(paths.lock)
  }
}

/**
 * Validate the shared selection in the requested appearance without applying
 * the theme.
 *
 * @param {{home: string, appearance: IAppearance}} params
 */
export async function validateGhosttyThemeAppearance({ home, appearance }) {
  assertAppearance(appearance)
  return withGhosttyShaderStateLock(home, async paths => {
    const shader = await readShaderSelection(paths)
    await validateBackgroundFile(home, appearance, shader)
    return { appearance, shader }
  })
}

/**
 * Changing appearance keeps the shader name and derives the background config.
 * Ordinary write failures roll back the theme, active config, and appearance.
 *
 * @param {{home: string, appearance: IAppearance, themeContent: string}} params
 */
export async function applyGhosttyThemeAppearance({ home, appearance, themeContent }) {
  assertAppearance(appearance)
  return withGhosttyShaderStateLock(home, async paths => {
    const shader = await readShaderSelection(paths)
    await validateBackgroundFile(home, appearance, shader)
    /** @type {Array<[string, string]>} */
    const updates = [
      [paths.theme, themeContent],
      [paths.active, renderActiveConfig(shader, appearance)],
      [paths.appearance, `${appearance}\n`],
    ]
    await commitState(updates)
    return { appearance, shader }
  })
}

/**
 * @param {{home: string, shader?: string, previous?: boolean, next?: boolean}} params
 */
export async function selectGhosttyShader({ home, shader, previous = false, next = false }) {
  if (previous && next) throw new Error('--prev and --next cannot be used together')
  if (shader && (previous || next)) {
    throw new Error('A shader name cannot be combined with --prev or --next')
  }
  if (shader && !GHOSTTY_SHADERS.includes(shader)) {
    throw new Error(`Unknown Ghostty shader: ${shader}`)
  }

  return withGhosttyShaderStateLock(home, async paths => {
    const appearance = await requireAppearance(paths)
    const currentShader = await readShaderSelection(paths)
    let selectedShader = shader
    if (!selectedShader) {
      const index = GHOSTTY_SHADERS.indexOf(currentShader)
      const offset = previous ? -1 : 1
      selectedShader = GHOSTTY_SHADERS[(index + offset + GHOSTTY_SHADERS.length) % GHOSTTY_SHADERS.length]
    }
    // Explicit replacement must not depend on the previous shader file existing.
    await validateBackgroundFile(home, appearance, selectedShader)
    await replaceFileAtomic(paths.active, renderActiveConfig(selectedShader, appearance))
    return { appearance, shader: selectedShader }
  })
}
