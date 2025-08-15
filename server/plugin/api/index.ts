/* eslint-disable no-param-reassign */
import type { ServerResponse } from 'node:http'
import type { Connect, Plugin } from 'vite'
import state from '../../state'
import { normalizeUrlPath } from '../../util/url'
import { fetchFile, fetchFileRaw, saveExcalidrawFile, switchFile } from './handle/file'
import { list_workspace_files, list_workspaces } from './handle/workspace'
import type { IApiHandle, IApiHandleParams, IApiHandleResult } from './types'

const handle_map: Record<string, IApiHandle> = {
  '/api/file': fetchFile,
  '/api/file/raw': fetchFileRaw,
  '/api/file-switch': switchFile,
  '/api/excalidraw/save': saveExcalidrawFile,
  '/api/workspaces': list_workspaces,
  '/api/workspace/files': list_workspace_files,
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

  const handle: IApiHandle | undefined = handle_map[pathname]
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
