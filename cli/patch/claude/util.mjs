import { execSync } from 'node:child_process'
import {
  chmodSync,
  closeSync,
  existsSync,
  openSync,
  readFileSync,
  readSync,
  realpathSync,
  renameSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from 'node:fs'
import { basename, dirname, join } from 'node:path'
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
    const output = execSync(cmd, { encoding: 'utf-8' })

    if (isNativeWindows) {
      return getWindowsCliPath(output)
    }

    const which = output.trim().split(/\r?\n/)[0]
    return realpathSync(which)
  } catch {
    return null
  }
}

/**
 * @param {string} whereOutput
 * @returns {string | null}
 */
function getWindowsCliPath(whereOutput) {
  for (const which of whereOutput.trim().split(/\r?\n/).filter(Boolean)) {
    const binDir = dirname(which)
    const packageDirs = [
      join(binDir, 'node_modules', '@anthropic-ai', 'claude-code'),
      join(binDir, '..', '@anthropic-ai', 'claude-code'),
    ]
    const candidates = [
      ...(basename(which).toLowerCase() === 'claude.exe' ? [which] : []),
      ...packageDirs.flatMap((packageDir) => [join(packageDir, 'bin', 'claude.exe'), join(packageDir, 'cli.js')]),
    ]

    for (const candidate of candidates) {
      if (existsSync(candidate)) return realpathSync(candidate)
    }
  }

  return null
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
 * Detect file encoding for read/write.
 * Native binaries must use latin1 to preserve byte-level fidelity;
 * plain JS files use utf-8.
 *
 * @param {string} filePath
 * @returns {'latin1' | 'utf-8'}
 */
function detectEncoding(filePath) {
  const header = Buffer.alloc(4)
  const fd = openSync(filePath, 'r')
  try {
    readSync(fd, header, 0, 4, 0)
  } finally {
    closeSync(fd)
  }

  const magic = header.readUInt32BE(0)
  const isElf = magic === 0x7f454c46
  const isPe = header[0] === 0x4d && header[1] === 0x5a
  if (isElf || isPe) return 'latin1'
  return 'utf-8'
}

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

  const encoding = detectEncoding(cliPath)
  let content = readFileSync(cliPath, encoding)
  const cliVersion = getCliVersion()

  console.log(`File: ${cliPath}`)
  console.log(`Version: ${cliVersion || 'unknown'}`)
  console.log(`Encoding: ${encoding}\n`)

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

  writePatched(cliPath, content, encoding)

  const verifyContent = readFileSync(cliPath, encoding)
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
 * Write patched content to file.
 * For ELF binaries on Linux, direct write fails with ETXTBSY when the binary
 * is running. Work around by writing to a temp file, unlinking the original,
 * then renaming the temp into place.
 *
 * @param {string} filePath
 * @param {string} content
 * @param {BufferEncoding} encoding
 */
function writePatched(filePath, content, encoding) {
  try {
    writeFileSync(filePath, content, encoding)
  } catch (err) {
    if (err?.code !== 'ETXTBSY') throw err

    const tmpPath = filePath + '.patched'
    const { mode } = statSync(filePath)
    writeFileSync(tmpPath, content, encoding)
    chmodSync(tmpPath, mode)
    unlinkSync(filePath)
    renameSync(tmpPath, filePath)
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
