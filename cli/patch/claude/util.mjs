import { execSync } from 'node:child_process'
import { existsSync, readFileSync, realpathSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import * as chalk from '#chalk'
import { PLATFORM } from '#env'

/**
 * @typedef {import('./types.mjs').IApplyOptions} IApplyOptions
 * @typedef {import('./types.mjs').IMatch} IMatch
 * @typedef {import('./types.mjs').IPatch} IPatch
 */

// ─── CLI ─────────────────────────────────────────────────────────────────────

/**
 * @returns {string | null}
 */
export function getCliPath() {
  const isNativeWindows = PLATFORM === 'win'

  try {
    const cmd = isNativeWindows ? 'where.exe claude' : 'which claude'
    const which = execSync(cmd, { encoding: 'utf-8' }).trim().split(/\r?\n/)[0]

    if (isNativeWindows) {
      const cliJs = join(dirname(which), 'node_modules', '@anthropic-ai', 'claude-code', 'cli.js')
      return existsSync(cliJs) ? cliJs : null
    }

    return realpathSync(which)
  } catch {
    return null
  }
}

/**
 * @returns {string | null}
 */
export function getCliVersion() {
  try {
    const output = execSync('claude --version', { encoding: 'utf-8' }).trim()
    return output.match(/^(\d+\.\d+\.\d+)/)?.[1] ?? null
  } catch {
    return null
  }
}

// ─── Patch ───────────────────────────────────────────────────────────────────

/**
 * @param {IApplyOptions} options
 * @returns {void}
 */
export function applyPatches(options) {
  const { patches, stopOnFirst = false } = options

  const cliPath = getCliPath()
  if (!cliPath) {
    console.error('Claude Code not found')
    process.exit(1)
  }

  let content = readFileSync(cliPath, 'utf-8')
  const cliVersion = getCliVersion()

  console.log(`File: ${cliPath}`)
  console.log(`Version: ${cliVersion || 'unknown'}\n`)

  const applicablePatches = patches.filter((p) => p.platform.includes(PLATFORM))
  let patchedCount = 0

  for (const patch of applicablePatches) {
    const label = `${patch.name}@${patch.version}`

    if (patch.version !== cliVersion) {
      if (!stopOnFirst) console.log(`[${label}] ${chalk.dim('Version mismatch, skipping')}`)
      continue
    }

    const result = applyPatch(content, patch)

    if (result === null) {
      if (patch.verify(content)) {
        console.log(`[${label}] ${chalk.yellow('Already patched')}`)
        if (stopOnFirst) process.exit(0)
      } else if (!stopOnFirst) {
        console.log(`[${label}] ${chalk.red('Pattern not found')}`)
      }
      continue
    }

    console.log(`[${label}] ${chalk.green('Patched')}`)
    content = result
    patchedCount++

    if (stopOnFirst) break
  }

  if (patchedCount === 0) {
    if (stopOnFirst) {
      const versionMatched = applicablePatches.some((p) => p.version === cliVersion)
      console.error(versionMatched ? 'Pattern not found' : `No patch available for version ${cliVersion}`)
      console.error('Supported versions:')
      applicablePatches.forEach((p) => console.error(`  - ${p.version}`))
      process.exit(1)
    }
    process.exit(0)
  }

  writeFileSync(cliPath, content)

  const verifyContent = readFileSync(cliPath, 'utf-8')
  const failed = applicablePatches.filter((p) => p.version === cliVersion && !p.verify(verifyContent))

  if (failed.length === 0) {
    console.log(`\n${chalk.green(`Patched ${patchedCount} location(s) successfully`)}`)
  } else {
    console.error(`\n${chalk.red('Patch verification failed:')}`)
    failed.forEach((p) => console.error(`  - ${p.name}`))
    process.exit(1)
  }
}

/**
 * @param {string} content
 * @param {IMatch[]} matches
 * @param {(m: IMatch) => string} getReplacement
 * @returns {string}
 */
export function replaceAll(content, matches, getReplacement) {
  let result = content
  for (const m of matches.toReversed()) {
    result = result.slice(0, m.offset_start) + getReplacement(m) + result.slice(m.offset_end)
  }
  return result
}

/**
 * @param {string} content
 * @param {IPatch} patch
 * @returns {string | null}
 */
function applyPatch(content, patch) {
  if (patch.verify(content)) return null

  const matches = findMatches(content, patch.search)
  if (matches.length === 0) return null

  return patch.replace(content, matches)
}

/**
 * @param {string} content
 * @param {string | RegExp} search
 * @returns {IMatch[]}
 */
function findMatches(content, search) {
  /** @type {IMatch[]} */
  const matches = []

  if (typeof search === 'string') {
    let index = 0
    while ((index = content.indexOf(search, index)) !== -1) {
      matches.push({
        matched_text: search,
        matched_groups: [],
        offset_start: index,
        offset_end: index + search.length,
      })
      index += search.length
    }
  } else {
    const regex = new RegExp(search.source, search.flags.replace('g', '') + 'g')
    let match
    while ((match = regex.exec(content)) !== null) {
      matches.push({
        matched_text: match[0],
        matched_groups: match.slice(1),
        offset_start: match.index,
        offset_end: match.index + match[0].length,
      })
    }
  }

  return matches
}
