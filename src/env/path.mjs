import fs from 'node:fs'
import path from 'node:path'
import url from 'node:url'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))

export const XDG_CONFIG_HOME_NODE = path.dirname(__dirname)
export const XDG_CONFIG_HOME = path.dirname(XDG_CONFIG_HOME_NODE)
export const HOME = path.dirname(XDG_CONFIG_HOME)

export const CLAUDE_CONFIG_DIR = path.join(XDG_CONFIG_HOME, 'claude')
export const CODEX_CONFIG_DIR = path.join(XDG_CONFIG_HOME, 'codex')
export const GEMINI_CONFIG_DIR = path.join(HOME, '.gemini')

export const XDG_CONFIG_NODE_SETTING = path.join(XDG_CONFIG_HOME_NODE, '.setting.json')
export const XDG_CONFIG_NODE_ASSET_DIR = path.join(XDG_CONFIG_HOME_NODE, 'asset')
export const XDG_CONFIG_NODE_ASSET_APP_DIR = path.join(XDG_CONFIG_NODE_ASSET_DIR, 'app')
export const XDG_CONFIG_NODE_ASSET_REPO_CONFIG = path.join(XDG_CONFIG_NODE_ASSET_DIR, 'repo.json')
export const XDG_CONFIG_NODE_ASSET_REPO_LOCAL_CONFIG = path.join(
  XDG_CONFIG_NODE_ASSET_DIR,
  'repo.local.json',
)
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
