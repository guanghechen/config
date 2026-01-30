import path from 'node:path'
import url from 'node:url'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))

export const XDG_CONFIG_HOME_NODE = path.dirname(__dirname)
export const XDG_CONFIG_HOME = path.dirname(XDG_CONFIG_HOME_NODE)
export const HOME_USER = path.dirname(XDG_CONFIG_HOME)

export const CLAUDE_CONFIG_DIR = path.join(XDG_CONFIG_HOME, 'claude')
export const CODEX_CONFIG_DIR = path.join(XDG_CONFIG_HOME, 'codex')
export const GEMINI_CONFIG_DIR = path.join(USER_HOME, '.gemini')
