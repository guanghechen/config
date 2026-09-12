import path from 'node:path'
import { parseDocument } from '../../../../../../shared/whiteboard/document'
import { isWhiteboardFilename } from '../../../../../../shared/whiteboard/files'
import state from '../../../../../state'
import { FileExistsError, createVersionedText } from '../../../../../util/versioned-text'
import type { IApiHandle } from '../../../types'

export const createWhiteboard: IApiHandle = async ({ req, body }) => {
  if (req.method !== 'POST')
    return { code: 405, data: { error: 'Use POST to create a whiteboard', data: null } }
  let input: unknown
  try {
    input = JSON.parse(body ?? '')
  } catch {
    return { code: 400, data: { error: 'Invalid JSON in request body', data: null } }
  }
  if (
    !input ||
    typeof input !== 'object' ||
    !('directory' in input) ||
    !('filename' in input) ||
    !('content' in input) ||
    typeof input.filename !== 'string' ||
    typeof input.content !== 'string' ||
    !isWhiteboardFilename(input.filename)
  )
    return { code: 400, data: { error: 'Choose a filename ending in .whiteboard', data: null } }
  const directory = state.access.resolve(input.directory, 'directory')
  try {
    parseDocument(input.content)
  } catch (error) {
    return {
      code: 400,
      data: { error: error instanceof Error ? error.message : 'Invalid whiteboard', data: null },
    }
  }
  const filepath = path.join(directory, input.filename)
  try {
    const snapshot = await createVersionedText(filepath, input.content)
    return { code: 201, data: { data: { filepath, revision: snapshot.revision } } }
  } catch (error) {
    if (error instanceof FileExistsError)
      return { code: 409, data: { error: error.message, data: null } }
    throw error
  }
}
