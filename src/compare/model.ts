import type { IFileChange } from '../git/file-change'

export interface ICompareSnapshot {
  readonly revision: number
  readonly repositoryPath: string
  readonly baseRef: string
  readonly targetRef: string
  readonly baseCommit: string
  readonly targetCommit: string
  readonly changes: ReadonlyArray<IFileChange>
}
