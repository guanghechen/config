import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { TARGET_DIR, extensionManifest } from './env.mjs'

export function bundle() {
  const packageManagerPath = process.env.npm_execpath
  if (!packageManagerPath) {
    throw new Error('Cannot run the build because npm_execpath is not set.')
  }

  const version = extensionManifest.version
  if (typeof version !== 'string' || version.length === 0) {
    throw new TypeError('The extension manifest must contain a non-empty version.')
  }

  try {
    runBuild(packageManagerPath)
    if (!fs.existsSync(TARGET_DIR)) {
      throw new Error(`Build output directory does not exist: ${TARGET_DIR}`)
    }

    const filepath = `${TARGET_DIR}@${version}.zip`
    fs.rmSync(filepath, { force: true })
    createArchive(filepath)
    return filepath
  } catch (cause) {
    throw new Error('Failed to build the extension bundle.', { cause })
  }
}

function runBuild(packageManagerPath) {
  const isJavaScriptCli = /\.[cm]?js$/i.test(packageManagerPath)
  const command = isJavaScriptCli ? process.execPath : packageManagerPath
  const args = isJavaScriptCli ? [packageManagerPath, 'run', 'build'] : ['run', 'build']
  execFileSync(command, args, { stdio: 'inherit' })
}

function createArchive(filepath) {
  execFileSync('zip', ['-r', filepath, path.basename(TARGET_DIR)], {
    cwd: path.dirname(TARGET_DIR),
    stdio: 'inherit',
  })
}

const filepath = bundle()
console.log(`Created extension bundle: ${filepath}`)
