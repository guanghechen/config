import path from 'node:path'
import state from '../../../../../state'
import { FileAccessError } from '../../../../../util/file-access'
import { findMarkdownFiles } from '../../../../../util/workspace'
import type { IApiHandle } from '../../../types'

export const list_workspace_files: IApiHandle = async ({ searchParams }) => {
  const root = state.access.resolve(searchParams.get('root'), 'directory')
  const candidates = await findMarkdownFiles(root)
  const files: string[] = []
  for (const filepath of candidates) {
    const absolute = path.resolve(root, filepath)
    try {
      state.access.resolve(absolute, 'file')
      files.push(absolute)
    } catch (error) {
      if (!(error instanceof FileAccessError)) throw error
    }
  }
  return { code: 200, data: { data: { root, files } } }
}
