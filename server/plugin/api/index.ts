import type { ServerResponse } from 'node:http'
import type { Connect, Plugin } from 'vite'
import { ApiRoutePathEnum } from '../../../shared/constant/api.ts'
import { normalizeUrlPath } from '../../../shared/util/index.ts'
import state from '../../state.ts'
import { FileAccessError } from '../../util/file-access.ts'
import { fetchCodeDefaults } from './h/api/code/defaults.ts'
import { fetchFile } from './h/api/file.ts'
import { fetchFileRaw } from './h/api/file/raw.ts'
import { saveFile } from './h/api/file/save.ts'
import { fetchFileText } from './h/api/file/text.ts'
import { switchFile } from './h/api/file-switch.ts'
import { getTextTransformer } from './h/api/text-transform/:name.ts'
import { listTextTransformers } from './h/api/text-transform/list.ts'
import { postUserAuth } from './h/api/user/auth.ts'
import { postUserLogout } from './h/api/user/logout.ts'
import { getUserProfile } from './h/api/user/profile.ts'
import { list_workspace_files } from './h/api/workspace/files.ts'
import { list_workspaces } from './h/api/workspaces.ts'
import { createWhiteboard } from './h/api/whiteboard/create.ts'
import { verifyJwtMiddleware } from './jwt.ts'
import type { IApiHandle, IApiHandleParams, IApiHandleResult } from './types.ts'

const handle_map: Record<string, IApiHandle> = {
  [ApiRoutePathEnum.USER_AUTH]: postUserAuth,
  [ApiRoutePathEnum.USER_LOGOUT]: postUserLogout,
  [ApiRoutePathEnum.USER_PROFILE]: getUserProfile,
  [ApiRoutePathEnum.FILE]: fetchFile,
  [ApiRoutePathEnum.FILE_RAW]: fetchFileRaw,
  [ApiRoutePathEnum.FILE_SAVE]: saveFile,
  [ApiRoutePathEnum.FILE_TEXT]: fetchFileText,
  [ApiRoutePathEnum.FILE_SWITCH]: switchFile,
  [ApiRoutePathEnum.WHITEBOARD_CREATE]: createWhiteboard,
  [ApiRoutePathEnum.TEXT_TRANSFORM_LIST]: listTextTransformers,
  [ApiRoutePathEnum.WORKSPACES]: list_workspaces,
  [ApiRoutePathEnum.WORKSPACE_FILES]: list_workspace_files,
}

// Endpoints that don't require authentication
const publicEndpoints: Set<string> = new Set([
  ApiRoutePathEnum.USER_AUTH,
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

  state.reporter.debug('--> request:', req.url)

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
    let result: IApiHandleResult | true
    try {
      result = await handle(params)
    } catch (error) {
      if (!(error instanceof FileAccessError)) state.reporter.error('API request failed', error)
      result = {
        code: error instanceof FileAccessError ? error.status : 500,
        data: {
          data: null,
          error: error instanceof FileAccessError ? error.message : 'Request failed',
        },
      }
    }
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
