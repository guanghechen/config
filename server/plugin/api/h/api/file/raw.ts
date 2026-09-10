import { createReadStream } from 'node:fs'
import path from 'node:path'
import state from '../../../../../state'
import type { IApiHandle, IApiHandleData } from '../../../types'

const SERVE_FILE_EXTNAME_TYPE_MAP = {
  '.avi': 'video/x-msvideo',
  '.bmp': 'image/bmp',
  '.eventstream': 'application/json',
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

export const fetchFileRaw: IApiHandle = async params => {
  const { res, pathname, searchParams } = params

  const filepath = state.access.resolve(searchParams.get('filepath'), 'file')

  const extname: string = path.extname(filepath).toLowerCase()
  const contentType: string | undefined =
    SERVE_FILE_EXTNAME_TYPE_MAP[extname as keyof typeof SERVE_FILE_EXTNAME_TYPE_MAP]

  if (!contentType) {
    const data: IApiHandleData = {
      error: 'Not support for the given file format',
      details: { pathname, filepath, extname, contentType },
      data: null,
    }
    return { code: 400, data }
  }

  // Always serve the raw file content directly with proper ContentType
  const stream = createReadStream(filepath)
  res.setHeader('Content-Type', contentType)
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
  return true
}
