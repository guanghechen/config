import dotenv from 'dotenv'
import path from 'node:path'
import url from 'node:url'

const __dirname: string = path.dirname(url.fileURLToPath(import.meta.url))
export const ROOT_DIR: string = __dirname

dotenv.config({
  path: [
    path.resolve(ROOT_DIR, '.env.local'), //
    path.resolve(ROOT_DIR, '.env'),
  ],
})

export const TARGET_DIR: string = path.resolve(ROOT_DIR, process.env.OUT_DIR || 'dist')
export const isProduction: boolean = process.env.NODE_ENV === 'production'
export const isDevelopment: boolean = process.env.NODE_ENV === 'development'
