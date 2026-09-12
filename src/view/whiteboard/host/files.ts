import {
  FileConflictError,
  createWhiteboardFile,
  loadReferencedText,
  saveReferencedText,
} from '@/shared/api/whiteboard'
import { WhiteboardFileConflictError } from '../contracts'
import type { IWhiteboardDrafts, IWhiteboardFiles } from '../contracts'

export const files: IWhiteboardFiles = {
  async load(filepath, revision, signal) {
    const data = await loadReferencedText(filepath, revision, signal)
    return data
      ? {
          filepath: data.filepath,
          content: data.content,
          revision: data.revision,
          renderData: data.markdown?.ast,
        }
      : null
  },
  async save(filepath, content, expectedRevision) {
    try {
      return await saveReferencedText(filepath, content, expectedRevision)
    } catch (error) {
      if (error instanceof FileConflictError) throw new WhiteboardFileConflictError(error.message)
      throw error
    }
  },
  create: createWhiteboardFile,
  subscribe(changed) {
    const listener = (event: { filepath: string }): void => changed(event.filepath)
    import.meta.hot?.on('guanghechen/file-changed', listener)
    return () => import.meta.hot?.off('guanghechen/file-changed', listener)
  },
}

export const drafts: IWhiteboardDrafts = {
  read: filepath => localStorage.getItem(`yoz.whiteboard.v1:${filepath ?? 'scratch'}`),
  write: (filepath, value) =>
    localStorage.setItem(`yoz.whiteboard.v1:${filepath ?? 'scratch'}`, value),
}

export const imageUrl = (url: string): string =>
  url.startsWith('/') && !url.startsWith('//') && !url.startsWith('/api/')
    ? `/api/file/raw?${new URLSearchParams({ filepath: url })}`
    : url

export const openFile = (filepath: string): void =>
  window.location.assign(`/whiteboard?${new URLSearchParams({ filepath })}`)
