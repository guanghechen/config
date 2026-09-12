import type { IWhiteboardDrafts } from '../contracts'
import { createDocument } from '@/shared/whiteboard/model'
import type { IWhiteboardDocument } from '@/shared/whiteboard/model'
import { parseDocument } from '@/shared/whiteboard/document'

export function readDraft(
  drafts: IWhiteboardDrafts | undefined,
  filepath?: string,
): {
  document: IWhiteboardDocument
  revision?: string
  error?: string
  recovered?: boolean
} {
  try {
    const raw = drafts?.read(filepath)
    if (raw) {
      const value = JSON.parse(raw)
      return {
        document: parseDocument(JSON.stringify(value.document)),
        revision: value.revision,
        recovered: true,
      }
    }
  } catch (error) {
    return {
      document: createDocument(),
      error: `Unable to restore draft: ${error instanceof Error ? error.message : String(error)}`,
    }
  }
  return { document: createDocument() }
}
