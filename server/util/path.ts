import os from 'node:os'
import path from 'node:path'

const platform: 'win' | 'wsl' | 'mac' | 'nix' | 'unknown' = (() => {
  if (os.release().toLowerCase().includes('microsoft')) return 'wsl'
  if (os.platform() === 'win32') return 'win'
  if (os.platform() === 'darwin') return 'mac'
  if (os.platform() === 'linux') return 'nix'
  return 'unknown'
})()

export function normalizeFilepath(filepath: string): string {
  const resolvedFilepath: string = path.normalize(filepath.replace(/^~/, process.env.HOME || '~'))

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

export function normalizeUrlPath(pathname: string): string {
  const p: string = pathname.trim().replace(/[/\\]+/g, '/')
  return p.length > 0 ? p.replace(/\/+$/, '') : p
}

export function resolveRealFilepath(filepath: string): string {
  return path.normalize(normalizeFilepath(filepath))
}
