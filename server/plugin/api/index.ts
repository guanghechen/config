import type { ServerResponse } from 'node:http'
import type { Connect, Plugin } from 'vite'
import { ApiRoutePathEnum } from '../../../shared/constant/api'
import { normalizeUrlPath } from '../../../shared/util'
import state from '../../state'
import { fetchCodeDefaults } from './h/api/code/defaults'
import { fetchFile } from './h/api/file'
import { fetchFileRaw } from './h/api/file/raw'
import { saveFile } from './h/api/file/save'
import { switchFile } from './h/api/file-switch'
import { getTextTransformer } from './h/api/text-transform/:name'
import { listTextTransformers } from './h/api/text-transform/list'
import { postUserLogin } from './h/api/user/login'
import { postUserLogout } from './h/api/user/logout'
import { getUserProfile } from './h/api/user/profile'
import { list_workspace_files } from './h/api/workspace/files'
import { list_workspaces } from './h/api/workspaces'
import { verifyJwtMiddleware } from './jwt'
import type { IApiHandle, IApiHandleParams, IApiHandleResult } from './types'

const handle_map: Record<string, IApiHandle> = {
  [ApiRoutePathEnum.USER_LOGIN]: postUserLogin,
  [ApiRoutePathEnum.USER_LOGOUT]: postUserLogout,
  [ApiRoutePathEnum.USER_PROFILE]: getUserProfile,
  [ApiRoutePathEnum.FILE]: fetchFile,
  [ApiRoutePathEnum.FILE_RAW]: fetchFileRaw,
  [ApiRoutePathEnum.FILE_SAVE]: saveFile,
  [ApiRoutePathEnum.FILE_SWITCH]: switchFile,
  [ApiRoutePathEnum.TEXT_TRANSFORM_LIST]: listTextTransformers,
  [ApiRoutePathEnum.WORKSPACES]: list_workspaces,
  [ApiRoutePathEnum.WORKSPACE_FILES]: list_workspace_files,
}

// Endpoints that don't require authentication
const publicEndpoints: Set<string> = new Set([
  ApiRoutePathEnum.USER_LOGIN,
  ApiRoutePathEnum.USER_LOGOUT,
  ApiRoutePathEnum.FILE_SWITCH,
])

// Check if an endpoint requires authentication
function requiresAuth(pathname: string): boolean {
  // Check exact matches first
  if (publicEndpoints.has(pathname)) {
    return false
  }

  // Check patterns for dynamic routes
  if (
    pathname.startsWith(`${ApiRoutePathEnum.TEXT_TRANSFORM}/`) &&
    pathname !== ApiRoutePathEnum.TEXT_TRANSFORM_LIST
  ) {
    return true // Transform endpoints require auth
  }

  if (pathname.startsWith(`${ApiRoutePathEnum.CODE_DEFAULTS}/`)) {
    return true // Code default endpoints require auth
  }

  // All other /api/ endpoints require auth by default
  return pathname.startsWith('/api/')
}

// Handle routes with path parameters
const getHandleForPath = (pathname: string): IApiHandle | undefined => {
  // First try exact match
  if (handle_map[pathname]) {
    return handle_map[pathname]
  }

  // Check for transformer path parameter pattern: /api/transform/text/:name
  if (
    pathname.startsWith(`${ApiRoutePathEnum.TEXT_TRANSFORM}/`) &&
    pathname !== ApiRoutePathEnum.TEXT_TRANSFORM_LIST
  ) {
    return getTextTransformer
  }

  // Check for code defaults path parameter pattern: /api/code/defaults/:filetype
  if (pathname.startsWith(`${ApiRoutePathEnum.CODE_DEFAULTS}/`)) {
    return fetchCodeDefaults
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

  // Check if authentication is required for this endpoint
  if (requiresAuth(pathname)) {
    const params: IApiHandleParams = {
      req,
      res,
      next,
      pathname,
      searchParams,
      search,
      body: '',
    }
    const jwtResult = verifyJwtMiddleware(params)
    if (jwtResult) {
      // eslint-disable-next-line no-param-reassign
      res.statusCode = jwtResult.code
      res.setHeader('Content-Type', 'application/json')
      res.end(JSON.stringify(jwtResult.data))
      return
    }
  }

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

    // eslint-disable-next-line no-param-reassign
    res.statusCode = result.code
    res.setHeader('Content-Type', 'application/json')

    // Set any additional headers from the response
    if (result.data.headers) {
      Object.entries(result.data.headers).forEach(([key, value]) => {
        res.setHeader(key, value)
      })
    }

    res.end(JSON.stringify(result.data))
    return
  }

  {
    // eslint-disable-next-line no-param-reassign
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
