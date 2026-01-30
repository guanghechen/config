import fs from 'node:fs'
import path from 'node:path'
import url from 'node:url'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))

export const XDG_CONFIG_HOME_NODE = path.dirname(__dirname)
export const XDG_CONFIG_HOME = path.dirname(XDG_CONFIG_HOME_NODE)
export const HOME_USER = path.dirname(XDG_CONFIG_HOME)

export const CLAUDE_CONFIG_DIR = path.join(XDG_CONFIG_HOME, 'claude')
export const CODEX_CONFIG_DIR = path.join(XDG_CONFIG_HOME, 'codex')
export const GEMINI_CONFIG_DIR = path.join(HOME_USER, '.gemini')

export const XDG_CONFIG_NODE_SETTING = path.join(XDG_CONFIG_HOME_NODE, '.setting.json')
export const XDG_CONFIG_NODE_THEME_ROOT = path.join(XDG_CONFIG_HOME_NODE, 'theme')
export const XDG_CONFIG_NODE_THEME_APP_DIR = path.join(XDG_CONFIG_NODE_THEME_ROOT, 'app')
export const XDG_CONFIG_NODE_THEME_SCHEME_DIR = path.join(XDG_CONFIG_NODE_THEME_ROOT, 'scheme')
export const XDG_CONFIG_NODE_THEMES = fs
  .readdirSync(XDG_CONFIG_NODE_THEME_SCHEME_DIR)
  .map(p => p.replace(/\.json$/, ''))

export const F_VSCODE_KEYBINDINGS = process.env.f_vscode_keybindings
export const F_WINDOWS_TERMINAL_SETTINGS = process.env.f_windows_terminal_settings
