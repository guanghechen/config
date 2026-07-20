export type FileChangeKind =
  'added' | 'copied' | 'deleted' | 'modified' | 'renamed' | 'typeChanged' | 'unmerged' | 'unknown'

export interface IFileChange {
  readonly kind: FileChangeKind
  readonly status: string
  readonly previousPath: string | null
  readonly currentPath: string | null
}

export interface ICompareSnapshot {
  readonly revision: number
  readonly repositoryPath: string
  readonly baseRef: string
  readonly targetRef: string
  readonly baseCommit: string
  readonly targetCommit: string
  readonly changes: ReadonlyArray<IFileChange>
}

export function resolveDisplayPath(change: IFileChange): string {
  return change.currentPath ?? change.previousPath ?? ''
}
