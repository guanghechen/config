import type { IMarkdownFileData } from '../types/api'
import { requester } from './requester'

export interface IReferencedText {
  readonly filepath: string
  readonly content: string
  readonly revision: string
  readonly markdown?: IMarkdownFileData
}

export class FileConflictError extends Error {}

export async function loadReferencedText(
  filepath: string,
  revision?: string,
  signal?: AbortSignal,
): Promise<IReferencedText | null> {
  const query = new URLSearchParams({ filepath, ...(revision ? { revision } : {}) })
  const response = await requester.get(`/api/file/text?${query}`, undefined, { signal })
  const body = (await response.json()) as {
    error?: string
    data: IReferencedText & { unchanged?: boolean }
  }
  if (!response.ok) throw new Error(body.error || 'Unable to read file')
  return body.data.unchanged ? null : body.data
}

export async function saveReferencedText(
  filepath: string,
  content: string,
  expectedRevision: string,
): Promise<string> {
  const response = await requester.post('/api/file/save', { filepath, content, expectedRevision })
  const body = (await response.json()) as { error?: string; data: { revision: string } }
  if (response.status === 409) throw new FileConflictError(body.error)
  if (!response.ok) throw new Error(body.error || 'Unable to save file')
  return body.data.revision
}
