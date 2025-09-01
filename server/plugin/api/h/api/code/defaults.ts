import { createReadStream, existsSync } from 'node:fs'
import path from 'node:path'
import type { IApiHandle, IApiHandleData } from '../../../types'

// Map file types to their corresponding file extensions and content types
const FILETYPE_TO_EXTENSION_MAP: Record<string, string> = {
  text: 'txt',
  markdown: 'md',
  json: 'json',
  html: 'html',
  svg: 'svg',
  excalidraw: 'excalidraw',
}

const EXTENSION_TO_CONTENT_TYPE_MAP: Record<string, string> = {
  txt: 'text/plain',
  md: 'text/markdown',
  json: 'application/json',
  html: 'text/html',
  svg: 'image/svg+xml',
  excalidraw: 'application/json',
}

export const fetchCodeDefaults: IApiHandle = async params => {
  const { res, pathname } = params

  // Extract filetype from pathname: /api/code/defaults/:filetype
  const pathParts = pathname.split('/')
  const filetype = pathParts[pathParts.length - 1]

  if (!filetype) {
    const data: IApiHandleData = {
      error: 'Filetype parameter is required',
      details: { pathname },
      data: null,
    }
    return { code: 400, data }
  }

  // Validate filetype
  const extension = FILETYPE_TO_EXTENSION_MAP[filetype]
  if (!extension) {
    const data: IApiHandleData = {
      error: 'Unsupported filetype',
      details: { pathname, filetype, supportedTypes: Object.keys(FILETYPE_TO_EXTENSION_MAP) },
      data: null,
    }
    return { code: 400, data }
  }

  // Build path to the default content file
  const filename = `${filetype}.${extension}`
  const filepath = path.join(__dirname, '../../../d/code', filename)

  if (!existsSync(filepath)) {
    const data: IApiHandleData = {
      error: 'Default content file not found',
      details: { pathname, filetype, filepath },
      data: null,
    }
    return { code: 404, data }
  }

  // Get content type
  const contentType = EXTENSION_TO_CONTENT_TYPE_MAP[extension] || 'text/plain'

  try {
    // Stream the file content directly with appropriate content type
    const stream = createReadStream(filepath)
    res.setHeader('Content-Type', contentType)

    // Add CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*')
    res.setHeader('Access-Control-Allow-Methods', 'GET')
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type')

    // Add caching headers (cache for 1 hour)
    res.setHeader('Cache-Control', 'public, max-age=3600')

    stream.pipe(res)
    stream.on('error', err => {
      res.statusCode = 500
      res.setHeader('Content-Type', 'application/json')
      const data = {
        error: 'Failed to read default content file',
        details: { pathname, filetype, filepath, err: err.message },
      }
      res.end(JSON.stringify(data))
    })

    return true
  } catch (error) {
    const data: IApiHandleData = {
      error: 'Failed to serve default content',
      details: {
        pathname,
        filetype,
        filepath,
        error: error instanceof Error ? error.message : String(error),
      },
      data: null,
    }
    return { code: 500, data }
  }
}
