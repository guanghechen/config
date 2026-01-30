import os from 'node:os'

/**
 * Current platform identifier.
 * @type {'wsl' | 'win' | 'osx' | 'nix' | 'unknown'}
 */
export const PLATFORM = (() => {
  if (os.release().toLowerCase().includes('microsoft')) return 'wsl'
  if (os.platform() === 'win32') return 'win'
  if (os.platform() === 'darwin') return 'osx'
  if (os.platform() === 'linux') return 'nix'
  return 'unknown'
})()

export const IS_NIX = PLATFORM === 'nix'
export const IS_MAC = PLATFORM === 'osx'
export const IS_WIN = PLATFORM === 'win'
export const IS_WSL = PLATFORM === 'wsl'
