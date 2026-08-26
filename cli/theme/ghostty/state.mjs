import { randomUUID } from 'node:crypto'
import fs from 'node:fs/promises'
import path from 'node:path'

export const GHOSTTY_SHADERS = Object.freeze({
  dark: Object.freeze([
    'off',
    'cubes',
    'fireworks-rockets',
    'gears-and-belts',
    'inside-the-matrix',
    'matrix-hallway',
    'mnoise',
    'sparks-from-fire',
    'starfield',
  ]),
  light: Object.freeze([
    'off',
    'cubes-light',
    'inside-the-matrix-light',
  ]),
})

const APPEARANCES = new Set(Object.keys(GHOSTTY_SHADERS))
const LOCK_RETRY_MS = 25
const LOCK_STALE_MS = 30_000
const LOCK_TIMEOUT_MS = 5_000

/**
 * @typedef {'dark'|'light'} IAppearance
 * @typedef {Object} IShaderStatePaths
 * @property {string} home
 * @property {string} localDir
 * @property {string} theme
 * @property {string} active
 * @property {string} appearance
 * @property {string} lock
 * @property {string} recoveryLock
 * @property {string} transaction
 * @property {Record<IAppearance, string>} saved
 */

/** @param {string} home @return {IShaderStatePaths} */
function resolvePaths(home) {
  const localDir = path.join(home, 'local')
  return {
    home,
    localDir,
    theme: path.join(localDir, 'theme.conf'),
    active: path.join(localDir, 'shader.conf'),
    appearance: path.join(localDir, 'appearance'),
    lock: path.join(localDir, '.shader-state.lock'),
    recoveryLock: path.join(localDir, '.shader-state.recovery.lock'),
    transaction: path.join(localDir, '.shader-state.transaction.json'),
    saved: {
      dark: path.join(localDir, 'shader-dark.conf'),
      light: path.join(localDir, 'shader-light.conf'),
    },
  }
}

/** @param {string} appearance @return {asserts appearance is IAppearance} */
function assertAppearance(appearance) {
  if (!APPEARANCES.has(appearance)) {
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

/** @param {string} directory */
async function syncDirectory(directory) {
  if (process.platform === 'win32') return
  const handle = await fs.open(directory, 'r')
  try {
    await handle.sync()
  } finally {
    await handle.close()
  }
}

/** @param {string} filepath */
async function unlinkFileDurable(filepath) {
  try {
    await fs.unlink(filepath)
    await syncDirectory(path.dirname(filepath))
  } catch (error) {
    if (!hasErrorCode(error, 'ENOENT')) throw error
  }
}

/** @param {string} filepath @param {string} content */
async function stageFile(filepath, content) {
  const tempPath = path.join(
    path.dirname(filepath),
    `.${path.basename(filepath)}.${process.pid}.${randomUUID()}.tmp`,
  )
  const handle = await fs.open(tempPath, 'wx')
  try {
    await handle.writeFile(content, 'utf8')
    await handle.sync()
  } catch (error) {
    await handle.close()
    await unlinkIfExists(tempPath)
    throw error
  }
  await handle.close()
  return tempPath
}

/** @param {string} filepath @param {string} content */
async function replaceFileAtomic(filepath, content) {
  const tempPath = await stageFile(filepath, content)
  try {
    await fs.rename(tempPath, filepath)
    await syncDirectory(path.dirname(filepath))
  } finally {
    await unlinkIfExists(tempPath)
  }
}

/** @param {string} filepath @param {string|undefined} content */
async function restoreOptionalFile(filepath, content) {
  if (content === undefined) {
    await unlinkFileDurable(filepath)
  } else {
    await replaceFileAtomic(filepath, content)
  }
}

/** @param {string} content */
function parseShaderConfig(content) {
  if (content.trim() === '') return 'off'

  const match = /^custom-shader = \.\.\/shaders\/([a-z0-9-]+)\.glsl\n?$/.exec(content)
  if (!match) throw new Error('Unrecognized Ghostty shader config; refusing to overwrite it')

  const shader = match[1]
  const known = Object.values(GHOSTTY_SHADERS).some(shaders => shaders.includes(shader))
  if (!known) throw new Error(`Unknown Ghostty shader in config: ${shader}`)
  return shader
}

/** @param {string} shader */
function renderShaderConfig(shader) {
  return shader === 'off' ? '' : `custom-shader = ../shaders/${shader}.glsl\n`
}

/** @param {string} shader @return {IAppearance|undefined} */
function resolveShaderAppearance(shader) {
  if (shader === 'off') return undefined
  if (GHOSTTY_SHADERS.dark.includes(shader)) return 'dark'
  if (GHOSTTY_SHADERS.light.includes(shader)) return 'light'
  return undefined
}

/** @param {IShaderStatePaths} paths @return {Promise<IAppearance|undefined>} */
async function readAppearance(paths) {
  const content = await readOptionalFile(paths.appearance)
  if (content === undefined) return undefined
  const appearance = content.trim()
  assertAppearance(appearance)
  return appearance
}

/** @param {IShaderStatePaths} paths @return {Promise<IAppearance>} */
async function requireAppearance(paths) {
  const appearance = await readAppearance(paths)
  if (!appearance) {
    throw new Error("Cannot determine Ghostty appearance. Run 'ghc-theme apply' first.")
  }
  return appearance
}

/** @param {string} home @param {string} shader */
async function validateShaderFile(home, shader) {
  if (shader === 'off') return

  const shaderPath = path.join(home, 'shaders', `${shader}.glsl`)
  try {
    const stat = await fs.stat(shaderPath)
    if (stat.isFile()) return
  } catch (error) {
    if (!hasErrorCode(error, 'ENOENT')) throw error
  }
  throw new Error(`Cannot find shader: ${shaderPath}`)
}

/**
 * Resolve the legacy active selection without mutating state.
 *
 * @param {IShaderStatePaths} paths
 * @param {IAppearance} targetAppearance
 */
async function resolveLegacyState(paths, targetAppearance) {
  const saved = {
    dark: await readOptionalFile(paths.saved.dark),
    light: await readOptionalFile(paths.saved.light),
  }
  if (saved.dark !== undefined && saved.light !== undefined) {
    return { saved, migratedAppearance: undefined }
  }

  const activeContent = await readOptionalFile(paths.active)
  if (activeContent === undefined) {
    return { saved, migratedAppearance: undefined }
  }

  const activeShader = parseShaderConfig(activeContent)
  const markedAppearance = await readAppearance(paths)
  const activeAppearance = resolveShaderAppearance(activeShader) ?? markedAppearance ?? targetAppearance

  if (saved[activeAppearance] === undefined) {
    saved[activeAppearance] = renderShaderConfig(activeShader)
    return { saved, migratedAppearance: activeAppearance }
  }
  return { saved, migratedAppearance: undefined }
}

/**
 * Preserve the pre-appearance shader selection before any derived active file
 * is replaced. Migration is idempotent and only recognizes the canonical
 * config emitted by the previous Fish implementation.
 *
 * @param {IShaderStatePaths} paths
 * @param {IAppearance} targetAppearance
 */
async function migrateLegacyState(paths, targetAppearance) {
  const { saved, migratedAppearance } = await resolveLegacyState(
    paths,
    targetAppearance,
  )
  if (migratedAppearance) {
    await replaceFileAtomic(
      paths.saved[migratedAppearance],
      /** @type {string} */ (saved[migratedAppearance]),
    )
  }
  return saved
}

/**
 * @param {IShaderStatePaths} paths
 * @param {Record<IAppearance, string|undefined>} saved
 * @param {IAppearance} appearance
 */
async function ensureSavedState(paths, saved, appearance) {
  if (saved[appearance] === undefined) {
    await replaceFileAtomic(paths.saved[appearance], '')
    saved[appearance] = ''
  }
  return /** @type {string} */ (saved[appearance])
}

/** @typedef {'theme'|'active'|'appearance'|'saved-dark'|'saved-light'} ITransactionTarget */

/** @param {IShaderStatePaths} paths @param {ITransactionTarget} target */
function resolveTransactionTarget(paths, target) {
  if (target === 'theme') return paths.theme
  if (target === 'active') return paths.active
  if (target === 'appearance') return paths.appearance
  if (target === 'saved-dark') return paths.saved.dark
  if (target === 'saved-light') return paths.saved.light
  throw new Error(`Invalid Ghostty shader transaction target: ${target}`)
}

/**
 * @param {IShaderStatePaths} paths
 * @param {ITransactionTarget[]} targets
 */
async function beginTransaction(paths, targets) {
  const files = []
  for (const target of targets) {
    const content = await readOptionalFile(resolveTransactionTarget(paths, target))
    files.push({ target, existed: content !== undefined, content: content ?? '' })
  }
  await replaceFileAtomic(
    paths.transaction,
    `${JSON.stringify({ version: 1, files })}\n`,
  )
}

/** @param {IShaderStatePaths} paths */
async function recoverPendingTransaction(paths) {
  const content = await readOptionalFile(paths.transaction)
  if (content === undefined) return false

  let transaction
  try {
    transaction = JSON.parse(content)
  } catch {
    throw new Error(`Invalid Ghostty shader transaction journal: ${paths.transaction}`)
  }

  if (transaction?.version !== 1 || !Array.isArray(transaction.files)) {
    throw new Error(`Invalid Ghostty shader transaction journal: ${paths.transaction}`)
  }

  const restored = new Set()
  for (const file of transaction.files) {
    const { target, existed, content: previousContent } = file ?? {}
    if (
      typeof target !== 'string' ||
      restored.has(target) ||
      typeof existed !== 'boolean' ||
      typeof previousContent !== 'string'
    ) {
      throw new Error(`Invalid Ghostty shader transaction journal: ${paths.transaction}`)
    }

    const filepath = resolveTransactionTarget(
      paths,
      /** @type {ITransactionTarget} */ (target),
    )
    await restoreOptionalFile(filepath, existed ? previousContent : undefined)
    restored.add(target)
  }

  await unlinkFileDurable(paths.transaction)
  return true
}

/**
 * @template T
 * @param {IShaderStatePaths} paths
 * @param {ITransactionTarget[]} targets
 * @param {() => Promise<T>} task
 * @return {Promise<T>}
 */
async function runTransaction(paths, targets, task) {
  await beginTransaction(paths, targets)
  try {
    const result = await task()
    await unlinkFileDurable(paths.transaction)
    return result
  } catch (error) {
    try {
      await recoverPendingTransaction(paths)
    } catch (recoveryError) {
      throw new AggregateError(
        [error, recoveryError],
        'Ghostty shader transaction failed and could not be recovered',
      )
    }
    throw error
  }
}

/**
 * @param {IShaderStatePaths} paths
 * @param {IAppearance} appearance
 * @param {string} content
 */
async function commitShaderSelection(paths, appearance, content) {
  await runTransaction(paths, [`saved-${appearance}`, 'active'], async () => {
    await replaceFileAtomic(paths.saved[appearance], content)
    await replaceFileAtomic(paths.active, content)
  })
}

/**
 * @param {IShaderStatePaths} paths
 * @param {IAppearance} appearance
 * @param {string} content
 */
async function commitAppearanceActivation(paths, appearance, content) {
  await runTransaction(paths, ['active', 'appearance'], async () => {
    await replaceFileAtomic(paths.active, content)
    await replaceFileAtomic(paths.appearance, `${appearance}\n`)
  })
}

/**
 * @param {IShaderStatePaths} paths
 * @param {IAppearance} appearance
 * @param {string} shaderContent
 * @param {string} themeContent
 */
async function commitThemeAppearance(paths, appearance, shaderContent, themeContent) {
  await runTransaction(paths, ['theme', 'active', 'appearance'], async () => {
    await replaceFileAtomic(paths.theme, themeContent)
    await replaceFileAtomic(paths.active, shaderContent)
    await replaceFileAtomic(paths.appearance, `${appearance}\n`)
  })
}

/** @param {number} duration */
function sleep(duration) {
  return new Promise(resolve => setTimeout(resolve, duration))
}

/** @param {string} content */
function inspectLockOwner(content) {
  const ownerPid = Number.parseInt(content, 10)
  if (!Number.isInteger(ownerPid) || ownerPid <= 0) {
    return { known: false, dead: false }
  }

  try {
    process.kill(ownerPid, 0)
    return { known: true, dead: false }
  } catch (error) {
    return { known: true, dead: hasErrorCode(error, 'ESRCH') }
  }
}

/** @param {string} lockPath @param {number} staleMs */
async function inspectLock(lockPath, staleMs) {
  try {
    const content = await fs.readFile(lockPath, 'utf8')
    const stat = await fs.stat(lockPath)
    const owner = inspectLockOwner(content)
    const ageMs = Date.now() - stat.mtimeMs
    return {
      exists: true,
      content,
      reclaimable: owner.dead,
      malformedStale: !owner.known && ageMs > staleMs,
    }
  } catch (error) {
    if (hasErrorCode(error, 'ENOENT')) {
      return {
        exists: false,
        content: undefined,
        reclaimable: true,
        malformedStale: false,
      }
    }
    throw error
  }
}

/** @param {string} lockPath @param {string} lockToken */
async function createOwnedLock(lockPath, lockToken) {
  const candidatePath = await stageFile(
    lockPath,
    `${process.pid} ${lockToken}\n`,
  )

  try {
    await fs.link(candidatePath, lockPath)
  } catch (error) {
    try {
      await unlinkIfExists(candidatePath)
    } catch (cleanupError) {
      throw new AggregateError(
        [error, cleanupError],
        'Ghostty shader lock creation and candidate cleanup failed',
      )
    }
    throw error
  }

  try {
    await unlinkIfExists(candidatePath)
  } catch (error) {
    try {
      await releaseLock(lockPath, lockToken)
    } catch (releaseError) {
      throw new AggregateError(
        [error, releaseError],
        'Ghostty shader lock candidate cleanup and lock release failed',
      )
    }
    throw error
  }
}

/** @param {string} lockPath @param {string} lockToken */
async function releaseLock(lockPath, lockToken) {
  const content = await readOptionalFile(lockPath)
  if (content?.trim() === `${process.pid} ${lockToken}`) {
    await unlinkIfExists(lockPath)
  }
}

/** @param {string} lockPath @param {string} lockToken */
async function ownsLock(lockPath, lockToken) {
  const content = await readOptionalFile(lockPath)
  return content?.trim() === `${process.pid} ${lockToken}`
}

/**
 * Serialize stale-main-lock recovery with a separately owned recovery lock.
 * Both lock records are fully initialized before their paths become visible.
 *
 * @param {IShaderStatePaths} paths
 * @param {number} staleMs
 */
async function reclaimAbandonedLock(paths, staleMs) {
  const recovery = await inspectLock(paths.recoveryLock, staleMs)
  if (recovery.exists) {
    if (recovery.malformedStale) {
      throw new Error(
        `Malformed Ghostty shader recovery lock requires manual removal: ${paths.recoveryLock}`,
      )
    }
    if (recovery.reclaimable) {
      throw new Error(
        `Abandoned Ghostty shader recovery lock requires manual removal after verifying no shader operation is running: ${paths.recoveryLock}`,
      )
    }
    return false
  }

  const observed = await inspectLock(paths.lock, staleMs)
  if (!observed.exists) return true
  if (observed.malformedStale) {
    throw new Error(
      `Malformed Ghostty shader state lock requires manual removal: ${paths.lock}`,
    )
  }
  if (!observed.reclaimable) return false

  const recoveryToken = randomUUID()
  try {
    await createOwnedLock(paths.recoveryLock, recoveryToken)
  } catch (error) {
    if (hasErrorCode(error, 'EEXIST')) return false
    throw error
  }

  try {
    const current = await inspectLock(paths.lock, staleMs)
    if (!current.exists) return true
    if (current.content !== observed.content) return false
    if (!current.reclaimable) return false
    if (!await ownsLock(paths.recoveryLock, recoveryToken)) return false
    await unlinkIfExists(paths.lock)
    return true
  } finally {
    await releaseLock(paths.recoveryLock, recoveryToken)
  }
}

/**
 * Serialize every shader-state mutation across Node processes.
 *
 * @template T
 * @param {string} home
 * @param {(paths: IShaderStatePaths) => Promise<T>} task
 * @param {{timeoutMs?: number, staleMs?: number}} [options]
 * @return {Promise<T>}
 */
export async function withGhosttyShaderStateLock(home, task, options = {}) {
  const paths = resolvePaths(home)
  const timeoutMs = options.timeoutMs ?? LOCK_TIMEOUT_MS
  const staleMs = options.staleMs ?? LOCK_STALE_MS
  const deadline = Date.now() + timeoutMs
  const lockToken = randomUUID()
  await fs.mkdir(paths.localDir, { recursive: true })

  let lockOwned = false
  while (!lockOwned) {
    try {
      await createOwnedLock(paths.lock, lockToken)
      lockOwned = true
      if (await readOptionalFile(paths.recoveryLock) !== undefined) {
        await releaseLock(paths.lock, lockToken)
        lockOwned = false
        await reclaimAbandonedLock(paths, staleMs)
      }
    } catch (error) {
      if (!hasErrorCode(error, 'EEXIST')) throw error
      await reclaimAbandonedLock(paths, staleMs)
    }

    if (!lockOwned) {
      if (Date.now() >= deadline) {
        throw new Error(`Timed out waiting for Ghostty shader state lock: ${paths.lock}`)
      }
      await sleep(Math.min(LOCK_RETRY_MS, Math.max(1, deadline - Date.now())))
    }
  }

  let result
  let taskError
  try {
    await recoverPendingTransaction(paths)
    result = await task(paths)
  } catch (error) {
    taskError = error
  }

  let releaseError
  try {
    await releaseLock(paths.lock, lockToken)
  } catch (error) {
    releaseError = error
  }

  if (taskError && releaseError) {
    throw new AggregateError([taskError, releaseError], 'Ghostty shader operation and lock release failed')
  }
  if (taskError) throw taskError
  if (releaseError) throw releaseError
  return /** @type {T} */ (result)
}

/** @param {{home: string}} params */
export async function listGhosttyShaders({ home }) {
  const paths = resolvePaths(home)
  const appearance = await requireAppearance(paths)
  return [...GHOSTTY_SHADERS[appearance]]
}

/**
 * @param {string} home
 * @param {IAppearance} appearance
 * @param {string} content
 */
async function validateAppearanceContent(home, appearance, content) {
  const shader = parseShaderConfig(content)
  if (!GHOSTTY_SHADERS[appearance].includes(shader)) {
    throw new Error(`Shader '${shader}' is not available for the ${appearance} appearance`)
  }
  await validateShaderFile(home, shader)
  return shader
}

/**
 * @param {IShaderStatePaths} paths
 * @param {string} home
 * @param {IAppearance} appearance
 */
async function prepareAppearanceActivation(paths, home, appearance) {
  const saved = await migrateLegacyState(paths, appearance)
  const content = await ensureSavedState(paths, saved, appearance)
  const shader = await validateAppearanceContent(home, appearance, content)
  return { content, shader }
}

/**
 * Validate the currently selected shader for a theme appearance without
 * applying the requested theme.
 *
 * @param {{home: string, appearance: IAppearance}} params
 */
export async function validateGhosttyThemeAppearance({ home, appearance }) {
  assertAppearance(appearance)
  return withGhosttyShaderStateLock(home, async paths => {
    const { saved } = await resolveLegacyState(paths, appearance)
    const content = saved[appearance] ?? ''
    const shader = await validateAppearanceContent(home, appearance, content)
    return { appearance, shader }
  })
}

/** @param {{home: string, appearance: IAppearance}} params */
export async function activateGhosttyShaderAppearance({ home, appearance }) {
  assertAppearance(appearance)
  return withGhosttyShaderStateLock(home, async paths => {
    const { content, shader } = await prepareAppearanceActivation(
      paths,
      home,
      appearance,
    )
    await commitAppearanceActivation(paths, appearance, content)
    return { appearance, shader }
  })
}

/**
 * Apply the rendered Ghostty theme and its shader appearance as one state
 * transition owned by this module.
 *
 * @param {{home: string, appearance: IAppearance, themeContent: string}} params
 */
export async function applyGhosttyThemeAppearance({
  home,
  appearance,
  themeContent,
}) {
  assertAppearance(appearance)
  return withGhosttyShaderStateLock(home, async paths => {
    const { content, shader } = await prepareAppearanceActivation(
      paths,
      home,
      appearance,
    )
    await commitThemeAppearance(paths, appearance, content, themeContent)
    return { appearance, shader }
  })
}

/**
 * @param {{home: string, shader?: string, previous?: boolean, next?: boolean}} params
 */
export async function selectGhosttyShader({
  home,
  shader,
  previous = false,
  next = false,
}) {
  if (previous && next) throw new Error('--prev and --next cannot be used together')
  if (shader && (previous || next)) {
    throw new Error('A shader name cannot be combined with --prev or --next')
  }

  return withGhosttyShaderStateLock(home, async paths => {
    const appearance = await requireAppearance(paths)
    const shaders = GHOSTTY_SHADERS[appearance]
    if (shader && !shaders.includes(shader)) {
      throw new Error(`Shader '${shader}' is not available for the ${appearance} appearance`)
    }
    if (shader) await validateShaderFile(home, shader)

    const saved = await migrateLegacyState(paths, appearance)
    const currentContent = await ensureSavedState(paths, saved, appearance)
    const currentShader = parseShaderConfig(currentContent)

    if (!shaders.includes(currentShader)) {
      throw new Error(`Shader '${currentShader}' is not available for the ${appearance} appearance`)
    }

    let selectedShader = shader
    if (!selectedShader) {
      const index = shaders.indexOf(currentShader)
      const offset = previous ? -1 : 1
      selectedShader = shaders[(index + offset + shaders.length) % shaders.length]
    }

    if (!shader) await validateShaderFile(home, selectedShader)
    const content = renderShaderConfig(selectedShader)
    await commitShaderSelection(paths, appearance, content)
    return { appearance, shader: selectedShader }
  })
}
