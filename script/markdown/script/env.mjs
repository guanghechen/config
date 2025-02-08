import dotenv from 'dotenv'
import path from 'node:path'
import url from 'node:url'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))
export const ROOT_DIR = path.dirname(__dirname)

dotenv.config({
  path: [
    path.resolve(ROOT_DIR, '.env.local'), //
    path.resolve(ROOT_DIR, '.env'),
  ],
})

export const TARGET_DIR = path.resolve(ROOT_DIR, process.env.OUT_DIR || 'dist')
export const isProduction = process.env.NODE_ENV === 'production'
export const isDevelopment = process.env.NODE_ENV === 'development'
