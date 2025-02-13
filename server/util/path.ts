import os from 'node:os'
import path from 'node:path'

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
        const envName: string = `YOZORA_WORKSPACE_${m1.replace(/-/g, '_').toUpperCase()}`
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
