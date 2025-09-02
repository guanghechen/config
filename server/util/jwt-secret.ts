import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { ROOT_DIR } from '../../env'

const ENV_LOCAL_FILE = path.join(ROOT_DIR, '.env.local')

export function getJwtSecret(): string {
  if (process.env.YOZ_JWT_SECRET) {
    return process.env.YOZ_JWT_SECRET
  }

  try {
    if (fs.existsSync(ENV_LOCAL_FILE)) {
      const content = fs.readFileSync(ENV_LOCAL_FILE, 'utf8')
      if (content.includes('YOZ_JWT_SECRET=')) {
        const match = content.match(/YOZ_JWT_SECRET=(.+)/)
        if (match?.[1]) {
          return match[1].trim()
        }
      }
    }
  } catch {
    // Fall through to generate new secret
  }

  const secret = crypto.randomBytes(32).toString('base64')

  try {
    const envEntry = `YOZ_JWT_SECRET=${secret}\n`
    fs.appendFileSync(ENV_LOCAL_FILE, envEntry, 'utf8')
    fs.chmodSync(ENV_LOCAL_FILE, 0o600)
  } catch {
    // If write fails, use secret for this session only
  }

  return secret
}
