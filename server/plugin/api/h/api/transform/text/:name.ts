import { existsSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'
import { ROOT_DIR } from '../../../../../../../env'
import { validateTransformerData } from '../../../../../../../shared/transform/util'
import type { IApiHandle, IApiHandleData } from '../../../../types'

const TRANSFORMER_DATA_DIR = path.join(ROOT_DIR, 'server/plugin/api/d/transform/text')

const extractNameFromPath = (pathname: string): string => {
  const pathParts = pathname.split('/')
  return pathParts[pathParts.length - 1] || ''
}

const ensureDirectoryExists = async (): Promise<void> => {
  if (!existsSync(TRANSFORMER_DATA_DIR)) {
    await fs.mkdir(TRANSFORMER_DATA_DIR, { recursive: true })
  }
}

export const getTextTransformer: IApiHandle = async params => {
  const { pathname, req, body } = params

  const name = extractNameFromPath(pathname)
  if (!name) {
    const data: IApiHandleData = {
      error: 'Missing transformer name parameter',
      details: { pathname },
      data: null,
    }
    return { code: 400, data }
  }

  const filename = `${name}.json`
  const filepath = path.join(TRANSFORMER_DATA_DIR, filename)

  try {
    switch (req.method) {
      case 'GET':
        return await handleGet(pathname, name, filepath)
      case 'POST':
        return await handlePost(pathname, name, filepath, body)
      case 'DELETE':
        return await handleDelete(pathname, name, filepath)
      default: {
        const data: IApiHandleData = {
          error: 'Method not allowed',
          details: { pathname, method: req.method },
          data: null,
        }
        return { code: 405, data }
      }
    }
  } catch (error) {
    const data: IApiHandleData = {
      error: 'Failed to handle transformer request',
      details: {
        pathname,
        name,
        method: req.method,
        error: error instanceof Error ? error.message : 'Unknown error',
      },
      data: null,
    }
    return { code: 500, data }
  }
}

const handleGet = async (
  pathname: string,
  name: string,
  filepath: string,
): Promise<{ code: number; data: IApiHandleData }> => {
  if (!existsSync(TRANSFORMER_DATA_DIR)) {
    const data: IApiHandleData = {
      error: 'Transformer data directory not found',
      details: { pathname, transformerDataDir: TRANSFORMER_DATA_DIR },
      data: null,
    }
    return { code: 404, data }
  }

  try {
    const content = await fs.readFile(filepath, 'utf8')
    const transformer = JSON.parse(content)

    const data: IApiHandleData = {
      data: { transformer },
    }
    return { code: 200, data }
  } catch (fileError) {
    if ((fileError as NodeJS.ErrnoException).code === 'ENOENT') {
      const data: IApiHandleData = {
        error: 'Transformer not found',
        details: { pathname, name },
        data: null,
      }
      return { code: 404, data }
    }

    const data: IApiHandleData = {
      error: 'Failed to parse transformer file',
      details: {
        pathname,
        name,
        error: fileError instanceof Error ? fileError.message : 'Unknown error',
      },
      data: null,
    }
    return { code: 400, data }
  }
}

const handlePost = async (
  pathname: string,
  name: string,
  filepath: string,
  body?: string,
): Promise<{ code: number; data: IApiHandleData }> => {
  if (!body) {
    const data: IApiHandleData = {
      error: 'Missing request body',
      details: { pathname, name },
      data: null,
    }
    return { code: 400, data }
  }

  try {
    await ensureDirectoryExists()

    const transformerData = JSON.parse(body)

    if (!validateTransformerData(transformerData)) {
      const data: IApiHandleData = {
        error: 'Invalid transformer data format',
        details: { pathname, name, requiredFields: ['name', 'functions'] },
        data: null,
      }
      return { code: 400, data }
    }

    // Ensure the name in the data matches the URL parameter
    if (transformerData.name !== name) {
      const data: IApiHandleData = {
        error: 'Transformer name mismatch',
        details: { pathname, urlName: name, dataName: transformerData.name },
        data: null,
      }
      return { code: 400, data }
    }

    await fs.writeFile(filepath, JSON.stringify(transformerData, null, 2), 'utf8')

    const data: IApiHandleData = {
      data: {
        transformer: transformerData,
        message: 'Transformer saved successfully',
      },
    }
    return { code: 200, data }
  } catch (parseError) {
    const data: IApiHandleData = {
      error: 'Invalid JSON in request body',
      details: {
        pathname,
        name,
        error: parseError instanceof Error ? parseError.message : 'Unknown error',
      },
      data: null,
    }
    return { code: 400, data }
  }
}

const handleDelete = async (
  pathname: string,
  name: string,
  filepath: string,
): Promise<{ code: number; data: IApiHandleData }> => {
  try {
    await fs.access(filepath)
    await fs.unlink(filepath)

    const data: IApiHandleData = {
      data: { name, message: 'Transformer deleted successfully' },
    }
    return { code: 200, data }
  } catch (fileError) {
    if ((fileError as NodeJS.ErrnoException).code === 'ENOENT') {
      const data: IApiHandleData = {
        error: 'Transformer not found',
        details: { pathname, name },
        data: null,
      }
      return { code: 404, data }
    }

    const data: IApiHandleData = {
      error: 'Failed to delete transformer',
      details: {
        pathname,
        name,
        error: fileError instanceof Error ? fileError.message : 'Unknown error',
      },
      data: null,
    }
    return { code: 500, data }
  }
}
