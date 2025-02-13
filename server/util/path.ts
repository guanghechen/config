import os from 'node:os'
import path from 'node:path'

const YOZORA_WORKSPACE_PREFIX = 'YOZORA_WORKSPACE_'
const YOZORA_WORKSPACE_ENVS: Array<[string, string]> = Object.entries(process.env)
  .filter(([key, val]) => !!val && key.startsWith(YOZORA_WORKSPACE_PREFIX))
  .map(([key, val]) => [key, resolveRealFilepath(val!)]) as Array<[string, string]>

const platform: 'win' | 'wsl' | 'mac' | 'nix' | 'unknown' = (() => {
  if (os.platform() === 'win32') {
    if (os.release().toLowerCase().includes('microsoft')) return 'wsl'
    return 'win'
  }
  if (os.platform() === 'darwin') return 'mac'
  if (os.platform() === 'linux') return 'nix'
  return 'unknown'
})()

export function normalizeFilepath(filepath: string): string {
  const resolvedFilepath: string = path.normalize(
    filepath
      .replace(/^@([\w-]+):/, (_, m1) => {
        const envName: string = `${YOZORA_WORKSPACE_PREFIX}${m1.replace(/-/g, '_').toUpperCase()}`
        return process.env[envName] || m1
      })
      .replace(/^~/, process.env.HOME || '~'),
  )

  if (platform === 'mac' || platform === 'nix') {
    return resolvedFilepath.replace(/[/\\]+/g, '/')
  }

  if (platform === 'wsl') {
    return resolvedFilepath
      .replace(/^([a-zA-Z]):/, (_, m1) => `/mnt/${m1.toLowerCase()}`)
      .replace(/[/\\]+/g, '/')
  }

  if (platform === 'win') {
    return resolvedFilepath.replace(/^\/mnt\/([a-zA-Z])\//, (_, m1) => `${m1.toUpperCase()}:/`)
  }
  return resolvedFilepath
}

export function resolveRealFilepath(filepath: string): string {
  return path.normalize(normalizeFilepath(filepath))
}

export function resolveShortFilepath(filepath: string): string {
  const resolvedFilepath: string = resolveRealFilepath(filepath)
  for (const [key, val] of YOZORA_WORKSPACE_ENVS) {
    if (resolvedFilepath.startsWith(val)) {
      const shortFilepath: string =
        `@${key.slice(YOZORA_WORKSPACE_PREFIX.length)}:` +
        path.sep +
        resolvedFilepath.slice(val.length)
      return shortFilepath
    }
  }
  return resolvedFilepath
}
