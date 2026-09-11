import { createHash, randomUUID } from 'node:crypto'
import { chmod, readFile, rename, stat, unlink, writeFile } from 'node:fs/promises'
import path from 'node:path'

export interface ITextSnapshot {
  readonly content: string
  readonly revision: string
}

export function textRevision(content: string): string {
  return createHash('sha256').update(content).digest('hex')
}

export async function readVersionedText(filepath: string): Promise<ITextSnapshot> {
  const content = await readFile(filepath, 'utf8')
  return { content, revision: textRevision(content) }
}

export class TextConflictError extends Error {
  constructor() {
    super('File changed on disk. Your draft has been preserved.')
  }
}

// Serialize this application's writers per canonical path. Other editors do not share this lock.
const writes = new Map<string, Promise<unknown>>()

export async function saveVersionedText(
  filepath: string,
  content: string,
  expectedRevision?: string,
): Promise<ITextSnapshot> {
  const previous = writes.get(filepath) ?? Promise.resolve()
  const pending = previous
    .catch(() => undefined)
    .then(async () => {
      if (expectedRevision !== undefined) {
        const current = await readVersionedText(filepath)
        if (current.revision !== expectedRevision) throw new TextConflictError()
      }
      const metadata = await stat(filepath)
      const temporary = path.join(
        path.dirname(filepath),
        `.${path.basename(filepath)}.yoz-${randomUUID()}.tmp`,
      )
      try {
        await writeFile(temporary, content, { encoding: 'utf8', mode: metadata.mode, flag: 'wx' })
        await chmod(temporary, metadata.mode & 0o777)
        // Recheck after writing the temporary file, so a failed write never truncates the source.
        if (
          expectedRevision !== undefined &&
          (await readVersionedText(filepath)).revision !== expectedRevision
        ) {
          throw new TextConflictError()
        }
        await rename(temporary, filepath)
      } finally {
        await unlink(temporary).catch((error: NodeJS.ErrnoException) => {
          if (error.code !== 'ENOENT') throw error
        })
      }
      return { content, revision: textRevision(content) }
    })
  writes.set(filepath, pending)
  try {
    return await pending
  } finally {
    if (writes.get(filepath) === pending) writes.delete(filepath)
  }
}
