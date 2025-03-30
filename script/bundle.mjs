import { execSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { TARGET_DIR, extensionManifest } from './env.mjs'

export async function bundle() {
  execSync('yarn build', { encoding: 'utf8' })

  const filepath = `${TARGET_DIR}@${extensionManifest.version}.zip`
  if (fs.execSync(filepath)) fs.rmSync(filepath)

  execSync(`zip -r "${filepath}" "${path.basename(TARGET_DIR)}"`, {
    cwd: path.dirname(TARGET_DIR),
    encoding: 'utf8',
  })
}

await bundle()
