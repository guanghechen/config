export const FILE_CHANGE_KINDS = [
  'added',
  'copied',
  'deleted',
  'modified',
  'renamed',
  'typeChanged',
  'unmerged',
  'unknown',
] as const

export type FileChangeKind = (typeof FILE_CHANGE_KINDS)[number]

export interface IFileChange {
  readonly kind: FileChangeKind
  readonly status: string
  readonly previousPath: string | null
  readonly currentPath: string | null
}

export function isFileChange(value: unknown): value is IFileChange {
  if (!value || typeof value !== 'object') return false
  const change = value as Partial<IFileChange>
  return (
    typeof change.kind === 'string' &&
    FILE_CHANGE_KINDS.includes(change.kind as FileChangeKind) &&
    typeof change.status === 'string' &&
    (change.previousPath === null || typeof change.previousPath === 'string') &&
    (change.currentPath === null || typeof change.currentPath === 'string')
  )
}

export function resolveDisplayPath(change: IFileChange): string {
  return change.currentPath ?? change.previousPath ?? ''
}
