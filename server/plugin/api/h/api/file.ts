import { createReadStream, existsSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'
import type {
  IImageFileData,
  IJsonFileData,
  IMarkdownFileData,
  ITextFileData,
} from '../../../../../shared/types'
import state from '../../../../state'
import parseMarkdown from '../../../../util/parseMarkdown'
import type { IApiHandle, IApiHandleData } from '../../types'

const SERVE_FILE_EXTNAME_TYPE_MAP = {
  '.avi': 'video/x-msvideo',
  '.bmp': 'image/bmp',
  '.eventstream': 'application/json',
  '.excalidraw': 'application/json',
  '.gif': 'image/gif',
  '.html': 'text/html',
  '.ico': 'image/x-icon',
  '.jpeg': 'image/jpeg',
  '.jpg': 'image/jpeg',
  '.json': 'application/json',
  '.jsonl': 'application/json',
  '.log': 'text/plain',
  '.md': 'application/json',
  '.mkv': 'video/x-matroska',
  '.mov': 'video/quicktime',
  '.mp3': 'audio/mpeg',
  '.mp4': 'video/mp4',
  '.ogg': 'audio/ogg',
  '.pdf': 'application/pdf',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.txt': 'text/plain',
  '.wav': 'audio/wav',
  '.webm': 'video/webm',
  '.webp': 'image/webp',
}

export const fetchFile: IApiHandle = async params => {
  const { res, pathname, search, searchParams } = params

  const workspace: string | null = decodeURIComponent(searchParams.get('workspace') ?? '') || null
  const filepath: string = decodeURIComponent(searchParams.get('filepath') ?? '')
  const absoluteFilepath = state.resolveFilepath(workspace, filepath)

  if (!absoluteFilepath) {
    const data: IApiHandleData = {
      error: 'Bad search parameters',
      details: { pathname, workspace, filepath: absoluteFilepath, search },
      data: null,
    }
    return { code: 400, data }
  }

  if (!path.isAbsolute(absoluteFilepath)) {
    const data: IApiHandleData = {
      error: 'Cannot resolve the given filepath.',
      details: { pathname, workspace, filepath: absoluteFilepath, search },
      data: null,
    }
    return { code: 400, data }
  }

  const extname: string = path.extname(absoluteFilepath).toLowerCase()
  const contentType: string | undefined =
    SERVE_FILE_EXTNAME_TYPE_MAP[extname as keyof typeof SERVE_FILE_EXTNAME_TYPE_MAP]

  if (!contentType) {
    const data: IApiHandleData = {
      error: 'Not support for the given file format',
      details: { pathname, workspace, filepath: absoluteFilepath, extname, contentType },
      data: null,
    }
    return { code: 400, data }
  }

  if (!existsSync(absoluteFilepath)) {
    const data: IApiHandleData = {
      error: 'File not found',
      details: { pathname, workspace, filepath: absoluteFilepath, extname, contentType },
      data: null,
    }
    return { code: 404, data }
  }

  state.watch(absoluteFilepath)

  switch (extname) {
    case '.eventstream':
    case '.excalidraw':
    case '.json':
    case '.jsonl': {
      let data: IApiHandleData
      try {
        const content: string = await fs.readFile(absoluteFilepath, 'utf8')
        const responseData: IJsonFileData = { content }
        data = {
          data: responseData,
        }
      } catch (error) {
        state.reporter.error('Failed to parse json:', { filepath: absoluteFilepath, error })
        data = {
          error: 'Failed to parse json',
          details: { pathname, workspace, filepath: absoluteFilepath },
          data: null,
        }
      }
      return { code: 200, data }
    }
    case '.log':
    case '.txt': {
      let data: IApiHandleData
      try {
        const content: string = await fs.readFile(absoluteFilepath, 'utf8')
        const responseData: ITextFileData = { content }
        data = {
          data: responseData,
        }
      } catch (error) {
        state.reporter.error('Failed to read text file:', { filepath: absoluteFilepath, error })
        data = {
          error: 'Failed to read text file',
          details: { pathname, workspace, filepath: absoluteFilepath },
          data: null,
        }
      }
      return { code: 200, data }
    }
    case '.md': {
      let data: IApiHandleData
      try {
        const responseData: IMarkdownFileData = await parseMarkdown(absoluteFilepath)
        data = {
          data: responseData,
        }
      } catch (error) {
        state.reporter.error('Failed to parse markdown:', { filepath: absoluteFilepath, error })
        data = {
          error: 'Failed to parse markdown',
          details: { pathname, workspace, filepath: absoluteFilepath },
          data: null,
        }
      }
      return { code: 200, data }
    }
    case '.bmp':
    case '.gif':
    case '.ico':
    case '.jpeg':
    case '.jpg':
    case '.png':
    case '.webp': {
      let data: IApiHandleData
      try {
        const stats = await fs.stat(absoluteFilepath)
        const url = `/api/file/raw?filepath=${encodeURIComponent(filepath)}&workspace=${encodeURIComponent(workspace || '')}`
        const responseData: IImageFileData = {
          url,
          size: stats.size,
          format: extname.slice(1), // Remove the dot
        }
        data = {
          data: responseData,
        }
      } catch (error) {
        state.reporter.error('Failed to get image info:', { filepath: absoluteFilepath, error })
        data = {
          error: 'Failed to get image info',
          details: { pathname, workspace, filepath: absoluteFilepath },
          data: null,
        }
      }
      // Set content type to JSON for structured image data
      res.setHeader('Content-Type', 'application/json')
      return { code: 200, data }
    }
    default:
  }

  const stream = createReadStream(absoluteFilepath)
  res.setHeader('Content-Type', contentType)
  stream.pipe(res)
  stream.on('error', err => {
    res.statusCode = 500
    res.setHeader('Content-Type', 'application/json')
    const data = {
      error: 'Failed to read file',
      details: { pathname, workspace, filepath: absoluteFilepath, extname, contentType, err },
    }
    res.end(JSON.stringify(data))
  })
  return true
}
