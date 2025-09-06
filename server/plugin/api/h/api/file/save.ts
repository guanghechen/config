import { existsSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'
import state from '../../../../../state'
import type { IApiHandle, IApiHandleData } from '../../../types'

export const saveFile: IApiHandle = async params => {
  const { body } = params

  if (!body) {
    const data: IApiHandleData = {
      error: 'Request body is required',
      details: { body },
      data: null,
    }
    return { code: 400, data }
  }

  let bodyData: { workspace?: string | null; filepath?: string; content?: string }
  try {
    bodyData = JSON.parse(body)
  } catch (error) {
    const data: IApiHandleData = {
      error: 'Invalid JSON in request body',
      details: { body, error: String(error) },
      data: null,
    }
    return { code: 400, data }
  }

  const workspace: string | null = bodyData.workspace ?? null
  let filepath: string = bodyData.filepath ?? ''
  const content: string = bodyData.content ?? ''

  filepath = state.resolveFilepath(workspace, filepath)

  if (!filepath) {
    const data: IApiHandleData = {
      error: 'Bad parameters',
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

  if (!existsSync(filepath)) {
    const data: IApiHandleData = {
      error: 'File not found',
      details: { workspace, filepath },
      data: null,
    }
    return { code: 404, data }
  }

  try {
    const extname: string = path.extname(filepath).toLowerCase()

    // For .excalidraw and .drawboard files, ensure content is valid JSON and format it
    if (extname === '.excalidraw' || extname === '.drawboard') {
      const parsedData = JSON.parse(content)
      const formattedJson = JSON.stringify(parsedData, null, 2)
      await fs.writeFile(filepath, formattedJson, 'utf8')
    } else {
      // For other files, save content as-is
      await fs.writeFile(filepath, content, 'utf8')
    }

    const data: IApiHandleData = {
      data: { success: true, filepath },
    }
    return { code: 200, data }
  } catch (error) {
    state.reporter.error('Failed to save file:', { filepath, error })
    const data: IApiHandleData = {
      error: 'Failed to save file: Invalid content or write error',
      details: { workspace, filepath, error: String(error) },
      data: null,
    }
    return { code: 500, data }
  }
}
