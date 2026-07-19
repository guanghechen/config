import { lstat, mkdir, readlink, realpath, rm, symlink } from 'node:fs/promises'
import { homedir } from 'node:os'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const SKILL_NAME = 'tsuki-agent'
const DEFAULT_SKILL_SOURCE = fileURLToPath(new URL(`../skills/${SKILL_NAME}`, import.meta.url))

export async function linkAgentSkill({
  codexHome = resolveDefaultCodexHome(),
  log = console.log,
} = {}) {
  const source = await realpath(DEFAULT_SKILL_SOURCE)
  const destination = resolveDestination(codexHome)
  const existing = await inspectDestination(destination, source)

  if (existing === 'linked') {
    log(`Tsuki agent skill is already linked at ${destination}`)
    return destination
  }
  if (existing === 'conflict') {
    throw new Error(`Refusing to replace existing skill path: ${destination}`)
  }

  await mkdir(path.dirname(destination), { recursive: true })
  await symlink(source, destination, process.platform === 'win32' ? 'junction' : 'dir')
  log(`Linked Tsuki agent skill at ${destination}`)
  return destination
}

export async function unlinkAgentSkill({
  codexHome = resolveDefaultCodexHome(),
  log = console.log,
} = {}) {
  const source = await realpath(DEFAULT_SKILL_SOURCE)
  const destination = resolveDestination(codexHome)
  const existing = await inspectDestination(destination, source)

  if (existing === 'missing') {
    log(`Tsuki agent skill is not linked at ${destination}`)
    return destination
  }
  if (existing === 'conflict') {
    throw new Error(`Refusing to remove non-Tsuki skill path: ${destination}`)
  }

  await rm(destination)
  log(`Unlinked Tsuki agent skill from ${destination}`)
  return destination
}

async function inspectDestination(destination, source) {
  let stats
  try {
    stats = await lstat(destination)
  } catch (cause) {
    if (cause?.code === 'ENOENT') return 'missing'
    throw cause
  }
  if (!stats.isSymbolicLink()) return 'conflict'

  const target = await readlink(destination)
  const resolvedTarget = path.resolve(path.dirname(destination), target)
  try {
    return (await realpath(resolvedTarget)) === source ? 'linked' : 'conflict'
  } catch {
    return 'conflict'
  }
}

function readCodexHomeOption(args) {
  const index = args.indexOf('--codex-home')
  if (index >= 0) {
    const value = args[index + 1]
    if (!value) throw new Error('--codex-home requires a path.')
    if (args.length !== 2) throw new Error('Unknown agent skill options.')
    return path.resolve(value)
  }
  if (args.length > 0) throw new Error('Unknown agent skill options.')
  return resolveDefaultCodexHome()
}

function resolveDefaultCodexHome() {
  return path.resolve(process.env.CODEX_HOME || path.join(homedir(), '.codex'))
}

function resolveDestination(codexHome) {
  return path.join(path.resolve(codexHome), 'skills', SKILL_NAME)
}

async function main() {
  const command = process.argv[2]
  const options = { codexHome: readCodexHomeOption(process.argv.slice(3)) }
  if (command === 'link') await linkAgentSkill(options)
  else if (command === 'unlink') await unlinkAgentSkill(options)
  else throw new Error('Usage: node script/agent-skill.mjs <link|unlink> [--codex-home PATH]')
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    await main()
  } catch (cause) {
    process.stderr.write(`${cause instanceof Error ? cause.message : String(cause)}\n`)
    process.exitCode = 1
  }
}
