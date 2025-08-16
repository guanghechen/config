import { existsSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'
import state from '../../../../../state'
import type { IApiHandle, IApiHandleData } from '../../../types'

export const saveExcalidrawFile: IApiHandle = async params => {
  const { searchParams, body } = params

  if (!body) {
    const data: IApiHandleData = {
      error: 'Request body is required',
      details: { body },
      data: null,
    }
    return { code: 400, data }
  }

  const workspace: string | null = decodeURIComponent(searchParams.get('workspace') ?? '') || null
  let filepath: string = decodeURIComponent(searchParams.get('filepath') ?? '')
  filepath = state.resolveFilepath(workspace, filepath)

  if (!filepath) {
    const data: IApiHandleData = {
      error: 'Bad search parameters',
      details: { workspace, filepath },
      data: null,
    }
    return { code: 400, data }
  }

  if (!path.isAbsolute(filepath)) {
    const data: IApiHandleData = {
      error: 'Cannot resolve the given filepath.',
      details: { workspace, filepath },
      data: null,
    }
    return { code: 400, data }
  }

  const extname: string = path.extname(filepath).toLowerCase()
  if (extname !== '.excalidraw') {
    const data: IApiHandleData = {
      error: 'Only .excalidraw files are allowed for saving',
      details: { workspace, filepath, extname },
      data: null,
    }
    return { code: 400, data }
  }

  if (!existsSync(filepath)) {
    const data: IApiHandleData = {
      error: 'File not found',
      details: { workspace, filepath },
      data: null,
    }
    return { code: 404, data }
  }

  try {
    // Validate that body is valid JSON
    const parsedData = JSON.parse(body)

    // Format JSON with proper indentation
    const formattedJson = JSON.stringify(parsedData, null, 2)

    // Write to file
    await fs.writeFile(filepath, formattedJson, 'utf8')

    const data: IApiHandleData = {
      data: { success: true, filepath },
    }
    return { code: 200, data }
  } catch (error) {
    state.reporter.error('Failed to save excalidraw file:', { filepath, error })
    const data: IApiHandleData = {
      error: 'Failed to save excalidraw file: Invalid JSON or write error',
      details: { workspace, filepath, error: String(error) },
      data: null,
    }
    return { code: 500, data }
  }
}
