import fs from 'node:fs/promises'
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

  let bodyData: unknown
  try {
    bodyData = JSON.parse(body)
  } catch {
    return { code: 400, data: { error: 'Invalid JSON in request body', data: null } }
  }
  if (
    !bodyData ||
    typeof bodyData !== 'object' ||
    !('filepath' in bodyData) ||
    !('content' in bodyData) ||
    typeof bodyData.content !== 'string'
  ) {
    return { code: 400, data: { error: 'filepath and string content are required', data: null } }
  }
  const filepath = state.access.resolve(bodyData.filepath, 'file')
  const content = bodyData.content

  try {
    await fs.writeFile(filepath, content, 'utf8')

    const data: IApiHandleData = {
      data: { success: true, filepath },
    }
    return { code: 200, data }
  } catch (error) {
    state.reporter.error('Failed to save file:', { filepath, error })
    const data: IApiHandleData = {
      error: 'Failed to save file: Invalid content or write error',
      details: { filepath, error: String(error) },
      data: null,
    }
    return { code: 500, data }
  }
}
