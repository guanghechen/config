/* eslint-disable no-param-reassign */
import type { ServerResponse } from 'node:http'
import type { Connect, Plugin } from 'vite'
import { normalizeUrlPath } from '../../../shared/util'
import state from '../../state'
import { fetchCodeDefault } from './h/api/config/code-default'
import { saveExcalidrawFile } from './h/api/excalidraw/save'
import { fetchFile } from './h/api/file'
import { fetchFileRaw } from './h/api/file/raw'
import { switchFile } from './h/api/file-switch'
import { getTextTransformer } from './h/api/transform/text/:name'
import { listTextTransformers } from './h/api/transform/text/list'
import { list_workspace_files } from './h/api/workspace/files'
import { list_workspaces } from './h/api/workspaces'
import type { IApiHandle, IApiHandleParams, IApiHandleResult } from './types'

const handle_map: Record<string, IApiHandle> = {
  '/api/file': fetchFile,
  '/api/file/raw': fetchFileRaw,
  '/api/file-switch': switchFile,
  '/api/excalidraw/save': saveExcalidrawFile,
  '/api/transform/text/list': listTextTransformers,
  '/api/workspaces': list_workspaces,
  '/api/workspace/files': list_workspace_files,
}

// Handle routes with path parameters
const getHandleForPath = (pathname: string): IApiHandle | undefined => {
  // First try exact match
  if (handle_map[pathname]) {
    return handle_map[pathname]
  }

  // Check for transformer path parameter pattern: /api/transform/text/:name
  if (pathname.startsWith('/api/transform/text/') && pathname !== '/api/transform/text/list') {
    return getTextTransformer
  }

  // Check for code-default path parameter pattern: /api/config/code-default/:filetype
  if (pathname.startsWith('/api/config/code-default/')) {
    return fetchCodeDefault
  }

  return undefined
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

  const { search, searchParams, pathname: pathname0 } = new URL(req.url, 'http://localhost')
  const pathname: string = normalizeUrlPath(pathname0)
  if (!pathname.startsWith('/api/')) {
    next()
    return
  }

  state.reporter.verbose('--> request:', req.url)

  const handle: IApiHandle | undefined = getHandleForPath(pathname)
  if (handle) {
    let body: string | undefined
    if (req.method === 'POST' && req.headers['content-type']?.includes('application/json')) {
      const chunks: Buffer[] = []
      for await (const chunk of req) {
        chunks.push(chunk)
      }
      body = Buffer.concat(chunks).toString('utf8')
    }

    const params: IApiHandleParams = { req, res, next, pathname, search, searchParams, body }
    const result: IApiHandleResult | true = await handle(params)
    if (result === true) return

    res.statusCode = result.code
    res.setHeader('Content-Type', 'application/json')
    res.end(JSON.stringify(result.data))
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
        void middleware(req, res, next)
      })
    },
  }
}

export default plugin
