import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import url from 'node:url'

// =============================================================================
// Platform
// =============================================================================

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
export const IS_OSX = PLATFORM === 'osx'
export const IS_WIN = PLATFORM === 'win'
export const IS_WSL = PLATFORM === 'wsl'

// =============================================================================
// Path
// =============================================================================

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))

// __dirname = env/, go up once to get project root
export const XDG_CONFIG_HOME_NODE = path.dirname(__dirname)
export const XDG_CONFIG_HOME = path.dirname(XDG_CONFIG_HOME_NODE)
export const HOME = path.dirname(XDG_CONFIG_HOME)

export const CLAUDE_CONFIG_DIR = path.join(XDG_CONFIG_HOME, 'claude')
export const CODEX_CONFIG_DIR = path.join(XDG_CONFIG_HOME, 'codex')
export const GEMINI_CONFIG_DIR = path.join(HOME, '.gemini')

export const XDG_CONFIG_NODE_ASSET_DIR = path.join(XDG_CONFIG_HOME_NODE, 'asset')
export const XDG_CONFIG_NODE_ENV_DIR = path.join(XDG_CONFIG_HOME_NODE, 'env')
export const XDG_CONFIG_NODE_SETTING_LOCAL = path.join(XDG_CONFIG_NODE_ENV_DIR, 'setting.local.sh')
export const XDG_CONFIG_NODE_SETTING_LOCAL_FISH = path.join(XDG_CONFIG_NODE_ENV_DIR, 'setting.local.fish')
export const XDG_CONFIG_NODE_SETTING_LOCAL_PS1 = path.join(XDG_CONFIG_NODE_ENV_DIR, 'setting.local.ps1')
export const XDG_CONFIG_NODE_ASSET_APP_DIR = path.join(XDG_CONFIG_NODE_ASSET_DIR, 'app')
export const XDG_CONFIG_NODE_REPO_CONFIG = path.join(XDG_CONFIG_NODE_ENV_DIR, 'repo.json')
export const XDG_CONFIG_NODE_REPO_LOCAL_CONFIG = path.join(XDG_CONFIG_NODE_ENV_DIR, 'repo.local.json')
export const XDG_CONFIG_NODE_ASSET_WALLPAPER_DIR = path.join(XDG_CONFIG_NODE_ASSET_DIR, 'wallpaper')
export const XDG_CONFIG_NODE_ASSET_THEME_DIR = path.join(XDG_CONFIG_NODE_ASSET_DIR, 'theme')
export const XDG_CONFIG_NODE_ASSET_THEME_APP_DIR = path.join(XDG_CONFIG_NODE_ASSET_THEME_DIR, 'app')
export const XDG_CONFIG_NODE_ASSET_THEME_SCHEME_DIR = path.join(
  XDG_CONFIG_NODE_ASSET_THEME_DIR,
  'scheme',
)
export const XDG_CONFIG_NODE_ASSET_THEMES = fs
  .readdirSync(XDG_CONFIG_NODE_ASSET_THEME_SCHEME_DIR)
  .map(p => p.replace(/\.json$/, ''))

export const F_VSCODE_KEYBINDINGS = process.env.f_vscode_keybindings
export const F_WINDOWS_TERMINAL_SETTINGS = process.env.f_windows_terminal_settings
