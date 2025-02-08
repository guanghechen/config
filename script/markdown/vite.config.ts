/* eslint-disable no-param-reassign */
import react from '@vitejs/plugin-react'
import fs from 'node:fs'
import path from 'node:path'
import { defineConfig } from 'vite'
import { ROOT_DIR, TARGET_DIR } from './script/env.mjs'

const SERVE_FILE_EXTNAME_TYPE_MAP = {
  '.md': 'text/markdown',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
}

// https://vite.dev/config/
export default defineConfig({
  define: {},
  build: {
    outDir: TARGET_DIR,
  },
  plugins: [
    react(),
    {
      name: '@guanghechen/serve',
      configureServer(server) {
        server.middlewares.use((req, res, next) => {
          if (!req.url) return void next()

          const { search, searchParams, pathname } = new URL(req.url, 'http://localhost')
          if (!pathname.startsWith('/api/')) return void next()

          if (pathname === '/api/file') {
            let filepath: string = decodeURIComponent(searchParams.get('filepath') ?? '')
            if (searchParams.get('base')) {
              const base: string = decodeURIComponent(searchParams.get('base')!)
              if (fs.existsSync(base)) {
                filepath = fs.statSync(base).isDirectory()
                  ? path.resolve(base, filepath)
                  : path.resolve(path.dirname(base), filepath)
              }
            }
            filepath = path.normalize(filepath)

            if (!filepath) {
              res.statusCode = 400
              res.setHeader('Content-Type', 'application/json')
              const data = {
                error: 'Bad search parameters',
                details: { pathname, filepath, search },
              }
              res.end(JSON.stringify(data))
              return
            }

            const extname: string = path.extname(filepath).toLowerCase()
            const contentType: string | undefined =
              SERVE_FILE_EXTNAME_TYPE_MAP[extname as keyof typeof SERVE_FILE_EXTNAME_TYPE_MAP]

            if (!contentType) {
              res.statusCode = 404
              res.setHeader('Content-Type', 'application/json')
              const data = {
                error: 'Not support for the given file format',
                details: { pathname, filepath, extname, contentType },
              }
              res.end(JSON.stringify(data))
              return
            }

            if (!fs.existsSync(filepath)) {
              res.statusCode = 404
              res.setHeader('Content-Type', 'application/json')
              const data = {
                error: 'File not found',
                details: { pathname, filepath, extname, contentType },
              }
              res.end(JSON.stringify(data))
              return
            }

            res.statusCode = 200
            res.setHeader('Content-Type', contentType)

            const stream = fs.createReadStream(filepath)
            stream.pipe(res)
            stream.on('error', err => {
              res.statusCode = 500
              res.setHeader('Content-Type', 'application/json')
              const data = {
                error: 'Failed to read file',
                details: { pathname, filepath, extname, contentType, err },
              }
              res.end(JSON.stringify(data))
            })
            return
          }

          {
            res.statusCode = 404
            res.setHeader('Content-Type', 'application/json')
            const data = {
              error: 'Unknown pathname',
              detail: { pathname },
            }
            res.end(JSON.stringify(data))
          }
        })
      },
    },
  ],
  resolve: {
    alias: {
      '@': path.resolve(ROOT_DIR, 'src'),
    },
  },
})
