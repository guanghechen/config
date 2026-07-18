import fs from 'node:fs'
import path from 'node:path'
import url from 'node:url'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))
export const ROOT_DIR = path.dirname(__dirname)

const ENV_FILEPATHS = [path.resolve(ROOT_DIR, '.env.local'), path.resolve(ROOT_DIR, '.env')]

loadEnvironment()

export const SOURCE_INJECT_DIR = path.resolve(ROOT_DIR, 'src/inject')
export const TARGET_DIR = path.resolve(ROOT_DIR, process.env.OUT_DIR || 'dist')
export const isProduction = process.env.NODE_ENV === 'production'
export const isDevelopment = process.env.NODE_ENV === 'development'
export const YOZ_SERVER_PORT = process.env.YOZ_SERVER_PORT || '7071'
export const AGENT_BRIDGE_PORT = process.env.AGENT_BRIDGE_PORT || '7072'

const extensionManifestContent = fs.readFileSync(path.join(ROOT_DIR, 'public/manifest.json'))
export const extensionManifest = JSON.parse(extensionManifestContent)

function loadEnvironment() {
  for (const filepath of ENV_FILEPATHS) {
    if (fs.existsSync(filepath)) process.loadEnvFile(filepath)
  }
}
