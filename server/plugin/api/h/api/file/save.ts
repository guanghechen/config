import state from '../../../../../state'
import { TextConflictError, saveVersionedText } from '../../../../../util/versioned-text'
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
  const expectedRevision = 'expectedRevision' in bodyData ? bodyData.expectedRevision : undefined
  if (
    expectedRevision !== undefined &&
    (typeof expectedRevision !== 'string' || !/^[a-f0-9]{64}$/.test(expectedRevision))
  ) {
    return { code: 400, data: { error: 'Invalid expected revision', data: null } }
  }

  try {
    const snapshot = await saveVersionedText(filepath, content, expectedRevision)

    const data: IApiHandleData = {
      data: { success: true, filepath, revision: snapshot.revision },
    }
    return { code: 200, data }
  } catch (error) {
    if (error instanceof TextConflictError) {
      return { code: 409, data: { error: error.message, data: null } }
    }
    state.reporter.error('Failed to save file:', { filepath, error })
    const data: IApiHandleData = {
      error: 'Failed to save file: Invalid content or write error',
      details: { filepath, error: String(error) },
      data: null,
    }
    return { code: 500, data }
  }
}
