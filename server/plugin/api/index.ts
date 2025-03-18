/* eslint-disable no-param-reassign */
import type { ServerResponse } from 'node:http'
import type { Connect, Plugin } from 'vite'
import state from '../../state'
import { file } from './handle/file'
import { file_switch } from './handle/file-switch'
import type { IApiHandle, IApiHandleParams } from './types'

const handle_map: Record<string, IApiHandle> = {
  '/api/file': file,
  '/api/file-switch': file_switch,
}

const middleware = async (
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

  state.reporter.verbose('--> request:', req.url)

  const handle: IApiHandle | undefined = handle_map[pathname]
  if (handle) {
    const params: IApiHandleParams = { req, res, next, pathname, search, searchParams }
    const handled = await handle(params)
    if (handled) return
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
        void middleware(req, res, next)
      })
    },
  }
}

export default plugin
