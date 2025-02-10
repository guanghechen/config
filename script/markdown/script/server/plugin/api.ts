/* eslint-disable no-param-reassign */
import fs from 'node:fs'
import type { ServerResponse } from 'node:http'
import path from 'node:path'
import type { Connect, Plugin } from 'vite'
import state from '../state'
import parseMarkdown from '../util/parseMarkdown'

const SERVE_FILE_EXTNAME_TYPE_MAP = {
  '.md': 'application/json',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
}

const middelware = async (
  req: Connect.IncomingMessage,
  res: ServerResponse,
  next: Connect.NextFunction,
): Promise<void> => {
  if (!req.url) {
    next()
    return
  }

  const { search, searchParams, pathname } = new URL(req.url, 'http://localhost')
  if (!pathname.startsWith('/api/')) {
    next()
    return
  }

  if (pathname === '/api/file') {
    let filepath: string = decodeURIComponent(searchParams.get('filepath') ?? '')
    filepath = filepath ? path.normalize(filepath) : ''

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

    state.watch(filepath)

    res.statusCode = 200
    res.setHeader('Content-Type', contentType)

    if (extname === '.md') {
      let result: object | undefined
      try {
        const ast = await parseMarkdown(filepath)
        result = { data: { ast } }
      } catch (error) {
        console.error('Failed to parse markdown:', { filepath, error })
        result = { error: 'Failed to parse markdown', details: { filepath } }
      }
      res.end(JSON.stringify(result))
      return
    }

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
}

const plugin = (): Plugin => {
  return {
    name: '@guanghechen/api',
    configureServer(server) {
      server.middlewares.use((req, res, next): void => {
        void middelware(req, res, next)
      })
    },
  }
}

export default plugin
