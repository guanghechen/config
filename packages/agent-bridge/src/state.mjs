import { chmod, mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'

export const DEFAULT_STATE_PATH = join(homedir(), '.config', 'tsuki-agent', 'broker.json')

export async function writeState(state, path = resolveStatePath()) {
  await mkdir(dirname(path), { recursive: true })
  const temporaryPath = `${path}.${process.pid}.${Date.now()}.tmp`
  try {
    await writeFile(temporaryPath, JSON.stringify(state), { flag: 'wx', mode: 0o600 })
    await rename(temporaryPath, path)
    await chmod(path, 0o600)
  } finally {
    await rm(temporaryPath, { force: true })
  }
}

export async function readState(path = resolveStatePath()) {
  const contents = await readFile(path, 'utf8')
  const state = JSON.parse(contents)
  if (
    !state ||
    typeof state !== 'object' ||
    !Number.isInteger(state.port) ||
    state.port < 1 ||
    state.port > 65_535 ||
    typeof state.clientToken !== 'string' ||
    state.clientToken.length < 32 ||
    state.clientToken.length > 256
  ) {
    throw new Error('Broker state is invalid.')
  }
  return state
}

export async function removeState(path = resolveStatePath(), expectedClientToken) {
  if (expectedClientToken) {
    try {
      const state = await readState(path)
      if (state.clientToken !== expectedClientToken) return
    } catch {
      return
    }
  }
  await rm(path, { force: true })
}

function resolveStatePath() {
  return process.env.TSUKI_AGENT_STATE_PATH || DEFAULT_STATE_PATH
}
