import { readdirSync } from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import url from 'node:url'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))
export const cwd = __dirname
export const HOME_THEME_SCHEME = path.join(__dirname, 'scheme')
export const HOME_THEME_APP = path.join(__dirname, 'app')
export const themes = readdirSync(HOME_THEME_SCHEME).map(p => p.replace(/\.json$/, ''))

const platform = os.platform()
const release = os.release().toLowerCase()
export const IS_MAC = platform === 'darwin'
export const IS_WIN = platform === 'win32'
export const IS_NIX = platform === 'linux' || platform === 'freebsd' || platform === 'openbsd'
export const IS_WSL = IS_NIX && release.includes('microsoft')
