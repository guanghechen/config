import type { FileChangeKind, IFileChange } from '../contract'

export function parseNameStatus(output: Buffer): ReadonlyArray<IFileChange> {
  if (output.length === 0) return []

  const fields = output.toString('utf8').split('\0')
  if (fields.at(-1) === '') fields.pop()

  const changes: IFileChange[] = []
  let index = 0

  while (index < fields.length) {
    const status = requireField(fields, index, 'status')
    index += 1
    const code = status[0]

    if (code === 'R' || code === 'C') {
      const previousPath = requireField(fields, index, 'previous path')
      const currentPath = requireField(fields, index + 1, 'current path')
      index += 2
      changes.push({
        kind: code === 'R' ? 'renamed' : 'copied',
        status,
        previousPath,
        currentPath,
      })
      continue
    }

    const path = requireField(fields, index, 'path')
    index += 1
    changes.push(createSinglePathChange(status, path))
  }

  return changes
}

function createSinglePathChange(status: string, path: string): IFileChange {
  const kind = resolveKind(status[0])
  return {
    kind,
    status,
    previousPath: kind === 'added' ? null : path,
    currentPath: kind === 'deleted' ? null : path,
  }
}

function resolveKind(code: string | undefined): FileChangeKind {
  switch (code) {
    case 'A':
      return 'added'
    case 'D':
      return 'deleted'
    case 'M':
      return 'modified'
    case 'T':
      return 'typeChanged'
    case 'U':
      return 'unmerged'
    default:
      return 'unknown'
  }
}

function requireField(fields: ReadonlyArray<string>, index: number, label: string): string {
  const value = fields[index]
  if (value) return value
  throw new Error(`Malformed git name-status output: missing ${label}.`)
}
